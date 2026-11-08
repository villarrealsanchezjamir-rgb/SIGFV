using System.Collections.Concurrent;
using System.Globalization;
using System.Text.RegularExpressions;
using SIGFV.Application.Abstractions;
using SIGFV.Application.Models;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

/// <summary>
/// Registro público de empresas clientes y solicitud de vehículos.
/// El administrador revisa cada solicitud, aprueba o rechaza, crea la
/// empresa/unidad minera y asigna vehículos y conductores.
/// </summary>
public sealed class SolicitudService
{
    private static readonly Regex CorreoRegex =
        new(@"^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$", RegexOptions.Compiled);

    private static readonly ConcurrentDictionary<string, List<DateTime>> Intentos = new();

    private readonly IDb _db;

    public SolicitudService(IDb db) => _db = db;

    /* ---------------- Formulario público ---------------- */

    public async Task<Dictionary<string, object?>> ContextoAsync(CancellationToken ct = default)
    {
        var tipos = await _db.QueryAsync(
            "SELECT id, nombre FROM tipos_vehiculo WHERE activo ORDER BY nombre", null, ct);
        var categorias = await _db.QueryAsync(
            "SELECT id, nombre FROM categorias_vehiculo WHERE activo ORDER BY nombre", null, ct);

        return new Dictionary<string, object?>
        {
            ["tipos"] = tipos,
            ["categorias"] = categorias,
            ["requisitos"] = new[]
            {
                "RUC de 11 dígitos y razón social vigente.",
                "Persona de contacto con teléfono y correo verificables.",
                "Cantidad, tipo de vehículo y fechas estimadas del servicio.",
                "Indique si requiere conductor y los requisitos operativos especiales.",
                "El administrador revisará la solicitud y confirmará la disponibilidad de la flota."
            },
            ["nota"] = "La solicitud no genera un contrato automáticamente. El administrador validará la información y asignará los vehículos disponibles."
        };
    }

    public async Task<Dictionary<string, object?>> CreateAsync(SolicitudCreateRequest request, string? ip,
        CancellationToken ct = default)
    {
        // Campo trampa: los bots suelen completarlo.
        if (!string.IsNullOrWhiteSpace(request.Website))
            throw new AppException("No se pudo procesar la solicitud.");

        Throttle(ip);

        var ruc = new string((request.Ruc ?? "").Where(char.IsDigit).ToArray());
        var razonSocial = Clean(request.RazonSocial, 150);
        var contacto = Clean(request.Contacto, 120);
        var cargo = Clean(request.Cargo, 80);
        var telefono = Clean(request.Telefono, 30);
        var correo = Clean(request.Correo, 120).ToLowerInvariant();
        var direccion = Clean(request.Direccion, 200);
        var actividad = Clean(request.Actividad, 150);
        var unidad = Clean(request.UnidadSolicitada, 150);
        var requisitos = Clean(request.Requisitos, 2000);
        var observaciones = Clean(request.Observaciones, 1000);

        if (ruc.Length != 11) throw new AppException("Ingrese un RUC válido de 11 dígitos.");
        if (razonSocial.Length < 3) throw new AppException("Ingrese la razón social de la empresa.");
        if (contacto.Length < 3) throw new AppException("Ingrese el nombre de la persona de contacto.");
        if (telefono.Count(char.IsDigit) < 6) throw new AppException("Ingrese un teléfono de contacto válido.");
        if (!CorreoRegex.IsMatch(correo)) throw new AppException("Ingrese un correo electrónico válido.");
        if (requisitos.Length < 10) throw new AppException("Describa los requisitos o el servicio que necesita.");

        var vehiculos = (request.Vehiculos ?? Array.Empty<SolicitudVehiculoRequest>()).Take(10).ToList();
        if (vehiculos.Count == 0) throw new AppException("Agregue al menos un vehículo a la solicitud.");

        foreach (var v in vehiculos)
        {
            if (v.TipoVehiculoId is null or <= 0)
                throw new AppException("Seleccione el tipo de vehículo solicitado.");
            if (v.Cantidad is < 1 or > 50)
                throw new AppException("La cantidad de vehículos debe estar entre 1 y 50.");
            if (v.FechaInicio is not null && v.FechaFin is not null && v.FechaFin < v.FechaInicio)
                throw new AppException("La fecha final no puede ser anterior a la fecha de inicio.");
        }

        var origen = string.Equals(request.Origen, "apk", StringComparison.OrdinalIgnoreCase) ? "apk" : "web";

        return await _db.TransactionAsync(async tx =>
        {
            var created = await tx.QueryAsync("""
                INSERT INTO solicitudes_empresa
                    (codigo, ruc, razon_social, contacto, cargo, telefono, correo, direccion, actividad,
                     unidad_solicitada, requisitos, observaciones, origen, ip)
                VALUES
                    ('SOL-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('solicitud_codigo_seq')::text, 4, '0'),
                     @ruc, @razon, @contacto, @cargo, @telefono, @correo, @direccion, @actividad,
                     @unidad, @requisitos, @observaciones, @origen, @ip)
                RETURNING id, codigo
                """, new Dictionary<string, object?>
            {
                ["ruc"] = ruc,
                ["razon"] = razonSocial,
                ["contacto"] = contacto,
                ["cargo"] = Nullable(cargo),
                ["telefono"] = telefono,
                ["correo"] = correo,
                ["direccion"] = Nullable(direccion),
                ["actividad"] = Nullable(actividad),
                ["unidad"] = Nullable(unidad),
                ["requisitos"] = requisitos,
                ["observaciones"] = Nullable(observaciones),
                ["origen"] = origen,
                ["ip"] = Nullable(ip ?? "")
            }, ct);

            var solicitudId = Convert.ToInt32(created[0]["id"]);
            var codigo = Convert.ToString(created[0]["codigo"], CultureInfo.InvariantCulture) ?? "";

            foreach (var v in vehiculos)
            {
                await tx.ExecuteAsync("""
                    INSERT INTO solicitud_vehiculos
                        (solicitud_id, tipo_vehiculo_id, categoria_vehiculo_id, cantidad,
                         fecha_inicio, fecha_fin, requiere_conductor, detalles)
                    VALUES
                        (@sid, @tipo, @categoria, @cantidad, @inicio, @fin, @conductor, @detalles)
                    """, new Dictionary<string, object?>
                {
                    ["sid"] = solicitudId,
                    ["tipo"] = v.TipoVehiculoId,
                    ["categoria"] = v.CategoriaVehiculoId is > 0 ? v.CategoriaVehiculoId : null,
                    ["cantidad"] = v.Cantidad,
                    ["inicio"] = v.FechaInicio?.Date,
                    ["fin"] = v.FechaFin?.Date,
                    ["conductor"] = v.RequiereConductor,
                    ["detalles"] = Nullable(Clean(v.Detalles, 500))
                }, ct);
            }

            return new Dictionary<string, object?>
            {
                ["id"] = solicitudId,
                ["codigo"] = codigo
            };
        }, ct);
    }

    /* ---------------- Bandeja del administrador ---------------- */

    public async Task<List<Dictionary<string, object?>>> ListAsync(string? estado, string? q,
        CancellationToken ct = default)
    {
        var filtro = (estado ?? "").Trim().ToLowerInvariant();
        if (filtro is not ("" or "pendiente" or "aprobada" or "rechazada")) filtro = "";
        var term = Clean(q, 80);

        return await _db.QueryAsync("""
            SELECT s.id, s.codigo, s.ruc, s.razon_social, s.contacto, s.telefono, s.correo,
                   s.unidad_solicitada, s.estado, s.creado_en, s.revisado_en, s.revisado_por,
                   s.origen, s.respuesta_admin,
                   COALESCE(emp.razon_social, '') empresa_creada,
                   (SELECT COUNT(*) FROM solicitud_vehiculos sv WHERE sv.solicitud_id = s.id) items,
                   (SELECT COALESCE(SUM(sv.cantidad), 0) FROM solicitud_vehiculos sv
                     WHERE sv.solicitud_id = s.id) unidades,
                   (SELECT COUNT(*) FROM solicitud_vehiculos sv
                     WHERE sv.solicitud_id = s.id AND sv.vehiculo_id IS NOT NULL) asignados
            FROM solicitudes_empresa s
            LEFT JOIN empresas emp ON emp.id = s.empresa_id
            WHERE (@estado = '' OR s.estado = @estado)
              AND (@q = '' OR s.ruc ILIKE '%' || @q || '%' OR s.razon_social ILIKE '%' || @q || '%'
                   OR s.contacto ILIKE '%' || @q || '%' OR s.codigo ILIKE '%' || @q || '%'
                   OR s.correo ILIKE '%' || @q || '%')
            ORDER BY CASE s.estado WHEN 'pendiente' THEN 0 WHEN 'aprobada' THEN 1 ELSE 2 END,
                     s.creado_en DESC
            LIMIT 200
            """, new Dictionary<string, object?> { ["estado"] = filtro, ["q"] = term }, ct);
    }

    public async Task<Dictionary<string, object?>> DetailAsync(int id, CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync("""
            SELECT s.*, COALESCE(emp.razon_social, '') empresa_creada,
                   COALESCE(um.nombre, '') unidad_creada
            FROM solicitudes_empresa s
            LEFT JOIN empresas emp ON emp.id = s.empresa_id
            LEFT JOIN unidades_mineras um ON um.id = s.unidad_minera_id
            WHERE s.id = @id
            """, new Dictionary<string, object?> { ["id"] = id }, ct);

        if (rows.Count == 0) throw new AppException("La solicitud no existe.", 404);

        var solicitud = rows[0];
        solicitud["items"] = await _db.QueryAsync("""
            SELECT sv.id, sv.cantidad, sv.fecha_inicio, sv.fecha_fin, sv.requiere_conductor,
                   sv.detalles, sv.estado, sv.tipo_vehiculo_id, sv.categoria_vehiculo_id,
                   sv.vehiculo_id, sv.conductor_id,
                   COALESCE(tv.nombre, '') tipo, COALESCE(cv.nombre, '') categoria,
                   COALESCE(v.codigo_interno, '') vehiculo_codigo, COALESCE(v.placa, '') vehiculo_placa,
                   COALESCE(c.nombres || ' ' || c.apellidos, '') conductor
            FROM solicitud_vehiculos sv
            LEFT JOIN tipos_vehiculo tv ON tv.id = sv.tipo_vehiculo_id
            LEFT JOIN categorias_vehiculo cv ON cv.id = sv.categoria_vehiculo_id
            LEFT JOIN vehiculos v ON v.id = sv.vehiculo_id
            LEFT JOIN conductores c ON c.id = sv.conductor_id
            WHERE sv.solicitud_id = @id
            ORDER BY sv.id
            """, new Dictionary<string, object?> { ["id"] = id }, ct);

        return solicitud;
    }

    public async Task<Dictionary<string, object?>> AsignablesAsync(CancellationToken ct = default)
    {
        var vehiculos = await _db.QueryAsync("""
            SELECT v.id, v.codigo_interno, COALESCE(v.placa, '') placa,
                   COALESCE(ev.nombre, '') estado, COALESCE(um.nombre, '') unidad
            FROM vehiculos v
            LEFT JOIN estados_vehiculo ev ON ev.id = v.estado_id
            LEFT JOIN unidades_mineras um ON um.id = v.unidad_minera_id
            WHERE v.eliminado_en IS NULL AND v.activo
            ORDER BY v.codigo_interno
            """, null, ct);

        var conductores = await _db.QueryAsync("""
            SELECT c.id, c.codigo, c.nombres, c.apellidos,
                   COALESCE(c.documento_identidad, '') documento,
                   COALESCE(to_char(MAX(l.fecha_vencimiento), 'YYYY-MM-DD'), '') licencia_vence
            FROM conductores c
            LEFT JOIN licencias l ON l.conductor_id = c.id
            WHERE c.eliminado_en IS NULL AND c.estado = 'activo'
            GROUP BY c.id
            ORDER BY c.apellidos, c.nombres
            """, null, ct);

        return new Dictionary<string, object?>
        {
            ["vehiculos"] = vehiculos,
            ["conductores"] = conductores
        };
    }

    public async Task<Dictionary<string, object?>> ApproveAsync(int id, SolicitudDecision decision,
        CurrentSession session, CancellationToken ct = default)
    {
        return await _db.TransactionAsync(async tx =>
        {
            var solRows = await tx.QueryAsync(
                "SELECT * FROM solicitudes_empresa WHERE id = @id FOR UPDATE",
                new Dictionary<string, object?> { ["id"] = id }, ct);
            if (solRows.Count == 0) throw new AppException("La solicitud no existe.", 404);

            var sol = solRows[0];
            if (Str(sol["estado"]) != "pendiente")
                throw new AppException("Esta solicitud ya fue revisada.", 409);

            var ruc = Str(sol["ruc"]);
            var razon = Str(sol["razon_social"]);
            var contacto = Str(sol["contacto"]);
            var telefono = Str(sol["telefono"]);
            var correo = Str(sol["correo"]);
            var direccion = Str(sol["direccion"]);
            var requisitos = Str(sol["requisitos"]);
            var codigo = Str(sol["codigo"]);

            // 1) Empresa: se reutiliza si el RUC ya existe.
            var empresaRows = await tx.QueryAsync(
                "SELECT id FROM empresas WHERE ruc = @ruc LIMIT 1",
                new Dictionary<string, object?> { ["ruc"] = ruc }, ct);

            int empresaId;
            if (empresaRows.Count == 0)
            {
                var nueva = await tx.QueryAsync("""
                    INSERT INTO empresas (ruc, razon_social, direccion, telefono, correo, contacto, notas, activo)
                    VALUES (@ruc, @razon, @direccion, @telefono, @correo, @contacto, @notas, TRUE)
                    RETURNING id
                    """, new Dictionary<string, object?>
                {
                    ["ruc"] = ruc,
                    ["razon"] = razon,
                    ["direccion"] = Nullable(direccion),
                    ["telefono"] = Nullable(telefono),
                    ["correo"] = Nullable(correo),
                    ["contacto"] = Nullable(contacto),
                    ["notas"] = Nullable(requisitos)
                }, ct);
                empresaId = Convert.ToInt32(nueva[0]["id"]);
            }
            else
            {
                empresaId = Convert.ToInt32(empresaRows[0]["id"]);
                await tx.ExecuteAsync("""
                    UPDATE empresas
                    SET razon_social = @razon,
                        direccion = COALESCE(NULLIF(@direccion, ''), direccion),
                        telefono = COALESCE(NULLIF(@telefono, ''), telefono),
                        correo = COALESCE(NULLIF(@correo, ''), correo),
                        contacto = COALESCE(NULLIF(@contacto, ''), contacto),
                        actualizado_en = sigfv_now()
                    WHERE id = @id
                    """, new Dictionary<string, object?>
                {
                    ["razon"] = razon,
                    ["direccion"] = direccion,
                    ["telefono"] = telefono,
                    ["correo"] = correo,
                    ["contacto"] = contacto,
                    ["id"] = empresaId
                }, ct);
            }

            // 2) Unidad minera del cliente (se crea si no existe).
            var unidadNombre = Clean(decision?.UnidadNombre, 150);
            if (unidadNombre.Length == 0) unidadNombre = Clean(Str(sol["unidad_solicitada"]), 150);
            if (unidadNombre.Length == 0) unidadNombre = razon[..Math.Min(razon.Length, 150)];

            var unidadRows = await tx.QueryAsync("""
                SELECT id FROM unidades_mineras
                WHERE empresa_id = @eid AND lower(nombre) = lower(@nombre)
                LIMIT 1
                """, new Dictionary<string, object?> { ["eid"] = empresaId, ["nombre"] = unidadNombre }, ct);

            int unidadId;
            if (unidadRows.Count == 0)
            {
                var countRows = await tx.QueryAsync(
                    "SELECT COUNT(*) n FROM unidades_mineras WHERE empresa_id = @eid",
                    new Dictionary<string, object?> { ["eid"] = empresaId }, ct);
                var correlativo = Convert.ToInt32(countRows[0]["n"], CultureInfo.InvariantCulture) + 1;
                string codigoUnidad;
                while (true)
                {
                    codigoUnidad = $"UM-{empresaId}-{correlativo:00}";
                    var usado = await tx.QueryAsync(
                        "SELECT 1 FROM unidades_mineras WHERE codigo = @codigo LIMIT 1",
                        new Dictionary<string, object?> { ["codigo"] = codigoUnidad }, ct);
                    if (usado.Count == 0) break;
                    correlativo++;
                }

                var creada = await tx.QueryAsync("""
                    INSERT INTO unidades_mineras (empresa_id, codigo, nombre, ubicacion, activo)
                    VALUES (@eid, @codigo, @nombre, @ubicacion, TRUE)
                    RETURNING id
                    """, new Dictionary<string, object?>
                {
                    ["eid"] = empresaId,
                    ["codigo"] = codigoUnidad,
                    ["nombre"] = unidadNombre,
                    ["ubicacion"] = Nullable(direccion)
                }, ct);
                unidadId = Convert.ToInt32(creada[0]["id"]);
            }
            else
            {
                unidadId = Convert.ToInt32(unidadRows[0]["id"]);
            }

            // 3) Responsable de la asignación (primer usuario activo).
            var usuarioRows = await tx.QueryAsync(
                "SELECT id FROM usuarios WHERE activo AND eliminado_en IS NULL ORDER BY id LIMIT 1", null, ct);
            int? responsableId = usuarioRows.Count > 0 ? Convert.ToInt32(usuarioRows[0]["id"]) : null;

            var items = await tx.QueryAsync(
                "SELECT * FROM solicitud_vehiculos WHERE solicitud_id = @id ORDER BY id",
                new Dictionary<string, object?> { ["id"] = id }, ct);
            var porId = items.ToDictionary(x => Convert.ToInt32(x["id"]));

            var usados = new HashSet<int>();
            var asignados = 0;

            foreach (var asignacion in decision?.Items ?? Array.Empty<SolicitudAsignacion>())
            {
                if (asignacion.VehiculoId is null or <= 0) continue;
                if (!porId.TryGetValue(asignacion.ItemId, out var item))
                    throw new AppException("Uno de los vehículos solicitados ya no existe en la solicitud.");
                if (!usados.Add(asignacion.VehiculoId.Value))
                    throw new AppException("No se puede asignar el mismo vehículo a dos pedidos de la solicitud.");

                var vehiculo = await tx.QueryAsync("""
                    SELECT id FROM vehiculos
                    WHERE id = @id AND eliminado_en IS NULL AND activo
                    """, new Dictionary<string, object?> { ["id"] = asignacion.VehiculoId.Value }, ct);
                if (vehiculo.Count == 0)
                    throw new AppException("El vehículo seleccionado ya no está disponible.");

                await tx.ExecuteAsync("""
                    UPDATE vehiculos
                    SET unidad_minera_id = @um, actualizado_en = sigfv_now()
                    WHERE id = @id
                    """, new Dictionary<string, object?>
                {
                    ["um"] = unidadId,
                    ["id"] = asignacion.VehiculoId.Value
                }, ct);

                if (responsableId is not null)
                {
                    var inicio = item["fecha_inicio"] is DateTime d ? d.Date : DateTime.Today;
                    var fin = item["fecha_fin"] is DateTime f ? f.Date : inicio.AddDays(30);
                    if (fin <= inicio) fin = inicio.AddDays(1);

                    await tx.ExecuteAsync("""
                        INSERT INTO asignaciones
                            (vehiculo_id, conductor_id, responsable_id, unidad_minera_id, tipo,
                             fecha_inicio, fecha_fin, estado, observaciones)
                        VALUES
                            (@vehiculo, @conductor, @responsable, @unidad, 'alquiler'::tipo_asignacion,
                             @inicio, @fin, 'programada'::estado_asignacion, @observaciones)
                        """, new Dictionary<string, object?>
                    {
                        ["vehiculo"] = asignacion.VehiculoId.Value,
                        ["conductor"] = asignacion.ConductorId is > 0 ? asignacion.ConductorId : null,
                        ["responsable"] = responsableId.Value,
                        ["unidad"] = unidadId,
                        ["inicio"] = inicio,
                        ["fin"] = fin,
                        ["observaciones"] = Clean($"Solicitud {codigo}: {Str(item["detalles"])}", 300)
                    }, ct);
                }

                await tx.ExecuteAsync("""
                    UPDATE solicitud_vehiculos
                    SET vehiculo_id = @vehiculo, conductor_id = @conductor, estado = 'asignado'
                    WHERE id = @id
                    """, new Dictionary<string, object?>
                {
                    ["vehiculo"] = asignacion.VehiculoId.Value,
                    ["conductor"] = asignacion.ConductorId is > 0 ? asignacion.ConductorId : null,
                    ["id"] = asignacion.ItemId
                }, ct);

                asignados++;
            }

            await tx.ExecuteAsync("""
                UPDATE solicitud_vehiculos
                SET estado = 'sin_asignar'
                WHERE solicitud_id = @id AND vehiculo_id IS NULL
                """, new Dictionary<string, object?> { ["id"] = id }, ct);

            var revisadoPor = string.IsNullOrWhiteSpace(session.Operador) ? session.RoleName : session.Operador;
            var respuesta = Clean(decision?.Observacion, 1000);

            await tx.ExecuteAsync("""
                UPDATE solicitudes_empresa
                SET estado = 'aprobada', empresa_id = @empresa, unidad_minera_id = @unidad,
                    revisado_por = @por, revisado_en = sigfv_now(),
                    respuesta_admin = @respuesta, actualizado_en = sigfv_now()
                WHERE id = @id
                """, new Dictionary<string, object?>
            {
                ["empresa"] = empresaId,
                ["unidad"] = unidadId,
                ["por"] = Clean(revisadoPor, 120),
                ["respuesta"] = Nullable(respuesta),
                ["id"] = id
            }, ct);

            return new Dictionary<string, object?>
            {
                ["ok"] = true,
                ["codigo"] = codigo,
                ["empresaId"] = empresaId,
                ["unidadId"] = unidadId,
                ["asignados"] = asignados
            };
        }, ct);
    }

    public async Task RejectAsync(int id, string? observacion, CurrentSession session,
        CancellationToken ct = default)
    {
        var motivo = Clean(observacion, 1000);
        if (motivo.Length < 5)
            throw new AppException("Indique el motivo del rechazo para informar a la empresa.");

        var revisadoPor = string.IsNullOrWhiteSpace(session.Operador) ? session.RoleName : session.Operador;
        var affected = await _db.ExecuteAsync("""
            UPDATE solicitudes_empresa
            SET estado = 'rechazada', revisado_por = @por, revisado_en = sigfv_now(),
                respuesta_admin = @motivo, actualizado_en = sigfv_now()
            WHERE id = @id AND estado = 'pendiente'
            """, new Dictionary<string, object?>
        {
            ["por"] = Clean(revisadoPor, 120),
            ["motivo"] = motivo,
            ["id"] = id
        }, ct);

        if (affected == 0)
            throw new AppException("La solicitud no existe o ya fue revisada.", 409);
    }

    public async Task<int> PendingCountAsync(CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync(
            "SELECT COUNT(*) n FROM solicitudes_empresa WHERE estado = 'pendiente'", null, ct);
        return rows.Count == 0 ? 0 : Convert.ToInt32(rows[0]["n"], CultureInfo.InvariantCulture);
    }

    /* ---------------- Utilidades ---------------- */

    private static string Clean(string? value, int max)
    {
        var text = (value ?? "").Trim();
        if (text.Length > max) text = text[..max];
        return text;
    }

    private static string Str(object? value)
        => value is null or DBNull ? "" : Convert.ToString(value, CultureInfo.InvariantCulture) ?? "";

    private static object? Nullable(string value) => string.IsNullOrWhiteSpace(value) ? null : value;

    private static void Throttle(string? ip)
    {
        var key = string.IsNullOrWhiteSpace(ip) ? "desconocida" : ip;
        var now = DateTime.UtcNow;
        var list = Intentos.GetOrAdd(key, _ => new List<DateTime>());
        lock (list)
        {
            list.RemoveAll(t => (now - t).TotalHours >= 1);
            if (list.Count >= 6)
                throw new AppException("Se recibieron varias solicitudes desde esta conexión. Intente nuevamente en una hora.", 429);
            list.Add(now);
        }
        if (Intentos.Count > 5000) Intentos.Clear();
    }
}
