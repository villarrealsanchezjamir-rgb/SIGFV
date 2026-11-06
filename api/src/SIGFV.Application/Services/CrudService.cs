using System.Globalization;
using System.Text;
using SIGFV.Application.Abstractions;
using SIGFV.Application.Models;
using SIGFV.Application.Resources;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

/// <summary>
/// CRUD genérico dirigido por catálogo. Aplica permisos, aislamiento por empresa,
/// campos virtuales, ganchos de negocio y auditoría en una sola transacción.
/// </summary>
public sealed class CrudService
{
    private readonly IDb _db;
    private readonly IPasswordHasher _hasher;

    public CrudService(IDb db, IPasswordHasher hasher)
    {
        _db = db;
        _hasher = hasher;
    }

    public static ResourceDef Resolve(string key)
    {
        if (!ResourceCatalog.All.TryGetValue(key, out var r))
            throw new AppException("Módulo no encontrado.", 404);
        return r;
    }

    public async Task<PagedResult> ListAsync(string key, CurrentSession session, string? q, int page, int limit,
        CancellationToken ct = default)
    {
        var r = Resolve(key);
        limit = Math.Clamp(limit <= 0 ? 20 : limit, 1, 5000);
        page = Math.Max(1, page);
        var offset = (page - 1) * limit;

        var parameters = new Dictionary<string, object?>();
        var where = BuildWhere(r, session, q, parameters);

        var countRows = await _db.QueryAsync($"SELECT COUNT(*)::int n {r.From} WHERE {where}", parameters, ct);
        var total = countRows.Count > 0 ? Convert.ToInt32(countRows[0]["n"]) : 0;

        parameters["lim"] = limit;
        parameters["off"] = offset;
        var items = await _db.QueryAsync(
            $"SELECT {r.Select} {r.From} WHERE {where} ORDER BY a.id DESC LIMIT @lim OFFSET @off",
            parameters, ct);

        return new PagedResult(total, items);
    }

    public async Task<List<Dictionary<string, object?>>> AllAsync(string key, CurrentSession session, string? q,
        int max = 20000, CancellationToken ct = default)
    {
        var r = Resolve(key);
        var parameters = new Dictionary<string, object?>();
        var where = BuildWhere(r, session, q, parameters);
        parameters["lim"] = Math.Clamp(max, 1, 50000);
        return await _db.QueryAsync(
            $"SELECT {r.Select} {r.From} WHERE {where} ORDER BY a.id DESC LIMIT @lim", parameters, ct);
    }

    public async Task<Dictionary<string, object?>> GetAsync(string key, int id, CurrentSession session,
        CancellationToken ct = default)
    {
        var r = Resolve(key);
        var parameters = new Dictionary<string, object?> { ["id"] = id };
        var where = BuildWhere(r, session, null, parameters);
        var rows = await _db.QueryAsync(
            $"SELECT a.* FROM {Quote(r.Table)} a WHERE a.id = @id AND {where}", parameters, ct);
        var row = rows.FirstOrDefault() ?? throw new AppException("Registro no encontrado.", 404);

        if (r.Key == "conductores")
        {
            var lic = await _db.QueryAsync("""
                SELECT categoria_id lic_categoria_id, numero lic_numero, fecha_emision lic_emision,
                       fecha_vencimiento lic_vencimiento
                FROM licencias WHERE conductor_id = @id ORDER BY id DESC LIMIT 1
                """, new Dictionary<string, object?> { ["id"] = id }, ct);
            if (lic.Count > 0)
                foreach (var (k, v) in lic[0]) row[k] = v;
        }
        else if (r.Key == "usuarios")
        {
            row.Remove("password_hash");
            var ur = await _db.QueryAsync("SELECT rol_id FROM usuario_roles WHERE usuario_id = @id LIMIT 1",
                new Dictionary<string, object?> { ["id"] = id }, ct);
            row["rol_id"] = ur.Count > 0 ? ur[0]["rol_id"] : null;
        }

        return row;
    }

    public Task<SaveResult> CreateAsync(string key, CurrentSession session, IReadOnlyDictionary<string, object?> body,
        string? ip, CancellationToken ct = default)
        => SaveAsync(key, session, null, body, ip, ct);

    public Task<SaveResult> UpdateAsync(string key, CurrentSession session, int id,
        IReadOnlyDictionary<string, object?> body, string? ip, CancellationToken ct = default)
        => SaveAsync(key, session, id, body, ip, ct);

    private async Task<SaveResult> SaveAsync(string key, CurrentSession session, int? id,
        IReadOnlyDictionary<string, object?> body, string? ip, CancellationToken ct)
    {
        var r = Resolve(key);
        var isNew = id is null;

        return await _db.TransactionAsync(async tx =>
        {
            var values = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

            foreach (var f in r.Fields)
            {
                if (f.Virtual) continue;
                var present = body.ContainsKey(f.Name);
                if (!isNew && !present) continue;

                var value = Normalize(f, present ? body[f.Name] : null);
                if (value is null)
                {
                    if (f.Required) throw new AppException($"{f.Label} es obligatorio.");
                    if (isNew) continue;
                    values[f.Name] = null;
                    continue;
                }
                values[f.Name] = value;
            }

            if (r.Table == "usuarios")
            {
                var password = body.TryGetValue("password", out var pv) ? Convert.ToString(pv) : null;
                if (!string.IsNullOrEmpty(password))
                {
                    if (password.Length < 8)
                        throw new AppException("La contraseña debe tener al menos 8 caracteres.");
                    values["password_hash"] = _hasher.Hash(password);
                }
                else if (isNew)
                {
                    throw new AppException("La contraseña es obligatoria.");
                }
            }

            int recordId;
            Dictionary<string, object?>? old = null;

            if (isNew)
            {
                foreach (var auto in r.Auto ?? Array.Empty<string>())
                {
                    if (session.UserId is int uid) values[auto] = uid;
                }
                if (r.Table == "incidentes")
                    values["codigo"] = "INC-" + ToBase36(DateTimeOffset.UtcNow.ToUnixTimeMilliseconds());

                if (values.Count == 0) throw new AppException("No hay datos para guardar.");

                var cols = string.Join(",", values.Keys.Select(Quote));
                var pars = string.Join(",", values.Keys.Select((k, i) => $"@v{i}"));
                var parameters = values.Values.Select((v, i) => (object?)v)
                    .Select((v, i) => (Key: $"v{i}", Value: v)).ToDictionary(x => x.Key, x => x.Value);
                var inserted = await tx.QueryAsync(
                    $"INSERT INTO {Quote(r.Table)} ({cols}) VALUES ({pars}) RETURNING id", parameters);
                recordId = Convert.ToInt32(inserted[0]["id"]);
            }
            else
            {
                recordId = id!.Value;
                var oldRows = await tx.QueryAsync($"SELECT * FROM {Quote(r.Table)} WHERE id = @id",
                    new Dictionary<string, object?> { ["id"] = recordId });
                old = oldRows.FirstOrDefault() ?? throw new AppException("Registro no encontrado.", 404);

                if (values.Count > 0)
                {
                    var sets = string.Join(",", values.Keys.Select((k, i) => $"{Quote(k)} = @v{i}"));
                    var parameters = values.Values.Select((v, i) => (object?)v)
                        .Select((v, i) => (Key: $"v{i}", Value: v))
                        .ToDictionary(x => x.Key, x => x.Value);
                    parameters["id"] = recordId;
                    await tx.ExecuteAsync(
                        $"UPDATE {Quote(r.Table)} SET {sets} WHERE id = @id", parameters);
                }
            }

            await ApplyHooksAsync(tx, r, recordId, body, values, isNew, old, session);

            var auditValues = new Dictionary<string, object?>(values);
            auditValues.Remove("password_hash");
            await tx.ExecuteAsync("""
                INSERT INTO auditoria (usuario_id, accion, entidad, entidad_id, valores_nuevos, ip)
                VALUES (@uid, @accion, @entidad, @eid, @nuevo::jsonb, @ip)
                """, new Dictionary<string, object?>
            {
                ["uid"] = session.UserId,
                ["accion"] = isNew ? "crear" : "editar",
                ["entidad"] = r.Table,
                ["eid"] = recordId.ToString(CultureInfo.InvariantCulture),
                ["nuevo"] = System.Text.Json.JsonSerializer.Serialize(auditValues),
                ["ip"] = ip
            }, ct);

            return new SaveResult(recordId, isNew);
        }, ct);
    }

    public async Task DeleteAsync(string key, CurrentSession session, int id, string? ip,
        CancellationToken ct = default)
    {
        var r = Resolve(key);
        if (r.Soft is null)
            throw new AppException("Este registro es histórico y no puede eliminarse.", 405);
        if (r.Table == "usuarios" && session.UserId == id)
            throw new AppException("No puede eliminar su propio usuario.");

        var set = r.Soft == "activo"
            ? "activo = FALSE"
            : "eliminado_en = sigfv_now()" + (r.Table == "usuarios" ? ", activo = FALSE" : "");

        var affected = await _db.ExecuteAsync(
            $"UPDATE {Quote(r.Table)} SET {set} WHERE id = @id",
            new Dictionary<string, object?> { ["id"] = id }, ct);
        if (affected == 0) throw new AppException("Registro no encontrado.", 404);

        await _db.ExecuteAsync("""
            INSERT INTO auditoria (usuario_id, accion, entidad, entidad_id, ip)
            VALUES (@uid, 'eliminar', @entidad, @eid, @ip)
            """, new Dictionary<string, object?>
        {
            ["uid"] = session.UserId,
            ["entidad"] = r.Table,
            ["eid"] = id.ToString(CultureInfo.InvariantCulture),
            ["ip"] = ip
        }, ct);
    }

    private static string BuildWhere(ResourceDef r, CurrentSession session, string? q,
        Dictionary<string, object?> parameters)
    {
        var conditions = new List<string>
        {
            r.Soft switch
            {
                "eliminado_en" => "a.eliminado_en IS NULL",
                "activo" => "a.activo = TRUE",
                _ => "1=1"
            }
        };

        if (r.Key == "usuarios")
            conditions.Add("a.es_representante = FALSE");

        if (r.CompanyFilter is not null && session.EmpresaId > 0)
            conditions.Add("(" + r.CompanyFilter.Replace("{0}", session.EmpresaId.ToString(CultureInfo.InvariantCulture)) + ")");

        var search = (q ?? string.Empty).Trim();
        if (search.Length > 0 && r.Search.Count > 0)
        {
            parameters["q"] = "%" + search + "%";
            conditions.Add("(" + string.Join(" OR ", r.Search.Select(s => $"{s} ILIKE @q")) + ")");
        }

        return string.Join(" AND ", conditions);
    }

    private static object? Normalize(FieldDef f, object? raw)
    {
        if (raw is null) return null;

        if (raw is bool b)
            return f.Name is "activo" or "bloquea_vehiculo" ? b : b;

        var text = Convert.ToString(raw, CultureInfo.InvariantCulture);
        if (text is null) return null;
        text = text.Trim();
        if (text.Length == 0) return null;

        if (f.Name is "activo" or "bloquea_vehiculo")
            return text is "1" or "true" or "True" or "si" or "sí" or "SI" or "t" or "yes";

        if (f.Type == "datetime")
        {
            if (text.Contains('T')) text = text.Replace('T', ' ');
            if (text.Length == 16) text += ":00";
            if (text.Length == 10) text += " 00:00:00";
        }

        return text;
    }

    private static async Task ApplyHooksAsync(IDbTransaction tx, ResourceDef r, int id,
        IReadOnlyDictionary<string, object?> body, Dictionary<string, object?> values, bool isNew,
        Dictionary<string, object?>? old, CurrentSession session)
    {
        switch (r.Table)
        {
            case "vehiculos":
            {
                if (values.TryGetValue("estado_id", out var nuevo) && nuevo is not null)
                {
                    var previous = isNew ? null : old?.GetValueOrDefault("estado_id");
                    var changed = isNew || previous is null || Convert.ToInt32(previous) != Convert.ToInt32(nuevo);
                    if (changed)
                    {
                        await tx.ExecuteAsync("""
                            INSERT INTO historial_estados_vehiculo
                                (vehiculo_id, estado_anterior_id, estado_nuevo_id, usuario_id, motivo)
                            VALUES (@vid, @prev, @next, @uid, @motivo)
                            """, new Dictionary<string, object?>
                        {
                            ["vid"] = id,
                            ["prev"] = isNew ? null : previous,
                            ["next"] = Convert.ToInt32(nuevo),
                            ["uid"] = session.UserId,
                            ["motivo"] = isNew ? "Alta del vehículo" : "Cambio de estado"
                        });
                    }
                }
                break;
            }

            case "conductores":
            {
                var numero = body.TryGetValue("lic_numero", out var ln) ? Convert.ToString(ln)?.Trim() : null;
                if (string.IsNullOrEmpty(numero)) break;

                var categoria = body.TryGetValue("lic_categoria_id", out var lc) ? lc : null;
                if (categoria is null || Convert.ToString(categoria)?.Trim().Length == 0)
                    throw new AppException("Seleccione la categoría de la licencia.");

                string? Date(string name) => body.TryGetValue(name, out var d)
                    ? Convert.ToString(d)?.Trim() is { Length: > 0 } s ? s : null
                    : null;

                var values2 = new object?[]
                {
                    Convert.ToInt32(categoria), numero, Date("lic_emision"), Date("lic_vencimiento")
                };

                var existing = await tx.QueryAsync(
                    "SELECT id FROM licencias WHERE conductor_id = @id ORDER BY id DESC LIMIT 1",
                    new Dictionary<string, object?> { ["id"] = id });

                if (existing.Count > 0)
                {
                    await tx.ExecuteAsync("""
                        UPDATE licencias SET categoria_id = @cat, numero = @num,
                            fecha_emision = COALESCE(@emi::date, fecha_emision),
                            fecha_vencimiento = COALESCE(@ven::date, fecha_vencimiento)
                        WHERE id = @id
                        """, new Dictionary<string, object?>
                    {
                        ["cat"] = values2[0], ["num"] = values2[1], ["emi"] = values2[2],
                        ["ven"] = values2[3], ["id"] = existing[0]["id"]
                    });
                }
                else
                {
                    await tx.ExecuteAsync("""
                        INSERT INTO licencias (conductor_id, categoria_id, numero, fecha_emision, fecha_vencimiento)
                        VALUES (@cid, @cat, @num, COALESCE(@emi::date, sigfv_today()), COALESCE(@ven::date, sigfv_today()))
                        """, new Dictionary<string, object?>
                    {
                        ["cid"] = id, ["cat"] = values2[0], ["num"] = values2[1],
                        ["emi"] = values2[2], ["ven"] = values2[3]
                    });
                }
                break;
            }

            case "inspecciones":
            {
                if (!isNew) break;
                var resultado = values.GetValueOrDefault("resultado")?.ToString();
                var bloquea = values.GetValueOrDefault("bloquea_vehiculo") as bool? ?? false;
                if (resultado != "no_conforme" || !bloquea) break;
                var vehiculoId = values.GetValueOrDefault("vehiculo_id");
                if (vehiculoId is null) break;

                var estado = await tx.QueryAsync(
                    "SELECT id FROM estados_vehiculo WHERE nombre = 'Fuera de servicio' LIMIT 1");
                if (estado.Count == 0) break;

                var current = await tx.QueryAsync("SELECT estado_id FROM vehiculos WHERE id = @id",
                    new Dictionary<string, object?> { ["id"] = Convert.ToInt32(vehiculoId) });
                if (current.Count == 0) break;

                await tx.ExecuteAsync("UPDATE vehiculos SET estado_id = @estado WHERE id = @id",
                    new Dictionary<string, object?>
                    {
                        ["estado"] = estado[0]["id"], ["id"] = Convert.ToInt32(vehiculoId)
                    });

                await tx.ExecuteAsync("""
                    INSERT INTO historial_estados_vehiculo
                        (vehiculo_id, estado_anterior_id, estado_nuevo_id, usuario_id, motivo)
                    VALUES (@vid, @prev, @next, @uid, @motivo)
                    """, new Dictionary<string, object?>
                {
                    ["vid"] = Convert.ToInt32(vehiculoId),
                    ["prev"] = current[0]["estado_id"],
                    ["next"] = estado[0]["id"],
                    ["uid"] = session.UserId,
                    ["motivo"] = "Inspección no conforme #" + id
                });
                break;
            }

            case "usuarios":
            {
                var rol = body.TryGetValue("rol_id", out var rv) ? rv : null;
                var rolId = rol is null ? (int?)null : Convert.ToInt32(rol);
                if (rolId is null) break;
                await tx.ExecuteAsync("DELETE FROM usuario_roles WHERE usuario_id = @id",
                    new Dictionary<string, object?> { ["id"] = id });
                await tx.ExecuteAsync("INSERT INTO usuario_roles (usuario_id, rol_id) VALUES (@id, @rol)",
                    new Dictionary<string, object?> { ["id"] = id, ["rol"] = rolId });
                break;
            }
        }
    }

    private static string Quote(string identifier)
    {
        if (!System.Text.RegularExpressions.Regex.IsMatch(identifier, "^[a-z_][a-z0-9_]*$"))
            throw new AppException("Identificador no válido.");
        return "\"" + identifier + "\"";
    }

    private static string ToBase36(long value)
    {
        const string alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        var sb = new StringBuilder();
        while (value > 0)
        {
            sb.Insert(0, alphabet[(int)(value % 36)]);
            value /= 36;
        }
        return sb.Length == 0 ? "0" : sb.ToString();
    }
}
