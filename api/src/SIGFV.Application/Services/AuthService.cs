using SIGFV.Application.Abstractions;
using SIGFV.Application.Models;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

public sealed class AuthService
{
    private readonly IDb _db;
    private readonly IPasswordHasher _hasher;
    private readonly ITokenService _token;

    public AuthService(IDb db, IPasswordHasher hasher, ITokenService token)
    {
        _db = db;
        _hasher = hasher;
        _token = token;
    }

    public async Task<AuthContextResponse> GetContextAsync(CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync("""
            SELECT e.id empresa_id, e.razon_social, e.ruc,
                   r.id rol_id, r.nombre, r.descripcion, r.icono, r.color, r.empresa_id rol_empresa
            FROM empresas e
            JOIN roles r ON r.activo
                        AND r.password_hash IS NOT NULL
                        AND (r.empresa_id = e.id OR r.empresa_id IS NULL)
            WHERE e.activo
            ORDER BY e.razon_social, r.nombre
            """, ct: ct);

        var companies = new List<CompanyDto>();
        foreach (var group in rows.GroupBy(r => new
                 {
                     Id = Convert.ToInt32(r["empresa_id"]),
                     Name = Convert.ToString(r["razon_social"]) ?? "",
                     Ruc = Convert.ToString(r["ruc"]) ?? ""
                 }))
        {
            var roles = group.Select(r => new CompanyRoleDto(
                Convert.ToInt32(r["rol_id"]),
                Convert.ToString(r["nombre"]) ?? "",
                r["descripcion"] as string,
                r["icono"] as string,
                r["color"] as string,
                r["rol_empresa"] is null or DBNull)).ToList();
            companies.Add(new CompanyDto(group.Key.Id, group.Key.Name, group.Key.Ruc, roles));
        }

        var globalRoles = await _db.QueryAsync("""
            SELECT id, nombre, descripcion, icono, color
            FROM roles
            WHERE activo AND password_hash IS NOT NULL AND empresa_id IS NULL
            ORDER BY nombre
            """, ct: ct);

        if (globalRoles.Count > 0)
        {
            var list = globalRoles.Select(r => new CompanyRoleDto(
                Convert.ToInt32(r["id"]), Convert.ToString(r["nombre"]) ?? "", r["descripcion"] as string,
                r["icono"] as string, r["color"] as string, true)).ToList();
            companies.Insert(0, new CompanyDto(0, "Todas las empresas", "—", list));
        }

        return new AuthContextResponse(companies);
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest request, string ip, CancellationToken ct = default)
    {
        if (request.RolId <= 0) throw new AppException("Seleccione un rol.");
        if (string.IsNullOrWhiteSpace(request.Password)) throw new AppException("Ingrese la contraseña del rol.");
        if (request.EmpresaId < 0) throw new AppException("Seleccione una empresa.");

        var rows = await _db.QueryAsync("""
            SELECT r.id, r.nombre, r.descripcion, r.password_hash, r.activo, r.empresa_id,
                   r.intentos_fallidos, r.bloqueado_hasta, e.razon_social, e.activo empresa_activa
            FROM roles r
            LEFT JOIN empresas e ON e.id = r.empresa_id
            WHERE r.id = @rid
            """, new Dictionary<string, object?> { ["rid"] = request.RolId }, ct);

        var role = rows.FirstOrDefault() ?? throw new AppException("Rol no válido.", 401);
        if (!Convert.ToBoolean(role["activo"])) throw new AppException("Rol inactivo.", 401);
        if (role["password_hash"] is not string hash || hash.Length == 0)
            throw new AppException("Este rol aún no tiene contraseña asignada. Contacte al administrador.", 403);

        var roleCompany = role["empresa_id"] is null or DBNull ? (int?)null : Convert.ToInt32(role["empresa_id"]);
        if (roleCompany is not null && roleCompany != request.EmpresaId)
            throw new AppException("El rol no pertenece a la empresa seleccionada.", 403);
        if (roleCompany is null && request.EmpresaId != 0)
        {
            // Los roles globales se pueden usar dentro de cualquier empresa seleccionada.
        }
        if (request.EmpresaId < 0)
            throw new AppException("Empresa no válida.", 400);

        if (role["bloqueado_hasta"] is DateTime blocked && blocked > DateTime.Now)
            throw new AppException("Rol bloqueado temporalmente por intentos fallidos. Intente más tarde.", 423);

        if (!_hasher.Verify(request.Password, hash))
        {
            await _db.ExecuteAsync("""
                UPDATE roles SET intentos_fallidos = intentos_fallidos + 1,
                    bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 5
                        THEN now() + INTERVAL '15 minutes' ELSE NULL END
                WHERE id = @rid
                """, new Dictionary<string, object?> { ["rid"] = request.RolId }, ct);
            await LogAccessAsync(request.RolId, request.EmpresaId, request.Operador, ip, false, ct);
            throw new AppException("Contraseña incorrecta.", 401);
        }

        var companyName = "Todas las empresas";
        if (request.EmpresaId > 0)
        {
            var company = await _db.QueryAsync(
                "SELECT razon_social, activo FROM empresas WHERE id = @id",
                new Dictionary<string, object?> { ["id"] = request.EmpresaId }, ct);
            var c = company.FirstOrDefault();
            if (c is null || !Convert.ToBoolean(c["activo"]))
                throw new AppException("Empresa no válida o inactiva.", 403);
            companyName = Convert.ToString(c["razon_social"]) ?? companyName;
        }

        await _db.ExecuteAsync("""
            UPDATE roles SET intentos_fallidos = 0, bloqueado_hasta = NULL, ultimo_acceso = now()
            WHERE id = @rid
            """, new Dictionary<string, object?> { ["rid"] = request.RolId }, ct);

        var userRows = await _db.QueryAsync(
            "SELECT usuario_id FROM usuario_roles WHERE rol_id = @rid ORDER BY usuario_id LIMIT 1",
            new Dictionary<string, object?> { ["rid"] = request.RolId }, ct);
        var userId = userRows.Count > 0 ? Convert.ToInt32(userRows[0]["usuario_id"]) : (int?)null;

        var operador = string.IsNullOrWhiteSpace(request.Operador) ? (string?)null : request.Operador.Trim();
        var permissions = await LoadPermissionsAsync(request.RolId, ct);
        var session = new CurrentSession(request.RolId, Convert.ToString(role["nombre"]) ?? "", request.EmpresaId,
            companyName, userId, operador ?? "", permissions, roleCompany);
        var token = _token.Create(session, operador ?? "Operador del rol");
        await LogAccessAsync(request.RolId, request.EmpresaId, operador, ip, true, ct);

        return new LoginResponse(token, session.RoleName, companyName, request.EmpresaId, session.Operador,
            permissions.OrderBy(p => p).ToList());
    }

    public async Task<CurrentSession> LoadSessionAsync(int roleId, int empresaId, int? userId, string? operador,
        CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync("""
            SELECT r.id, r.nombre, r.activo, r.empresa_id, e.razon_social, e.activo empresa_activa
            FROM roles r LEFT JOIN empresas e ON e.id = r.empresa_id
            WHERE r.id = @rid
            """, new Dictionary<string, object?> { ["rid"] = roleId }, ct);
        var row = rows.FirstOrDefault() ?? throw new AppException("Sesión no válida.", 401);
        if (!Convert.ToBoolean(row["activo"])) throw new AppException("Rol inactivo.", 401);
        var roleCompany = row["empresa_id"] is null or DBNull ? (int?)null : Convert.ToInt32(row["empresa_id"]);
        if (roleCompany is not null && roleCompany != empresaId)
            throw new AppException("La empresa de la sesión no coincide con el rol.", 401);

        var companyName = "Todas las empresas";
        if (empresaId > 0)
        {
            var company = await _db.QueryAsync("SELECT razon_social, activo FROM empresas WHERE id = @id",
                new Dictionary<string, object?> { ["id"] = empresaId }, ct);
            var c = company.FirstOrDefault();
            if (c is null || !Convert.ToBoolean(c["activo"]))
                throw new AppException("Empresa inactiva.", 401);
            companyName = Convert.ToString(c["razon_social"]) ?? companyName;
        }

        var permissions = await LoadPermissionsAsync(roleId, ct);
        return new CurrentSession(roleId, Convert.ToString(row["nombre"]) ?? "", empresaId, companyName, userId,
            operador ?? "", permissions, roleCompany);
    }

    private async Task<IReadOnlySet<string>> LoadPermissionsAsync(int roleId, CancellationToken ct)
    {
        var rows = await _db.QueryAsync("""
            SELECT DISTINCT p.modulo, p.accion
            FROM rol_permisos rp JOIN permisos p ON p.id = rp.permiso_id
            WHERE rp.rol_id = @rid
            """, new Dictionary<string, object?> { ["rid"] = roleId }, ct);
        return rows.Select(r => $"{r["modulo"]}:{r["accion"]}").ToHashSet(StringComparer.OrdinalIgnoreCase);
    }

    private Task LogAccessAsync(int roleId, int empresaId, string? operador, string ip, bool ok,
        CancellationToken ct = default)
        => _db.ExecuteAsync("""
            INSERT INTO registros_acceso (usuario_id, nombre_usuario, ip, exitoso, rol_id, empresa_id, operador)
            VALUES ((SELECT usuario_id FROM usuario_roles WHERE rol_id = @rid LIMIT 1), @nombre, @ip, @ok,
                    @rid, @eid, @op)
            """, new Dictionary<string, object?>
            {
                ["rid"] = roleId, ["nombre"] = $"rol_{roleId}", ["ip"] = ip, ["ok"] = ok,
                ["eid"] = empresaId > 0 ? empresaId : null, ["op"] = operador
            }, ct);
}
