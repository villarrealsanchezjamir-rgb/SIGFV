namespace SIGFV.Application.Resources;

public sealed record ColumnDef(string Key, string Label, string? Kind = null);

public sealed record OptionDef(string Value, string Label);

public sealed record FieldDef(
    string Name,
    string Label,
    string Type = "text",
    bool Required = false,
    string? Catalog = null,
    IReadOnlyList<OptionDef>? Options = null,
    bool Virtual = false);

public sealed record ResourceDef(
    string Key,
    string Mod,
    string Label,
    string Group,
    string Icon,
    string Table,
    string? Soft,
    string Select,
    string From,
    IReadOnlyList<string> Search,
    IReadOnlyList<ColumnDef> Cols,
    IReadOnlyList<FieldDef> Fields,
    IReadOnlyList<string>? Auto = null,
    string? CompanyFilter = null,
    bool HasAfter = false,
    bool HasOne = false);

public static class ResourceCatalog
{
    private static FieldDef F(string name, string label, string type = "text", bool required = false,
        string? catalog = null, IReadOnlyList<OptionDef>? options = null, bool isVirtual = false)
        => new(name, label, type, required, catalog, options, isVirtual);

    private static IReadOnlyList<OptionDef> O(params string[] values)
        => values.Select(v => new OptionDef(v, v.Replace('_', ' '))).ToList();

    private static readonly IReadOnlyList<OptionDef> Combustibles =
        O("diesel", "gasolina", "glp", "gnv", "electrico", "otro");

    private static ResourceDef CatalogResource(string key, string label, string select, string from,
        IReadOnlyList<ColumnDef> cols, IReadOnlyList<FieldDef> fields, string? companyFilter = null,
        IReadOnlyList<string>? search = null)
        => new(key, "configuracion", label, "Administración", "settings", key, "activo", select, from,
            search ?? new[] { "a." + cols[0].Key }, cols, fields, CompanyFilter: companyFilter);

    public static readonly IReadOnlyDictionary<string, ResourceDef> All = Build();

    private static Dictionary<string, ResourceDef> Build()
    {
        var list = new List<ResourceDef>
        {
            new(
                "vehiculos", "vehiculos", "Vehículos", "Operación", "truck", "vehiculos", "eliminado_en",
                "a.id,a.codigo_interno codigo,a.placa,(ma.nombre || ' ' || mo.nombre) modelo,tv.nombre tipo,a.kilometraje km,um.nombre unidad,ev.nombre estado,ev.color",
                "FROM vehiculos a JOIN modelos mo ON mo.id=a.modelo_id JOIN marcas ma ON ma.id=mo.marca_id JOIN tipos_vehiculo tv ON tv.id=a.tipo_id JOIN estados_vehiculo ev ON ev.id=a.estado_id JOIN unidades_mineras um ON um.id=a.unidad_minera_id",
                new[] { "a.codigo_interno", "a.placa", "a.vin", "a.numero_serie" },
                new[]
                {
                    new ColumnDef("codigo", "Código"), new ColumnDef("placa", "Placa"),
                    new ColumnDef("tipo", "Tipo"), new ColumnDef("modelo", "Marca / modelo"),
                    new ColumnDef("km", "Km"), new ColumnDef("unidad", "Unidad minera"),
                    new ColumnDef("estado", "Estado", "badge")
                },
                new[]
                {
                    F("codigo_interno", "Código interno", required: true), F("placa", "Placa"),
                    F("modelo_id", "Marca y modelo", "select", true, "modelos"),
                    F("tipo_id", "Tipo de vehículo", "select", true, "tipos_vehiculo"),
                    F("categoria_id", "Categoría", "select", false, "categorias_vehiculo"),
                    F("anio_fabricacion", "Año de fabricación", "number"), F("numero_serie", "Número de serie"),
                    F("vin", "VIN"), F("numero_motor", "Número de motor"),
                    F("kilometraje", "Kilometraje", "number"), F("capacidad", "Capacidad"),
                    F("tipo_combustible", "Combustible", "select", options: Combustibles),
                    F("fecha_adquisicion", "Fecha de adquisición", "date"),
                    F("propietario_id", "Propietario", "select", true, "propietarios"),
                    F("estado_id", "Estado operativo", "select", true, "estados_vehiculo"),
                    F("unidad_minera_id", "Unidad minera", "select", true, "unidades_mineras"),
                    F("observaciones", "Observaciones", "textarea")
                },
                CompanyFilter: "um.empresa_id = {0}", HasAfter: true),

            new(
                "conductores", "conductores", "Conductores", "Operación", "id-card", "conductores", "eliminado_en",
                "a.id,a.codigo,(a.nombres || ' ' || a.apellidos) nombre,a.documento_identidad dni,a.telefono,a.estado,(SELECT MAX(fecha_vencimiento) FROM licencias l WHERE l.conductor_id=a.id) licencia_vence",
                "FROM conductores a",
                new[] { "a.codigo", "a.nombres", "a.apellidos", "a.documento_identidad" },
                new[]
                {
                    new ColumnDef("codigo", "Código"), new ColumnDef("nombre", "Nombre"),
                    new ColumnDef("dni", "Documento"), new ColumnDef("telefono", "Teléfono"),
                    new ColumnDef("licencia_vence", "Licencia vence"), new ColumnDef("estado", "Estado", "badge")
                },
                new[]
                {
                    F("codigo", "Código de conductor", required: true), F("nombres", "Nombres", required: true),
                    F("apellidos", "Apellidos", required: true),
                    F("documento_identidad", "Documento de identidad", required: true),
                    F("telefono", "Teléfono"), F("correo", "Correo"), F("direccion", "Dirección"),
                    F("unidad_minera_id", "Unidad minera", "select", false, "unidades_mineras"),
                    F("estado", "Estado", "select", options: O("activo", "inactivo", "inhabilitado")),
                    F("fecha_incorporacion", "Fecha de incorporación", "date"),
                    F("lic_categoria_id", "Categoría de licencia", "select", false, "categorias_licencia", isVirtual: true),
                    F("lic_numero", "Número de licencia", isVirtual: true),
                    F("lic_emision", "Emisión de licencia", "date", isVirtual: true),
                    F("lic_vencimiento", "Vencimiento de licencia", "date", isVirtual: true),
                    F("observaciones", "Observaciones", "textarea")
                },
                CompanyFilter: "a.unidad_minera_id IN (SELECT id FROM unidades_mineras WHERE empresa_id = {0})",
                HasAfter: true, HasOne: true),

            new(
                "asignaciones", "asignaciones", "Asignaciones", "Operación", "calendar-range", "asignaciones", null,
                "a.id,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,(c.nombres || ' ' || c.apellidos) conductor,um.nombre unidad,a.tipo,a.fecha_inicio inicio,a.fecha_fin fin,a.estado",
                "FROM asignaciones a JOIN vehiculos v ON v.id=a.vehiculo_id LEFT JOIN conductores c ON c.id=a.conductor_id JOIN unidades_mineras um ON um.id=a.unidad_minera_id",
                new[] { "v.codigo_interno", "v.placa", "c.apellidos", "c.nombres" },
                new[]
                {
                    new ColumnDef("vehiculo", "Vehículo"), new ColumnDef("conductor", "Conductor"),
                    new ColumnDef("unidad", "Unidad minera"), new ColumnDef("tipo", "Tipo"),
                    new ColumnDef("inicio", "Inicio"), new ColumnDef("fin", "Fin"),
                    new ColumnDef("estado", "Estado", "badge")
                },
                new[]
                {
                    F("vehiculo_id", "Vehículo", "select", true, "vehiculos"),
                    F("conductor_id", "Conductor", "select", false, "conductores"),
                    F("unidad_minera_id", "Unidad minera", "select", true, "unidades_mineras"),
                    F("tipo", "Tipo de asignación", "select",
                        options: O("operativa", "alquiler", "temporal", "permanente")),
                    F("fecha_inicio", "Inicio", "datetime", true), F("fecha_fin", "Fin", "datetime"),
                    F("estado", "Estado", "select",
                        options: O("programada", "activa", "finalizada", "cancelada")),
                    F("observaciones", "Observaciones", "textarea")
                },
                Auto: new[] { "responsable_id" }, CompanyFilter: "um.empresa_id = {0}"),

            new(
                "mantenimientos", "mantenimiento", "Mantenimiento", "Mantenimiento", "wrench", "mantenimientos", "eliminado_en",
                "a.id,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,tm.nombre tipo,a.fecha,a.costo,a.proximo_fecha proximo,a.estado",
                "FROM mantenimientos a JOIN vehiculos v ON v.id=a.vehiculo_id JOIN tipos_mantenimiento tm ON tm.id=a.tipo_id",
                new[] { "v.codigo_interno", "v.placa", "a.descripcion" },
                new[]
                {
                    new ColumnDef("vehiculo", "Vehículo"), new ColumnDef("tipo", "Tipo"),
                    new ColumnDef("fecha", "Fecha"), new ColumnDef("costo", "Costo"),
                    new ColumnDef("proximo", "Próximo"), new ColumnDef("estado", "Estado", "badge")
                },
                new[]
                {
                    F("vehiculo_id", "Vehículo", "select", true, "vehiculos"),
                    F("tipo_id", "Tipo", "select", true, "tipos_mantenimiento"),
                    F("fecha", "Fecha", "date", true), F("kilometraje", "Kilometraje", "number"),
                    F("taller_id", "Taller", "select", false, "talleres"), F("costo", "Costo", "number"),
                    F("proximo_fecha", "Próximo mantenimiento", "date"),
                    F("proximo_km", "Próximo (km)", "number"),
                    F("estado", "Estado", "select",
                        options: O("programado", "en_proceso", "completado", "cancelado")),
                    F("descripcion", "Descripción", "textarea"),
                    F("diagnostico", "Diagnóstico", "textarea"),
                    F("trabajo_realizado", "Trabajo realizado", "textarea")
                },
                Auto: new[] { "responsable_id" },
                CompanyFilter: "v.unidad_minera_id IN (SELECT id FROM unidades_mineras WHERE empresa_id = {0})"),

            new(
                "documentos", "documentos", "Documentación", "Logística", "file-text", "documentos", "eliminado_en",
                "a.id,td.nombre documento,COALESCE(v.codigo_interno,(c.nombres || ' ' || c.apellidos)) titular,a.numero,a.fecha_vencimiento vence,CASE WHEN a.fecha_vencimiento < sigfv_today() THEN 'vencido' WHEN a.fecha_vencimiento <= sigfv_today() + 30 THEN 'por vencer' ELSE 'vigente' END estado",
                "FROM documentos a JOIN tipos_documento td ON td.id=a.tipo_id LEFT JOIN vehiculos v ON v.id=a.vehiculo_id LEFT JOIN conductores c ON c.id=a.conductor_id",
                new[] { "td.nombre", "a.numero", "v.codigo_interno", "c.apellidos" },
                new[]
                {
                    new ColumnDef("documento", "Documento"), new ColumnDef("titular", "Vehículo / conductor"),
                    new ColumnDef("numero", "Número"), new ColumnDef("vence", "Vence"),
                    new ColumnDef("estado", "Estado", "badge")
                },
                new[]
                {
                    F("tipo_id", "Tipo de documento", "select", true, "tipos_documento"),
                    F("vehiculo_id", "Vehículo (si aplica)", "select", false, "vehiculos"),
                    F("conductor_id", "Conductor (si aplica)", "select", false, "conductores"),
                    F("numero", "Número"), F("fecha_emision", "Emisión", "date"),
                    F("fecha_vencimiento", "Vencimiento", "date", true),
                    F("observaciones", "Observaciones")
                },
                CompanyFilter: "(v.unidad_minera_id IN (SELECT id FROM unidades_mineras WHERE empresa_id = {0}) OR c.unidad_minera_id IN (SELECT id FROM unidades_mineras WHERE empresa_id = {0}))"),

            new(
                "inspecciones", "inspecciones", "Inspecciones", "Seguridad", "clipboard-check", "inspecciones", null,
                "a.id,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,(c.nombres || ' ' || c.apellidos) conductor,a.fecha_hora fecha,a.resultado,CASE WHEN a.bloquea_vehiculo THEN 'Sí' ELSE 'No' END bloqueo",
                "FROM inspecciones a JOIN vehiculos v ON v.id=a.vehiculo_id JOIN conductores c ON c.id=a.conductor_id",
                new[] { "v.codigo_interno", "v.placa", "c.apellidos" },
                new[]
                {
                    new ColumnDef("vehiculo", "Vehículo"), new ColumnDef("conductor", "Conductor"),
                    new ColumnDef("fecha", "Fecha"), new ColumnDef("resultado", "Resultado", "badge"),
                    new ColumnDef("bloqueo", "Bloqueó vehículo")
                },
                new[]
                {
                    F("vehiculo_id", "Vehículo", "select", true, "vehiculos"),
                    F("conductor_id", "Conductor", "select", true, "conductores"),
                    F("fecha_hora", "Fecha y hora", "datetime", true),
                    F("resultado", "Resultado", "select", true,
                        options: O("conforme", "conforme_con_observaciones", "no_conforme")),
                    F("bloquea_vehiculo", "Bloquear uso del vehículo", "select",
                        options: new[] { new OptionDef("0", "No"), new OptionDef("1", "Sí (pasa a fuera de servicio)") }),
                    F("observaciones", "Observaciones", "textarea")
                },
                CompanyFilter: "v.unidad_minera_id IN (SELECT id FROM unidades_mineras WHERE empresa_id = {0})",
                HasAfter: true),

            new(
                "abastecimientos", "combustible", "Combustible", "Logística", "fuel", "abastecimientos", null,
                "a.id,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,a.fecha,a.tipo_combustible tipo,a.litros,a.precio_litro precio,a.importe_total importe",
                "FROM abastecimientos a JOIN vehiculos v ON v.id=a.vehiculo_id",
                new[] { "v.codigo_interno", "v.placa" },
                new[]
                {
                    new ColumnDef("vehiculo", "Vehículo"), new ColumnDef("fecha", "Fecha"),
                    new ColumnDef("tipo", "Combustible"), new ColumnDef("litros", "Litros"),
                    new ColumnDef("precio", "Precio/L"), new ColumnDef("importe", "Importe")
                },
                new[]
                {
                    F("vehiculo_id", "Vehículo", "select", true, "vehiculos"),
                    F("fecha", "Fecha y hora", "datetime", true),
                    F("tipo_combustible", "Combustible", "select", true, options: Combustibles),
                    F("litros", "Litros", "number", true),
                    F("precio_litro", "Precio por litro", "number", true),
                    F("kilometraje", "Kilometraje", "number"),
                    F("proveedor_id", "Estación / proveedor", "select", false, "proveedores_combustible"),
                    F("observaciones", "Observaciones")
                },
                Auto: new[] { "responsable_id" },
                CompanyFilter: "v.unidad_minera_id IN (SELECT id FROM unidades_mineras WHERE empresa_id = {0})"),

            new(
                "incidentes", "incidentes", "Incidentes", "Seguridad", "triangle-alert", "incidentes", "eliminado_en",
                "a.id,a.codigo,(v.codigo_interno || ' ' || COALESCE(v.placa,'')) vehiculo,ti.nombre tipo,g.nombre gravedad,a.fecha_hora fecha,a.estado_investigacion estado",
                "FROM incidentes a JOIN vehiculos v ON v.id=a.vehiculo_id JOIN tipos_incidente ti ON ti.id=a.tipo_id JOIN niveles_gravedad g ON g.id=a.gravedad_id",
                new[] { "a.codigo", "v.codigo_interno", "v.placa", "a.descripcion" },
                new[]
                {
                    new ColumnDef("codigo", "Código"), new ColumnDef("vehiculo", "Vehículo"),
                    new ColumnDef("tipo", "Tipo"), new ColumnDef("gravedad", "Gravedad"),
                    new ColumnDef("fecha", "Fecha"), new ColumnDef("estado", "Investigación", "badge")
                },
                new[]
                {
                    F("vehiculo_id", "Vehículo", "select", true, "vehiculos"),
                    F("conductor_id", "Conductor", "select", false, "conductores"),
                    F("fecha_hora", "Fecha y hora", "datetime", true),
                    F("ubicacion", "Ubicación"),
                    F("tipo_id", "Tipo", "select", true, "tipos_incidente"),
                    F("gravedad_id", "Gravedad", "select", true, "niveles_gravedad"),
                    F("estado_investigacion", "Estado de investigación", "select",
                        options: O("pendiente", "en_investigacion", "cerrado")),
                    F("descripcion", "Descripción", "textarea", true),
                    F("danos", "Daños registrados", "textarea"),
                    F("medidas_adoptadas", "Medidas adoptadas", "textarea")
                },
                Auto: new[] { "reportado_por" },
                CompanyFilter: "v.unidad_minera_id IN (SELECT id FROM unidades_mineras WHERE empresa_id = {0})"),

            new(
                "usuarios", "usuarios", "Usuarios", "Administración", "shield", "usuarios", "eliminado_en",
                "a.id,a.nombre_usuario usuario,(a.nombres || ' ' || a.apellidos) nombre,a.correo,(SELECT STRING_AGG(r.nombre, ',') FROM usuario_roles ur JOIN roles r ON r.id=ur.rol_id WHERE ur.usuario_id=a.id) rol,CASE WHEN a.activo THEN 'activo' ELSE 'inactivo' END estado",
                "FROM usuarios a",
                new[] { "a.nombre_usuario", "a.nombres", "a.apellidos", "a.correo" },
                new[]
                {
                    new ColumnDef("usuario", "Usuario"), new ColumnDef("nombre", "Nombre"),
                    new ColumnDef("correo", "Correo"), new ColumnDef("rol", "Rol"),
                    new ColumnDef("estado", "Estado", "badge")
                },
                new[]
                {
                    F("nombre_usuario", "Usuario", required: true), F("correo", "Correo", required: true),
                    F("nombres", "Nombres", required: true), F("apellidos", "Apellidos", required: true),
                    F("rol_id", "Rol", "select", true, "roles", isVirtual: true),
                    F("password", "Contraseña (mín. 8; en blanco = no cambiar)", "password", isVirtual: true),
                    F("activo", "Estado", "select",
                        options: new[] { new OptionDef("1", "Activo"), new OptionDef("0", "Inactivo") })
                },
                HasAfter: true, HasOne: true),

            CatalogResource("empresas", "Empresas", "a.id,a.ruc,a.razon_social,a.contacto,a.telefono,a.correo",
                "FROM empresas a",
                new[]
                {
                    new ColumnDef("ruc", "RUC"), new ColumnDef("razon_social", "Razón social"),
                    new ColumnDef("contacto", "Contacto"), new ColumnDef("telefono", "Teléfono"),
                    new ColumnDef("correo", "Correo")
                },
                new[]
                {
                    F("ruc", "RUC", required: true), F("razon_social", "Razón social", required: true),
                    F("contacto", "Persona de contacto"), F("direccion", "Dirección"),
                    F("telefono", "Teléfono"), F("correo", "Correo"),
                    F("notas", "Notas / alcance del servicio", "textarea")
                },
                companyFilter: "a.id = {0}", search: new[] { "a.razon_social", "a.ruc" }),

            CatalogResource("unidades_mineras", "Unidades mineras", "a.id,a.codigo,a.nombre,a.ubicacion",
                "FROM unidades_mineras a",
                new[]
                {
                    new ColumnDef("codigo", "Código"), new ColumnDef("nombre", "Nombre"),
                    new ColumnDef("ubicacion", "Ubicación")
                },
                new[]
                {
                    F("empresa_id", "Empresa", "select", true, "empresas"),
                    F("codigo", "Código", required: true), F("nombre", "Nombre", required: true),
                    F("ubicacion", "Ubicación")
                },
                companyFilter: "a.empresa_id = {0}"),

            CatalogResource("marcas", "Marcas", "a.id,a.nombre", "FROM marcas a",
                new[] { new ColumnDef("nombre", "Nombre") },
                new[] { F("nombre", "Nombre", required: true) }),

            CatalogResource("modelos", "Modelos", "a.id,ma.nombre marca,a.nombre",
                "FROM modelos a JOIN marcas ma ON ma.id=a.marca_id",
                new[] { new ColumnDef("marca", "Marca"), new ColumnDef("nombre", "Modelo") },
                new[]
                {
                    F("marca_id", "Marca", "select", true, "marcas"),
                    F("nombre", "Modelo", required: true)
                },
                search: new[] { "a.nombre", "ma.nombre" }),

            CatalogResource("propietarios", "Propietarios", "a.id,a.nombre,a.documento", "FROM propietarios a",
                new[] { new ColumnDef("nombre", "Nombre"), new ColumnDef("documento", "Documento") },
                new[] { F("nombre", "Nombre", required: true), F("documento", "Documento") }),

            CatalogResource("proveedores_combustible", "Estaciones de combustible",
                "a.id,a.nombre,a.ubicacion", "FROM proveedores_combustible a",
                new[] { new ColumnDef("nombre", "Nombre"), new ColumnDef("ubicacion", "Ubicación") },
                new[]
                {
                    F("nombre", "Nombre", required: true), F("ruc", "RUC"), F("ubicacion", "Ubicación")
                }),

            CatalogResource("talleres", "Talleres", "a.id,a.nombre,a.direccion", "FROM talleres a",
                new[] { new ColumnDef("nombre", "Nombre"), new ColumnDef("direccion", "Dirección") },
                new[] { F("nombre", "Nombre", required: true), F("direccion", "Dirección") })
        };

        return list.ToDictionary(r => r.Key, StringComparer.OrdinalIgnoreCase);
    }

    public static ResourceDef Get(string key)
        => All.TryGetValue(key, out var r) ? r : throw new KeyNotFoundException("Módulo no encontrado.");

    /// <summary>Módulos que aparecen en el menú pero se resuelven con pantallas propias.</summary>
    public static readonly IReadOnlyList<(string Key, string Mod, string Label, string Group, string Icon)> Custom =
        new[]
        {
            ("roles", "usuarios", "Roles y accesos", "Administración", "key"),
            ("reportes", "reportes", "Reportes", "Administración", "chart")
        };
}
