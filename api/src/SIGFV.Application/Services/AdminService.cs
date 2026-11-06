using SIGFV.Application.Abstractions;
using SIGFV.Application.Models;
using SIGFV.Application.Resources;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

public sealed class AdminService
{
    private readonly IDb _db;
    private readonly IPasswordHasher _hasher;

    public AdminService(IDb db, IPasswordHasher hasher)
    {
        _db = db;
        _hasher = hasher;
    }

    private static readonly (string Mod, string Label)[] Modules =
    {
        ("dashboard", "Dashboard"),
        ("vehiculos", "Vehículos"),
        ("conductores", "Conductores"),
        ("asignaciones", "Asignaciones"),
        ("mantenimiento", "Mantenimiento"),
        ("inspecciones", "Inspecciones"),
        ("combustible", "Combustible"),
        ("documentos", "Documentación"),
        ("incidentes", "Incidentes"),
        ("historial", "Historial"),
        ("reportes", "Reportes"),
        ("usuarios", "Usuarios y roles"),
        ("notificaciones", "Notificaciones"),
        ("configuracion", "Configuración y catálogos"),
        ("asistente", "Asistente")
    };

    public IReadOnlyList<PermissionGroup> Permissions()
        => Modules.Select(m => new PermissionGroup(m.Mod, m.Label, PermissionActions.All)).ToList();

    public async Task<List<RoleListItem>> RolesAsync(CurrentSession session, CancellationToken ct = default)
    {
        var parameters = new Dictionary<string, object?>();
        var filter = "";
        if (session.RoleEmpresaId is > 0)
        {
            filter = "WHERE (r.empresa_id IS NULL OR r.empresa_id = @eid)";
            parameters["eid"] = session.RoleEmpresaId;
        }

        var rows = await _db.QueryAsync($"""
            SELECT r.id, r.nombre, r.descripcion, r.empresa_id, r.activo, r.icono, r.color,
                   (r.password_hash IS NOT NULL) tiene_password, e.razon_social empresa,
                   (SELECT array_agg(p.modulo || ':' || p.accion)
                    FROM rol_permisos rp JOIN permisos p ON p.id = rp.permiso_id
                    WHERE rp.rol_id = r.id) permisos
            FROM roles r
            LEFT JOIN empresas e ON e.id = r.empresa_id
            {filter}
            ORDER BY (r.empresa_id IS NULL) DESC, r.nombre
            """, parameters, ct);

        return rows.Select(r => new RoleListItem(
            Convert.ToInt32(r["id"]),
            Convert.ToString(r["nombre"]) ?? "",
            r["descripcion"] as string,
            r["empresa_id"] is null ? null : Convert.ToInt32(r["empresa_id"]),
            r["empresa"] as string,
            Convert.ToBoolean(r["activo"]),
            Convert.ToBoolean(r["tiene_password"]),
            r["icono"] as string,
            r["color"] as string,
            ToList(r["permisos"]))).ToList();
    }

    public async Task<int> SaveRoleAsync(int? id, RoleSaveRequest request, CurrentSession session,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(request.Nombre))
            throw new AppException("El nombre del rol es obligatorio.");
        if (request.Nombre.Length > 60)
            throw new AppException("El nombre del rol no puede superar 60 caracteres.");

        var empresaId = request.EmpresaId;
        if (session.RoleEmpresaId is > 0)
        {
            empresaId = session.RoleEmpresaId;
        }
        else if (empresaId is <= 0)
        {
            empresaId = null;
        }

        if (empresaId is int eid)
        {
            var company = await _db.QueryAsync("SELECT activo FROM empresas WHERE id = @id",
                new Dictionary<string, object?> { ["id"] = eid }, ct);
            if (company.Count == 0) throw new AppException("La empresa seleccionada no existe.");
        }

        string? hash = null;
        if (!string.IsNullOrWhiteSpace(request.Password))
        {
            if (request.Password.Length < 8)
                throw new AppException("La contraseña del rol debe tener al menos 8 caracteres.");
            hash = _hasher.Hash(request.Password);
        }
        else if (id is null)
        {
            throw new AppException("Asigne una contraseña al rol para que pueda iniciar sesión.");
        }

        var roleId = await _db.TransactionAsync(async tx =>
        {
            int roleId;
            if (id is null)
            {
                var inserted = await tx.QueryAsync("""
                    INSERT INTO roles (nombre, descripcion, empresa_id, password_hash, icono, color, activo, es_sistema)
                    VALUES (@nombre, @desc, @eid, @hash, @icono, @color, @activo, FALSE)
                    RETURNING id
                    """, new Dictionary<string, object?>
                {
                    ["nombre"] = request.Nombre.Trim(),
                    ["desc"] = request.Descripcion,
                    ["eid"] = empresaId,
                    ["hash"] = hash,
                    ["icono"] = request.Icono,
                    ["color"] = request.Color,
                    ["activo"] = request.Activo
                });
                roleId = Convert.ToInt32(inserted[0]["id"]);
            }
            else
            {
                roleId = id.Value;
                var current = await tx.QueryAsync("SELECT es_sistema, password_hash FROM roles WHERE id = @id",
                    new Dictionary<string, object?> { ["id"] = roleId });
                if (current.Count == 0) throw new AppException("Rol no encontrado.", 404);

                await tx.ExecuteAsync("""
                    UPDATE roles SET nombre = @nombre, descripcion = @desc, empresa_id = @eid,
                        password_hash = COALESCE(@hash, password_hash), icono = @icono, color = @color,
                        activo = @activo
                    WHERE id = @id
                    """, new Dictionary<string, object?>
                {
                    ["id"] = roleId,
                    ["nombre"] = request.Nombre.Trim(),
                    ["desc"] = request.Descripcion,
                    ["eid"] = empresaId,
                    ["hash"] = hash,
                    ["icono"] = request.Icono,
                    ["color"] = request.Color,
                    ["activo"] = request.Activo
                });
            }

            if (request.Permisos is not null)
            {
                await tx.ExecuteAsync("DELETE FROM rol_permisos WHERE rol_id = @id",
                    new Dictionary<string, object?> { ["id"] = roleId });

                foreach (var permission in request.Permisos.Distinct(StringComparer.OrdinalIgnoreCase))
                {
                    var parts = permission.Split(':', 2);
                    if (parts.Length != 2) continue;
                    await tx.ExecuteAsync("""
                        INSERT INTO rol_permisos (rol_id, permiso_id)
                        SELECT @rid, p.id FROM permisos p
                        WHERE p.modulo = @mod AND p.accion = @acc::accion_permiso
                        ON CONFLICT DO NOTHING
                        """, new Dictionary<string, object?>
                    {
                        ["rid"] = roleId, ["mod"] = parts[0], ["acc"] = parts[1]
                    });
                }
            }

            await EnsureRepresentativeAsync(tx, roleId, hash, ct);
            return roleId;
        }, ct);

        return roleId;
    }

    public async Task DeleteRoleAsync(int id, CurrentSession session, CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync("SELECT es_sistema, empresa_id FROM roles WHERE id = @id",
            new Dictionary<string, object?> { ["id"] = id }, ct);
        var role = rows.FirstOrDefault() ?? throw new AppException("Rol no encontrado.", 404);
        if (Convert.ToBoolean(role["es_sistema"]))
            throw new AppException("El rol Administrador no puede eliminarse.");
        if (session.RoleEmpresaId is > 0 && role["empresa_id"] is not null &&
            Convert.ToInt32(role["empresa_id"]) != session.RoleEmpresaId)
            throw new AppException("No puede eliminar roles de otra empresa.", 403);

        await _db.ExecuteAsync("UPDATE roles SET activo = FALSE WHERE id = @id",
            new Dictionary<string, object?> { ["id"] = id }, ct);
        await _db.ExecuteAsync("""
            INSERT INTO auditoria (usuario_id, accion, entidad, entidad_id, ip)
            VALUES (@uid, 'eliminar', 'roles', @eid, @ip)
            """, new Dictionary<string, object?>
        {
            ["uid"] = session.UserId, ["eid"] = id.ToString(), ["ip"] = (string?)null
        }, ct);
    }

    public async Task ChangePasswordAsync(CurrentSession session, string current, string next,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(next) || next.Length < 8)
            throw new AppException("La nueva contraseña debe tener al menos 8 caracteres.");

        var rows = await _db.QueryAsync("SELECT password_hash FROM roles WHERE id = @id",
            new Dictionary<string, object?> { ["id"] = session.RoleId }, ct);
        var hash = rows.FirstOrDefault()?["password_hash"] as string;
        if (hash is null || !_hasher.Verify(current, hash))
            throw new AppException("La contraseña actual no es correcta.", 401);

        var newHash = _hasher.Hash(next);
        await _db.TransactionAsync(async tx =>
        {
            await tx.ExecuteAsync("UPDATE roles SET password_hash = @hash WHERE id = @id",
                new Dictionary<string, object?> { ["hash"] = newHash, ["id"] = session.RoleId });
            await tx.ExecuteAsync("""
                UPDATE usuarios SET password_hash = @hash, actualizado_en = sigfv_now()
                WHERE es_representante AND id IN (SELECT usuario_id FROM usuario_roles WHERE rol_id = @id)
                """, new Dictionary<string, object?> { ["hash"] = newHash, ["id"] = session.RoleId });
            await tx.ExecuteAsync("""
                INSERT INTO auditoria (usuario_id, accion, entidad, entidad_id, ip)
                VALUES (@uid, 'cambiar_password', 'roles', @eid, NULL)
                """, new Dictionary<string, object?>
            {
                ["uid"] = session.UserId, ["eid"] = session.RoleId.ToString()
            });
            return true;
        }, ct);
    }

    private static async Task EnsureRepresentativeAsync(IDbTransaction tx, int roleId, string? newHash,
        CancellationToken ct)
    {
        var linked = await tx.QueryAsync("SELECT usuario_id FROM usuario_roles WHERE rol_id = @id LIMIT 1",
            new Dictionary<string, object?> { ["id"] = roleId }, ct);
        if (linked.Count > 0)
        {
            if (newHash is not null)
            {
                await tx.ExecuteAsync("""
                    UPDATE usuarios SET password_hash = @hash, actualizado_en = sigfv_now()
                    WHERE es_representante AND id = @uid
                    """, new Dictionary<string, object?>
                {
                    ["hash"] = newHash, ["uid"] = linked[0]["usuario_id"]
                });
            }
            return;
        }

        var role = await tx.QueryAsync("SELECT nombre, password_hash FROM roles WHERE id = @id",
            new Dictionary<string, object?> { ["id"] = roleId }, ct);
        var roleName = Convert.ToString(role[0]["nombre"]) ?? $"Rol {roleId}";
        var hash = newHash ?? role[0]["password_hash"] as string;
        if (hash is null) return;

        var inserted = await tx.QueryAsync("""
            INSERT INTO usuarios (nombre_usuario, correo, nombres, apellidos, password_hash, es_representante)
            VALUES (@user, @mail, 'Acceso', @role, @hash, TRUE)
            RETURNING id
            """, new Dictionary<string, object?>
        {
            ["user"] = $"rol_{roleId}",
            ["mail"] = $"rol_{roleId}@sigfv.local",
            ["role"] = roleName,
            ["hash"] = hash
        });
        var userId = Convert.ToInt32(inserted[0]["id"]);
        await tx.ExecuteAsync("INSERT INTO usuario_roles (usuario_id, rol_id) VALUES (@uid, @rid)",
            new Dictionary<string, object?> { ["uid"] = userId, ["rid"] = roleId });
    }

    public async Task<List<CompanySummary>> CompaniesAsync(CurrentSession session, CancellationToken ct = default)
    {
        var parameters = new Dictionary<string, object?>();
        var filter = "";
        if (session.RoleEmpresaId is > 0)
        {
            filter = "WHERE e.id = @eid";
            parameters["eid"] = session.RoleEmpresaId;
        }

        var rows = await _db.QueryAsync($"""
            SELECT e.id, e.ruc, e.razon_social, e.activo,
              (SELECT COUNT(*)::int FROM unidades_mineras u WHERE u.empresa_id = e.id) unidades,
              (SELECT COUNT(*)::int FROM vehiculos v JOIN unidades_mineras u ON u.id = v.unidad_minera_id
                 WHERE u.empresa_id = e.id AND v.eliminado_en IS NULL) vehiculos,
              (SELECT COUNT(*)::int FROM conductores c JOIN unidades_mineras u ON u.id = c.unidad_minera_id
                 WHERE u.empresa_id = e.id AND c.eliminado_en IS NULL) conductores
            FROM empresas e
            {filter}
            ORDER BY e.razon_social
            """, parameters, ct);

        return rows.Select(r => new CompanySummary(
            Convert.ToInt32(r["id"]), Convert.ToString(r["ruc"]) ?? "",
            Convert.ToString(r["razon_social"]) ?? "", Convert.ToBoolean(r["activo"]),
            Convert.ToInt32(r["unidades"]), Convert.ToInt32(r["vehiculos"]), Convert.ToInt32(r["conductores"])))
            .ToList();
    }

    public async Task<Dictionary<string, object?>> CompanyDetailAsync(int id, CurrentSession session,
        CancellationToken ct = default)
    {
        if (session.RoleEmpresaId is > 0 && session.RoleEmpresaId != id)
            throw new AppException("No puede consultar otra empresa.", 403);

        var parameters = new Dictionary<string, object?> { ["id"] = id };
        var company = (await _db.QueryAsync("""
            SELECT id, ruc, razon_social, direccion, telefono, correo, contacto, notas, activo,
                   creado_en, actualizado_en
            FROM empresas WHERE id = @id
            """, parameters, ct)).FirstOrDefault() ?? throw new AppException("Empresa no encontrada.", 404);

        var units = await _db.QueryAsync("""
            SELECT id, codigo, nombre, ubicacion, activo FROM unidades_mineras
            WHERE empresa_id = @id ORDER BY nombre
            """, parameters, ct);

        var roles = await _db.QueryAsync("""
            SELECT r.id, r.nombre, r.descripcion, r.activo, (r.password_hash IS NOT NULL) tiene_password,
                   (SELECT array_agg(p.modulo || ':' || p.accion)
                    FROM rol_permisos rp JOIN permisos p ON p.id = rp.permiso_id
                    WHERE rp.rol_id = r.id) permisos
            FROM roles r
            WHERE r.empresa_id = @id
            ORDER BY r.nombre
            """, parameters, ct);

        var globalRoles = await _db.QueryAsync("""
            SELECT r.id, r.nombre, r.descripcion, r.activo, (r.password_hash IS NOT NULL) tiene_password,
                   (SELECT array_agg(p.modulo || ':' || p.accion)
                    FROM rol_permisos rp JOIN permisos p ON p.id = rp.permiso_id
                    WHERE rp.rol_id = r.id) permisos
            FROM roles r
            WHERE r.empresa_id IS NULL AND r.activo
            ORDER BY r.nombre
            """, ct: ct);

        var vehicles = await _db.QueryAsync("""
            SELECT v.id, v.codigo_interno codigo, v.placa, v.kilometraje km,
                   (m.nombre || ' ' || mo.nombre) modelo, e.nombre estado
            FROM vehiculos v
            JOIN unidades_mineras u ON u.id = v.unidad_minera_id
            LEFT JOIN modelos mo ON mo.id = v.modelo_id
            LEFT JOIN marcas m ON m.id = mo.marca_id
            LEFT JOIN estados_vehiculo e ON e.id = v.estado_id
            WHERE u.empresa_id = @id AND v.eliminado_en IS NULL
            ORDER BY v.codigo_interno
            """, parameters, ct);

        var drivers = await _db.QueryAsync("""
            SELECT c.id, c.codigo, (c.nombres || ' ' || c.apellidos) nombre, c.documento_identidad documento,
                   c.telefono, c.estado, u.nombre unidad
            FROM conductores c
            JOIN unidades_mineras u ON u.id = c.unidad_minera_id
            WHERE u.empresa_id = @id AND c.eliminado_en IS NULL
            ORDER BY c.apellidos, c.nombres
            """, parameters, ct);

        var pendingDocs = await _db.QueryAsync("""
            SELECT COUNT(*)::int n FROM documentos d
            LEFT JOIN vehiculos v ON v.id = d.vehiculo_id
            LEFT JOIN conductores c ON c.id = d.conductor_id
            LEFT JOIN unidades_mineras uv ON uv.id = v.unidad_minera_id
            LEFT JOIN unidades_mineras uc ON uc.id = c.unidad_minera_id
            WHERE d.eliminado_en IS NULL AND d.fecha_vencimiento <= sigfv_today() + 30
              AND (uv.empresa_id = @id OR uc.empresa_id = @id)
            """, parameters, ct);

        var requirements = (Convert.ToString(company["notas"]) ?? "")
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToList();

        return new Dictionary<string, object?>
        {
            ["empresa"] = company,
            ["resumen"] = new Dictionary<string, object?>
            {
                ["unidades"] = units.Count,
                ["vehiculos"] = vehicles.Count,
                ["conductores"] = drivers.Count,
                ["documentosPorVencer"] = pendingDocs.Count > 0 ? pendingDocs[0]["n"] : 0
            },
            ["unidades"] = units,
            ["roles"] = roles.Concat(globalRoles).Select(r => new Dictionary<string, object?>
            {
                ["id"] = r["id"],
                ["nombre"] = r["nombre"],
                ["descripcion"] = r["descripcion"],
                ["activo"] = r["activo"],
                ["tienePassword"] = r["tiene_password"],
                ["global"] = globalRoles.Any(g => Convert.ToInt32(g["id"]) == Convert.ToInt32(r["id"])),
                ["permisos"] = ToList(r["permisos"])
            }).ToList(),
            ["vehiculos"] = vehicles,
            ["conductores"] = drivers,
            ["requerimientos"] = requirements
        };
    }

    public async Task<int> SaveCompanyAsync(int? id, CompanySaveRequest request, CurrentSession session,
        CancellationToken ct = default)
    {
        if (session.RoleEmpresaId is > 0 && session.RoleEmpresaId != (id ?? session.RoleEmpresaId))
            throw new AppException("No puede modificar otra empresa.", 403);

        var ruc = (request.Ruc ?? "").Trim();
        var name = (request.RazonSocial ?? "").Trim();
        if (name.Length < 3)
            throw new AppException("La razón social es obligatoria (mínimo 3 caracteres).");
        if (ruc.Length is > 0 and < 8)
            throw new AppException("El RUC debe tener al menos 8 caracteres.");

        var values = new Dictionary<string, object?>
        {
            ["ruc"] = ruc.Length == 0 ? null : ruc,
            ["razon_social"] = name,
            ["direccion"] = Text(request.Direccion),
            ["telefono"] = Text(request.Telefono),
            ["correo"] = Text(request.Correo),
            ["contacto"] = Text(request.Contacto),
            ["notas"] = Text(request.Notas),
            ["activo"] = request.Activo
        };

        var companyId = await _db.TransactionAsync(async tx =>
        {
            var companyId = id ?? 0;
            if (id is null)
            {
                var inserted = await tx.QueryAsync("""
                    INSERT INTO empresas (ruc, razon_social, direccion, telefono, correo, contacto, notas, activo)
                    VALUES (@ruc, @razon_social, @direccion, @telefono, @correo, @contacto, @notas, @activo)
                    RETURNING id
                    """, values);
                companyId = Convert.ToInt32(inserted[0]["id"]);
            }
            else
            {
                var exists = await tx.QueryAsync("SELECT id FROM empresas WHERE id = @id",
                    new Dictionary<string, object?> { ["id"] = companyId });
                if (exists.Count == 0) throw new AppException("Empresa no encontrada.", 404);
                values["id"] = companyId;
                await tx.ExecuteAsync("""
                    UPDATE empresas SET ruc = @ruc, razon_social = @razon_social, direccion = @direccion,
                        telefono = @telefono, correo = @correo, contacto = @contacto, notas = @notas,
                        activo = @activo
                    WHERE id = @id
                    """, values);
            }

            await tx.ExecuteAsync("""
                INSERT INTO auditoria (usuario_id, accion, entidad, entidad_id, valores_nuevos, ip)
                VALUES (@uid, @accion, 'empresas', @eid, @nuevo::jsonb, NULL)
                """, new Dictionary<string, object?>
            {
                ["uid"] = session.UserId,
                ["accion"] = id is null ? "crear" : "editar",
                ["eid"] = companyId.ToString(),
                ["nuevo"] = System.Text.Json.JsonSerializer.Serialize(values)
            });

            return companyId;
        }, ct);

        return companyId;
    }

    public async Task<List<Dictionary<string, object?>>> AuditAsync(CurrentSession session, int limit = 200,
        CancellationToken ct = default)
    {
        if (session.RoleEmpresaId is > 0)
            throw new AppException("La auditoría completa solo está disponible para roles globales.", 403);

        limit = Math.Clamp(limit, 1, 1000);
        return await _db.QueryAsync("""
            SELECT a.id, a.accion, a.entidad, a.entidad_id, a.valores_nuevos, a.ip, a.fecha,
                   COALESCE((u.nombres || ' ' || u.apellidos), u.nombre_usuario, 'Sistema') usuario
            FROM auditoria a
            LEFT JOIN usuarios u ON u.id = a.usuario_id
            ORDER BY a.id DESC
            LIMIT @lim
            """, new Dictionary<string, object?> { ["lim"] = limit }, ct);
    }

    private static List<string> ToList(object? value)
    {
        if (value is string[] array) return array.ToList();
        if (value is IEnumerable<string> enumerable) return enumerable.ToList();
        return new List<string>();
    }

    private static string? Text(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
