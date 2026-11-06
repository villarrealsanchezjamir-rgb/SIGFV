using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using SIGFV.Application.Abstractions;
using SIGFV.Application.Common;
using SIGFV.Application.Models;
using SIGFV.Application.Services;
using SIGFV.Domain;
using SIGFV.Infrastructure.Excel;
using SIGFV.Infrastructure.Persistence;
using SIGFV.Infrastructure.Security;

const string Version = "2.2.0";
JwtSecurityTokenHandler.DefaultMapInboundClaims = false;

var root = FindRoot();
LoadDotEnv(root);

var port = int.TryParse(Env("PORT") ?? "3000", out var p) ? p : 3000;
var connectionString = Env("SUPABASE_DB_URL") ?? Env("ConnectionStrings__Supabase");
if (string.IsNullOrWhiteSpace(connectionString))
    throw new InvalidOperationException("Defina SUPABASE_DB_URL (cadena de conexión de Supabase/PostgreSQL).");
var jwtSecret = Env("JWT_SECRET");
if (string.IsNullOrWhiteSpace(jwtSecret) || jwtSecret.Length < 32)
    throw new InvalidOperationException("Defina JWT_SECRET con al menos 32 caracteres.");

var webRoot = Path.Combine(root, "public");

var builder = WebApplication.CreateBuilder(new WebApplicationOptions
{
    Args = args,
    ContentRootPath = root,
    WebRootPath = Directory.Exists(webRoot) ? webRoot : null
});

builder.WebHost.UseUrls($"http://0.0.0.0:{port}");
builder.Logging.ClearProviders();
builder.Logging.AddSimpleConsole(o => { o.SingleLine = true; o.TimestampFormat = "HH:mm:ss "; });

var db = new NpgsqlDb(connectionString);
var hasher = new Pbkdf2PasswordHasher();
var tokens = new JwtTokenService(jwtSecret);
var crud = new CrudService(db, hasher);

builder.Services.AddSingleton<IDb>(db);
builder.Services.AddSingleton<IPasswordHasher>(hasher);
builder.Services.AddSingleton<ITokenService>(tokens);
builder.Services.AddSingleton<IExcelExporter, XlsxExporter>();
builder.Services.AddSingleton(crud);
builder.Services.AddSingleton(new AuthService(db, hasher, tokens));
builder.Services.AddSingleton<MetaService>();
builder.Services.AddSingleton<CatalogService>();
builder.Services.AddSingleton<DashboardService>();
builder.Services.AddSingleton<NotificationService>();
builder.Services.AddSingleton<ExportService>();
builder.Services.AddSingleton<SyncService>();
builder.Services.AddSingleton<AdminService>();

builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    o.SerializerOptions.DictionaryKeyPolicy = null;
});

var allowedOrigins = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
{
    "https://localhost", "http://localhost", "capacitor://localhost",
    "https://sigfv.onrender.com"
};
foreach (var origin in (Env("ALLOWED_ORIGINS") ?? "").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
    allowedOrigins.Add(origin);

builder.Services.AddCors(o => o.AddDefaultPolicy(policy => policy
    .SetIsOriginAllowed(origin => allowedOrigins.Contains(origin))
    .AllowAnyHeader()
    .AllowAnyMethod()));

var app = builder.Build();

app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers["X-Frame-Options"] = "DENY";
    ctx.Response.Headers["Referrer-Policy"] = "same-origin";
    ctx.Response.Headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()";
    ctx.Response.Headers["Content-Security-Policy"] =
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
        "font-src https://fonts.gstatic.com; img-src 'self' data:; connect-src 'self' https://sigfv.onrender.com https://localhost";
    await next();
});

app.Use(async (ctx, next) =>
{
    try
    {
        await next();
    }
    catch (AppException ex)
    {
        if (!ctx.Response.HasStarted)
        {
            ctx.Response.Clear();
            ctx.Response.StatusCode = ex.Status;
            await ctx.Response.WriteAsJsonAsync(new { error = ex.Message });
        }
    }
    catch (PostgresException ex)
    {
        if (!ctx.Response.HasStarted)
        {
            ctx.Response.Clear();
            var (status, message) = ex.SqlState switch
            {
                "23505" => (409, "Ya existe un registro con ese valor único (código, placa, documento, RUC, etc.)."),
                "23514" => (400, "Algún valor no cumple las reglas de validación (fechas, cantidades o titular del documento)."),
                "23503" => (400, "Alguno de los datos relacionados no existe o está en uso."),
                "23502" => (400, "Falta un dato obligatorio."),
                "22P02" or "22007" or "22008" or "22003" or "22001" => (400, "Formato de dato inválido."),
                "P0001" => (409, ex.MessageText),
                _ => (500, "Error de base de datos.")
            };
            ctx.Response.StatusCode = status;
            await ctx.Response.WriteAsJsonAsync(new { error = message });
            if (status == 500) app.Logger.LogError(ex, "PostgreSQL {State}", ex.SqlState);
        }
    }
    catch (BadHttpRequestException ex)
    {
        if (!ctx.Response.HasStarted)
        {
            ctx.Response.Clear();
            ctx.Response.StatusCode = 400;
            await ctx.Response.WriteAsJsonAsync(new { error = "El cuerpo de la solicitud no es válido: " + ex.Message });
        }
    }
    catch (Exception ex)
    {
        if (!ctx.Response.HasStarted)
        {
            ctx.Response.Clear();
            ctx.Response.StatusCode = 500;
            await ctx.Response.WriteAsJsonAsync(new { error = "Error interno del servidor." });
        }
        app.Logger.LogError(ex, "Error no controlado en {Path}", ctx.Request.Path);
    }
});

app.UseCors();
app.UseDefaultFiles();
app.UseStaticFiles();

app.Use(async (ctx, next) =>
{
    var path = ctx.Request.Path;
    if (!path.StartsWithSegments("/api") ||
        path.StartsWithSegments("/api/health") ||
        path.StartsWithSegments("/api/auth/login") ||
        path.StartsWithSegments("/api/auth/context"))
    {
        await next();
        return;
    }

    try
    {
        var token = ReadToken(ctx);
        if (string.IsNullOrWhiteSpace(token))
            throw new AppException("Sesión no iniciada o vencida.", 401);

        var handler = new JwtSecurityTokenHandler();
        var parameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            ValidateIssuer = false,
            ValidateAudience = false,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1)
        };
        var principal = handler.ValidateToken(token, parameters, out _);
        var roleId = ClaimInt(principal, "rid");
        var empresaId = ClaimInt(principal, "eid");
        if (roleId is null || empresaId is null)
            throw new AppException("Sesión no válida. Vuelva a ingresar.", 401);

        var userId = ClaimInt(principal, "sub");
        var operador = principal.FindFirst("op")?.Value;
        var auth = ctx.RequestServices.GetRequiredService<AuthService>();
        var session = await auth.LoadSessionAsync(roleId.Value, empresaId.Value,
            userId is > 0 ? userId : null, operador, ctx.RequestAborted);
        ctx.Items["session"] = session;
    }
    catch (AppException ex)
    {
        if (!ctx.Response.HasStarted)
        {
            ctx.Response.StatusCode = 401;
            await ctx.Response.WriteAsJsonAsync(new { error = ex.Message });
        }
        return;
    }
    catch (SecurityTokenException)
    {
        if (!ctx.Response.HasStarted)
        {
            ctx.Response.StatusCode = 401;
            await ctx.Response.WriteAsJsonAsync(new { error = "Sesión no iniciada o vencida." });
        }
        return;
    }

    await next();
});

app.MapGet("/api/health", async (IDb database) =>
{
    await database.QueryAsync("SELECT 1");
    return Results.Ok(new
    {
        ok = true,
        version = Version,
        database = "Supabase PostgreSQL",
        supabase = new { configured = true, ok = true },
        hora = DateTime.UtcNow.ToString("O")
    });
});

app.MapGet("/api/auth/context", async (AuthService auth, CancellationToken ct) =>
    Results.Ok(await auth.GetContextAsync(ct)));

app.MapPost("/api/auth/login", async (JsonElement body, HttpContext ctx, AuthService auth, CancellationToken ct) =>
{
    if (body.ValueKind != JsonValueKind.Object)
        throw new AppException("Solicitud no válida.");

    if (body.TryGetProperty("usuario", out _) && !body.TryGetProperty("rolId", out _))
        throw new AppException(
            "Esta versión ya no usa usuario y contraseña. Ingrese con empresa, rol y contraseña, o actualice la aplicación.",
            426);

    var request = new LoginRequest(
        GetInt(body, "empresaId") ?? -1,
        GetInt(body, "rolId") ?? 0,
        GetString(body, "password") ?? "",
        GetString(body, "operador"));

    var ip = ctx.Connection.RemoteIpAddress?.ToString();
    var response = await auth.LoginAsync(request, ip ?? "desconocida", ct);
    return Results.Ok(response);
});

app.MapPost("/api/auth/change-password", async (JsonElement body, HttpContext ctx, AdminService admin,
    CancellationToken ct) =>
{
    var session = Session(ctx);
    await admin.ChangePasswordAsync(session, GetString(body, "actual") ?? "", GetString(body, "nueva") ?? "", ct);
    return Results.Ok(new { ok = true });
});

app.MapGet("/api/meta", (HttpContext ctx, MetaService meta) =>
    Results.Ok(meta.Build(Session(ctx))));

app.MapGet("/api/cat/{name}", async (string name, HttpContext ctx, CatalogService catalogs, CancellationToken ct) =>
{
    var session = Session(ctx);
    if (!session.Has("configuracion", "consultar") && !session.Has("vehiculos", "consultar") &&
        !session.Has("conductores", "consultar") && !session.Has("asignaciones", "consultar") &&
        !session.Has("mantenimiento", "consultar") && !session.Has("documentos", "consultar") &&
        !session.Has("combustible", "consultar") && !session.Has("incidentes", "consultar") &&
        !session.Has("inspecciones", "consultar") && !session.Has("usuarios", "consultar"))
        throw new AppException("No tiene permiso para consultar catálogos.", 403);

    return Results.Ok(await catalogs.GetAsync(name, session, ct));
});

app.MapGet("/api/dashboard", async (HttpContext ctx, DashboardService dashboard, CancellationToken ct) =>
{
    var session = Session(ctx);
    Require(session, "dashboard", "consultar");
    return Results.Ok(await dashboard.GetAsync(session, ct));
});

app.MapGet("/api/notificaciones", async (HttpContext ctx, NotificationService notifications, CancellationToken ct) =>
{
    var session = Session(ctx);
    Require(session, "notificaciones", "consultar");
    return Results.Ok(await notifications.GetAsync(session, ct));
});

app.MapGet("/api/r/{key}", async (string key, string? q, int? pagina, int? limit, HttpContext ctx,
    CrudService crudService, CancellationToken ct) =>
{
    var session = Session(ctx);
    var resource = CrudService.Resolve(key);
    Require(session, resource.Mod, "consultar");
    return Results.Ok(await crudService.ListAsync(key, session, q, pagina ?? 1, limit ?? 20, ct));
});

app.MapGet("/api/r/{key}/{id:int}", async (string key, int id, HttpContext ctx, CrudService crudService,
    CancellationToken ct) =>
{
    var session = Session(ctx);
    var resource = CrudService.Resolve(key);
    Require(session, resource.Mod, "consultar");
    return Results.Ok(await crudService.GetAsync(key, id, session, ct));
});

app.MapPost("/api/r/{key}", async (string key, JsonElement body, HttpContext ctx, CrudService crudService,
    CancellationToken ct) =>
{
    var session = Session(ctx);
    var resource = CrudService.Resolve(key);
    Require(session, resource.Mod, "crear");
    var result = await crudService.CreateAsync(key, session, JsonUtil.ToDictionary(body), Ip(ctx), ct);
    return Results.Created($"/api/r/{key}/{result.Id}", new { id = result.Id });
});

app.MapPut("/api/r/{key}/{id:int}", async (string key, int id, JsonElement body, HttpContext ctx,
    CrudService crudService, CancellationToken ct) =>
{
    var session = Session(ctx);
    var resource = CrudService.Resolve(key);
    Require(session, resource.Mod, "editar");
    var result = await crudService.UpdateAsync(key, session, id, JsonUtil.ToDictionary(body), Ip(ctx), ct);
    return Results.Ok(new { id = result.Id });
});

app.MapDelete("/api/r/{key}/{id:int}", async (string key, int id, HttpContext ctx, CrudService crudService,
    CancellationToken ct) =>
{
    var session = Session(ctx);
    var resource = CrudService.Resolve(key);
    Require(session, resource.Mod, "eliminar");
    await crudService.DeleteAsync(key, session, id, Ip(ctx), ct);
    return Results.Ok(new { ok = true });
});

app.MapGet("/api/export/all", async (HttpContext ctx, ExportService export, CancellationToken ct) =>
{
    var file = await export.BuildAllAsync(Session(ctx), ct);
    return Results.File(file.Content,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", file.FileName);
});

app.MapGet("/api/export/{key}", async (string key, string? q, HttpContext ctx, ExportService export,
    CancellationToken ct) =>
{
    var file = await export.BuildModuleAsync(key, Session(ctx), q, ct);
    return Results.File(file.Content,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", file.FileName);
});

app.MapPost("/api/sync", async (JsonElement body, HttpContext ctx, SyncService sync, CancellationToken ct) =>
{
    var session = Session(ctx);
    var request = new SyncRequest(ParseOps(body));
    return Results.Ok(new { results = await sync.ApplyAsync(request, session, Ip(ctx), ct) });
});

app.MapGet("/api/admin/permissions", (HttpContext ctx, AdminService admin) =>
{
    Require(Session(ctx), "usuarios", "consultar");
    return Results.Ok(admin.Permissions());
});

app.MapGet("/api/admin/roles", async (HttpContext ctx, AdminService admin, CancellationToken ct) =>
{
    Require(Session(ctx), "usuarios", "consultar");
    return Results.Ok(await admin.RolesAsync(Session(ctx), ct));
});

app.MapPost("/api/admin/roles", async (JsonElement body, HttpContext ctx, AdminService admin,
    CancellationToken ct) =>
{
    var session = Session(ctx);
    RequireAny(session, ("usuarios", "crear"), ("usuarios", "editar"));
    var id = await admin.SaveRoleAsync(null, ReadRole(body), session, ct);
    return Results.Created($"/api/admin/roles/{id}", new { id });
});

app.MapPut("/api/admin/roles/{id:int}", async (int id, JsonElement body, HttpContext ctx, AdminService admin,
    CancellationToken ct) =>
{
    var session = Session(ctx);
    Require(session, "usuarios", "editar");
    await admin.SaveRoleAsync(id, ReadRole(body), session, ct);
    return Results.Ok(new { id });
});

app.MapDelete("/api/admin/roles/{id:int}", async (int id, HttpContext ctx, AdminService admin,
    CancellationToken ct) =>
{
    var session = Session(ctx);
    Require(session, "usuarios", "eliminar");
    await admin.DeleteRoleAsync(id, session, ct);
    return Results.Ok(new { ok = true });
});

app.MapGet("/api/admin/empresas", async (HttpContext ctx, AdminService admin, CancellationToken ct) =>
{
    Require(Session(ctx), "configuracion", "consultar");
    return Results.Ok(await admin.CompaniesAsync(Session(ctx), ct));
});

app.MapGet("/api/admin/empresas/{id:int}", async (int id, HttpContext ctx, AdminService admin,
    CancellationToken ct) =>
{
    Require(Session(ctx), "configuracion", "consultar");
    return Results.Ok(await admin.CompanyDetailAsync(id, Session(ctx), ct));
});

app.MapPost("/api/admin/empresas", async (JsonElement body, HttpContext ctx, AdminService admin,
    CancellationToken ct) =>
{
    var session = Session(ctx);
    Require(session, "configuracion", "crear");
    var id = await admin.SaveCompanyAsync(null, ReadCompany(body), session, ct);
    return Results.Created($"/api/admin/empresas/{id}", new { id });
});

app.MapPut("/api/admin/empresas/{id:int}", async (int id, JsonElement body, HttpContext ctx, AdminService admin,
    CancellationToken ct) =>
{
    var session = Session(ctx);
    Require(session, "configuracion", "editar");
    await admin.SaveCompanyAsync(id, ReadCompany(body), session, ct);
    return Results.Ok(new { id });
});

app.MapGet("/api/admin/auditoria", async (int? limit, HttpContext ctx, AdminService admin,
    CancellationToken ct) =>
{
    Require(Session(ctx), "configuracion", "consultar");
    return Results.Ok(await admin.AuditAsync(Session(ctx), limit ?? 200, ct));
});

app.MapFallback(async ctx =>
{
    if (ctx.Request.Path.StartsWithSegments("/api"))
    {
        ctx.Response.StatusCode = 404;
        await ctx.Response.WriteAsJsonAsync(new { error = "Ruta no encontrada." });
        return;
    }

    var index = Path.Combine(webRoot, "index.html");
    if (File.Exists(index))
    {
        ctx.Response.ContentType = "text/html; charset=utf-8";
        await ctx.Response.SendFileAsync(index);
    }
    else
    {
        ctx.Response.StatusCode = 404;
        await ctx.Response.WriteAsync("SIGFV API activa.");
    }
});

app.Logger.LogInformation("SIGFV {Version} escuchando en el puerto {Port}", Version, port);
app.Run();

/* ---------- Utilidades ---------- */

static CurrentSession Session(HttpContext ctx)
    => ctx.Items["session"] as CurrentSession ?? throw new AppException("Sesión no iniciada.", 401);

static void Require(CurrentSession session, string module, string action)
{
    if (!session.Has(module, action))
        throw new AppException("No tiene permiso para esta acción.", 403);
}

static void RequireAny(CurrentSession session, params (string Module, string Action)[] permissions)
{
    if (permissions.Any(p => session.Has(p.Module, p.Action))) return;
    throw new AppException("No tiene permiso para esta acción.", 403);
}

static string? Ip(HttpContext ctx) => ctx.Connection.RemoteIpAddress?.ToString();

static string? ReadToken(HttpContext ctx)
{
    var header = ctx.Request.Headers.Authorization.ToString();
    if (!string.IsNullOrWhiteSpace(header) && header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        return header["Bearer ".Length..].Trim();

    if (ctx.Request.Path.StartsWithSegments("/api/export"))
        return ctx.Request.Query["token"].ToString();

    return null;
}

static int? ClaimInt(ClaimsPrincipal principal, string type)
{
    var value = principal.FindFirst(type)?.Value;
    return int.TryParse(value, out var parsed) ? parsed : null;
}

static string? GetString(JsonElement body, string name)
    => body.ValueKind == JsonValueKind.Object && body.TryGetProperty(name, out var value) &&
       value.ValueKind is JsonValueKind.String or JsonValueKind.Number
        ? value.ToString()
        : null;

static int? GetInt(JsonElement body, string name)
{
    if (body.ValueKind != JsonValueKind.Object || !body.TryGetProperty(name, out var value)) return null;
    if (value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number)) return number;
    return int.TryParse(value.ToString(), out var parsed) ? parsed : null;
}

static RoleSaveRequest ReadRole(JsonElement body)
{
    var permissions = new List<string>();
    if (body.ValueKind != JsonValueKind.Object)
        return new RoleSaveRequest("", null, null, null, null, null, true, permissions);

    if (body.TryGetProperty("permisos", out var perms) && perms.ValueKind == JsonValueKind.Array)
        foreach (var item in perms.EnumerateArray())
            if (item.ValueKind == JsonValueKind.String)
                permissions.Add(item.GetString()!);

    return new RoleSaveRequest(
        GetString(body, "nombre") ?? "",
        GetString(body, "descripcion"),
        GetInt(body, "empresaId"),
        GetString(body, "password"),
        GetString(body, "icono"),
        GetString(body, "color"),
        body.TryGetProperty("activo", out var activo) ? activo.ValueKind != JsonValueKind.False : true,
        permissions);
}

static CompanySaveRequest ReadCompany(JsonElement body)
{
    if (body.ValueKind != JsonValueKind.Object)
        return new CompanySaveRequest(null, "", null, null, null, null, null, true);

    return new CompanySaveRequest(
        GetString(body, "ruc"),
        GetString(body, "razonSocial") ?? GetString(body, "razon_social") ?? "",
        GetString(body, "direccion"),
        GetString(body, "telefono"),
        GetString(body, "correo"),
        GetString(body, "contacto"),
        GetString(body, "notas"),
        !body.TryGetProperty("activo", out var activo) || activo.ValueKind != JsonValueKind.False);
}

static List<SyncOperation> ParseOps(JsonElement body)
{
    var ops = new List<SyncOperation>();
    if (body.ValueKind != JsonValueKind.Object || !body.TryGetProperty("ops", out var list) ||
        list.ValueKind != JsonValueKind.Array)
        return ops;

    foreach (var item in list.EnumerateArray())
    {
        if (item.ValueKind != JsonValueKind.Object) continue;
        var opId = GetString(item, "opId") ?? "";
        var method = GetString(item, "method") ?? "";
        var resource = GetString(item, "resource") ?? "";
        var id = GetInt(item, "id");
        Dictionary<string, object?>? payload = null;
        if (item.TryGetProperty("body", out var opBody) && opBody.ValueKind == JsonValueKind.Object)
            payload = JsonUtil.ToDictionary(opBody);
        ops.Add(new SyncOperation(opId, method, resource, id, payload));
    }

    return ops;
}

static string FindRoot()
{
    foreach (var start in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
    {
        var dir = new DirectoryInfo(start);
        while (dir is not null)
        {
            if (File.Exists(Path.Combine(dir.FullName, "public", "index.html")))
                return dir.FullName;
            dir = dir.Parent;
        }
    }
    return Directory.GetCurrentDirectory();
}

static void LoadDotEnv(string root)
{
    var path = Path.Combine(root, ".env");
    if (!File.Exists(path)) return;
    foreach (var line in File.ReadAllLines(path))
    {
        var trimmed = line.Trim();
        if (trimmed.Length == 0 || trimmed.StartsWith('#')) continue;
        var index = trimmed.IndexOf('=');
        if (index <= 0) continue;
        var key = trimmed[..index].Trim();
        var value = trimmed[(index + 1)..].Trim().Trim('"');
        if (Environment.GetEnvironmentVariable(key) is null)
            Environment.SetEnvironmentVariable(key, value);
    }
}

static string? Env(string name)
{
    var value = Environment.GetEnvironmentVariable(name);
    return string.IsNullOrWhiteSpace(value) ? null : value;
}
