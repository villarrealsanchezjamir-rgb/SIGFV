using SIGFV.Application.Abstractions;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

public sealed class NotificationService
{
    private readonly IDb _db;

    public NotificationService(IDb db) => _db = db;

    private const string Scope = "SELECT id FROM unidades_mineras WHERE @eid = 0 OR empresa_id = @eid";

    public Task<List<Dictionary<string, object?>>> GetAsync(CurrentSession session, CancellationToken ct = default)
    {
        var eid = session.EmpresaId > 0 ? session.EmpresaId : 0;
        return _db.QueryAsync($"""
            (SELECT CASE WHEN d.fecha_vencimiento < sigfv_today()
                         THEN 'Documento vencido' ELSE 'Documento por vencer' END tipo,
                    (td.nombre || ' · ' || COALESCE(v.codigo_interno, (c.nombres || ' ' || c.apellidos))) detalle,
                    d.fecha_vencimiento::date fecha
             FROM documentos d
             JOIN tipos_documento td ON td.id = d.tipo_id
             LEFT JOIN vehiculos v ON v.id = d.vehiculo_id
             LEFT JOIN conductores c ON c.id = d.conductor_id
             WHERE d.eliminado_en IS NULL AND d.fecha_vencimiento <= sigfv_today() + 30
               AND (v.unidad_minera_id IN ({Scope}) OR c.unidad_minera_id IN ({Scope})))

            UNION ALL

            (SELECT CASE WHEN l.fecha_vencimiento < sigfv_today()
                         THEN 'Licencia vencida' ELSE 'Licencia por vencer' END,
                    (c.nombres || ' ' || c.apellidos || ' · ' || l.numero),
                    l.fecha_vencimiento::date
             FROM licencias l JOIN conductores c ON c.id = l.conductor_id
             WHERE c.eliminado_en IS NULL AND l.fecha_vencimiento <= sigfv_today() + 30
               AND c.unidad_minera_id IN ({Scope}))

            UNION ALL

            (SELECT 'Inspección no conforme', v.codigo_interno, i.fecha_hora::date
             FROM inspecciones i JOIN vehiculos v ON v.id = i.vehiculo_id
             WHERE i.resultado = 'no_conforme' AND i.fecha_hora >= sigfv_now() - INTERVAL '30 days'
               AND v.unidad_minera_id IN ({Scope}))

            UNION ALL

            (SELECT 'Vehículo fuera de servicio', v.codigo_interno, v.actualizado_en::date
             FROM vehiculos v JOIN estados_vehiculo e ON e.id = v.estado_id
             WHERE e.nombre = 'Fuera de servicio' AND v.eliminado_en IS NULL
               AND v.unidad_minera_id IN ({Scope}))

            UNION ALL

            (SELECT 'Incidente pendiente', (i.codigo || ' · ' || LEFT(i.descripcion, 60)), i.fecha_hora::date
             FROM incidentes i JOIN vehiculos v ON v.id = i.vehiculo_id
             WHERE i.estado_investigacion <> 'cerrado' AND i.eliminado_en IS NULL
               AND v.unidad_minera_id IN ({Scope}))

            ORDER BY fecha LIMIT 100
            """, new Dictionary<string, object?> { ["eid"] = eid }, ct);
    }
}
