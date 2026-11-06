using SIGFV.Application.Abstractions;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

public sealed class CatalogService
{
    private readonly IDb _db;

    public CatalogService(IDb db) => _db = db;

    private static readonly Dictionary<string, string> Queries = new(StringComparer.OrdinalIgnoreCase)
    {
        ["modelos"] = "SELECT m.id, (ma.nombre || ' ' || m.nombre) nombre FROM modelos m JOIN marcas ma ON ma.id=m.marca_id WHERE m.activo ORDER BY 2",
        ["tipos_vehiculo"] = Simple("tipos_vehiculo"),
        ["categorias_vehiculo"] = Simple("categorias_vehiculo"),
        ["estados_vehiculo"] = "SELECT id, nombre FROM estados_vehiculo ORDER BY nombre",
        ["propietarios"] = "SELECT id, nombre FROM propietarios WHERE activo ORDER BY nombre",
        ["unidades_mineras"] = "SELECT id, nombre FROM unidades_mineras WHERE activo ORDER BY nombre",
        ["empresas"] = "SELECT id, razon_social nombre FROM empresas WHERE activo ORDER BY razon_social",
        ["marcas"] = Simple("marcas"),
        ["talleres"] = "SELECT id, nombre FROM talleres WHERE activo ORDER BY nombre",
        ["tipos_mantenimiento"] = Simple("tipos_mantenimiento"),
        ["tipos_documento"] = Simple("tipos_documento"),
        ["proveedores_combustible"] = "SELECT id, nombre FROM proveedores_combustible WHERE activo ORDER BY nombre",
        ["tipos_incidente"] = Simple("tipos_incidente"),
        ["niveles_gravedad"] = "SELECT id, nombre FROM niveles_gravedad ORDER BY nombre",
        ["categorias_licencia"] = "SELECT id, codigo nombre FROM categorias_licencia ORDER BY codigo",
        ["roles"] = "SELECT id, nombre FROM roles WHERE activo ORDER BY nombre",
        ["conductores"] = "SELECT id, (nombres || ' ' || apellidos) nombre FROM conductores WHERE eliminado_en IS NULL ORDER BY 2",
        ["vehiculos"] = "SELECT id, (codigo_interno || ' ' || COALESCE(placa,'')) nombre FROM vehiculos WHERE eliminado_en IS NULL ORDER BY 2"
    };

    private static string Simple(string table) => $"SELECT id, nombre FROM {table} WHERE activo ORDER BY nombre";

    public async Task<List<Dictionary<string, object?>>> GetAsync(string name, CurrentSession session,
        CancellationToken ct = default)
    {
        if (!Queries.TryGetValue(name, out var sql))
            throw new AppException("Catálogo no válido.", 404);

        if (session.EmpresaId > 0)
        {
            var eid = session.EmpresaId;
            var scope = "(SELECT id FROM unidades_mineras WHERE empresa_id = @eid)";
            sql = name switch
            {
                "unidades_mineras" => "SELECT id, nombre FROM unidades_mineras WHERE activo AND empresa_id = @eid ORDER BY nombre",
                "empresas" => "SELECT id, razon_social nombre FROM empresas WHERE activo AND id = @eid ORDER BY razon_social",
                "roles" => "SELECT id, nombre FROM roles WHERE activo AND (empresa_id IS NULL OR empresa_id = @eid) ORDER BY nombre",
                "conductores" => "SELECT id, (nombres || ' ' || apellidos) nombre FROM conductores WHERE eliminado_en IS NULL AND unidad_minera_id IN " + scope + " ORDER BY 2",
                "vehiculos" => "SELECT id, (codigo_interno || ' ' || COALESCE(placa,'')) nombre FROM vehiculos WHERE eliminado_en IS NULL AND unidad_minera_id IN " + scope + " ORDER BY 2",
                _ => sql
            };

            return await _db.QueryAsync(sql,
                new Dictionary<string, object?> { ["eid"] = eid }, ct);
        }

        return await _db.QueryAsync(sql, ct: ct);
    }
}
