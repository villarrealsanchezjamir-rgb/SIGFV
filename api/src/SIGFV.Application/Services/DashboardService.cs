using SIGFV.Application.Abstractions;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

public sealed class DashboardService
{
    private readonly IDb _db;

    public DashboardService(IDb db) => _db = db;

    private const string Scope = "SELECT id FROM unidades_mineras WHERE @eid = 0 OR empresa_id = @eid";

    public async Task<Dictionary<string, object?>> GetAsync(CurrentSession session, CancellationToken ct = default)
    {
        var eid = session.EmpresaId > 0 ? session.EmpresaId : 0;
        var cfg = await _db.QueryAsync(
            "SELECT valor FROM configuraciones WHERE clave = 'alerta.documentos.dias'", ct: ct);
        var dias = 30;
        if (cfg.Count > 0) int.TryParse(Convert.ToString(cfg[0]["valor"]), out dias);
        if (dias < 0) dias = 30;

        var parameters = new Dictionary<string, object?> { ["eid"] = eid, ["dias"] = dias };

        var k = (await _db.QueryAsync($"""
            SELECT
              (SELECT COUNT(*)::int FROM vehiculos v
                 WHERE v.eliminado_en IS NULL AND v.unidad_minera_id IN ({Scope})) total,
              (SELECT COUNT(*)::int FROM conductores c
                 WHERE c.estado = 'activo' AND c.eliminado_en IS NULL AND c.unidad_minera_id IN ({Scope})) conductores,
              (SELECT COUNT(*)::int FROM inspecciones i JOIN vehiculos v ON v.id = i.vehiculo_id
                 WHERE i.resultado = 'no_conforme' AND i.fecha_hora >= sigfv_now() - INTERVAL '30 days'
                   AND v.unidad_minera_id IN ({Scope})) insp_nc,
              (SELECT COUNT(*)::int FROM documentos d
                 LEFT JOIN vehiculos v ON v.id = d.vehiculo_id
                 LEFT JOIN conductores c ON c.id = d.conductor_id
                 WHERE d.eliminado_en IS NULL AND d.fecha_vencimiento <= sigfv_today() + @dias
                   AND (v.unidad_minera_id IN ({Scope}) OR c.unidad_minera_id IN ({Scope}))) docs,
              (SELECT COUNT(*)::int FROM mantenimientos m JOIN vehiculos v ON v.id = m.vehiculo_id
                 WHERE m.estado = 'programado' AND m.eliminado_en IS NULL
                   AND v.unidad_minera_id IN ({Scope})) mant,
              (SELECT COALESCE(SUM(a.litros), 0) FROM abastecimientos a JOIN vehiculos v ON v.id = a.vehiculo_id
                 WHERE a.fecha >= date_trunc('month', sigfv_now())
                   AND v.unidad_minera_id IN ({Scope})) litros,
              (SELECT COUNT(*)::int FROM incidentes i JOIN vehiculos v ON v.id = i.vehiculo_id
                 WHERE i.estado_investigacion <> 'cerrado' AND i.eliminado_en IS NULL
                   AND v.unidad_minera_id IN ({Scope})) incidentes
            """, parameters, ct)).FirstOrDefault() ?? new Dictionary<string, object?>();

        var estados = await _db.QueryAsync($"""
            SELECT e.nombre, e.color, COUNT(v.id)::int n
            FROM estados_vehiculo e
            LEFT JOIN vehiculos v ON v.estado_id = e.id AND v.eliminado_en IS NULL
                 AND v.unidad_minera_id IN ({Scope})
            GROUP BY e.id, e.nombre, e.color ORDER BY e.id
            """, parameters, ct);

        var mant = await _db.QueryAsync($"""
            SELECT v.codigo_interno vehiculo, t.nombre tipo, m.fecha
            FROM mantenimientos m
            JOIN vehiculos v ON v.id = m.vehiculo_id
            JOIN tipos_mantenimiento t ON t.id = m.tipo_id
            WHERE m.estado = 'programado' AND m.eliminado_en IS NULL
              AND v.unidad_minera_id IN ({Scope})
            ORDER BY m.fecha LIMIT 6
            """, parameters, ct);

        var docs = await _db.QueryAsync($"""
            SELECT COALESCE(v.codigo_interno, (c.nombres || ' ' || c.apellidos)) titular,
                   td.nombre documento, d.fecha_vencimiento vence
            FROM documentos d
            JOIN tipos_documento td ON td.id = d.tipo_id
            LEFT JOIN vehiculos v ON v.id = d.vehiculo_id
            LEFT JOIN conductores c ON c.id = d.conductor_id
            WHERE d.eliminado_en IS NULL AND d.fecha_vencimiento <= sigfv_today() + @dias
              AND (v.unidad_minera_id IN ({Scope}) OR c.unidad_minera_id IN ({Scope}))
            ORDER BY d.fecha_vencimiento LIMIT 6
            """, parameters, ct);

        return new Dictionary<string, object?>
        {
            ["k"] = k,
            ["estados"] = estados,
            ["mant"] = mant,
            ["docs"] = docs
        };
    }
}
