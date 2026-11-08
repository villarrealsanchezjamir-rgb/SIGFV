namespace SIGFV.Application.Resources;

/// <summary>
/// Directorio funcional de módulos: orden de presentación y rol encargado
/// de cada área operativa. Se expone en /api/meta para que la web y la APK
/// muestren quién responde por cada módulo.
/// </summary>
public static class ModuleDirectory
{
    public sealed record Area(string Id, string Title, string Description, string Responsible);

    public static readonly IReadOnlyList<Area> Areas = new[]
    {
        new Area("operaciones", "Gestión de Operaciones", "Flota, conductores y asignaciones", "Supervisor de flota"),
        new Area("mantenimiento", "Gestión de Mantenimiento", "Servicios e inspecciones técnicas", "Responsable de mantenimiento"),
        new Area("logistica", "Gestión Logística", "Combustible y documentación", "Encargado de logística"),
        new Area("seguridad", "Gestión de Seguridad", "Incidentes y acciones correctivas", "Personal de seguridad"),
        new Area("administracion", "Administración", "Usuarios, empresas y catálogos maestros", "Administrador")
    };

    /// <summary>Orden operativo recomendado para los módulos.</summary>
    public static readonly IReadOnlyList<string> Order = new[]
    {
        "vehiculos", "conductores", "asignaciones",
        "mantenimientos", "inspecciones",
        "abastecimientos", "documentos",
        "incidentes",
        "usuarios", "roles", "empresas", "unidades_mineras",
        "marcas", "modelos", "propietarios", "proveedores_combustible", "talleres"
    };

    public static string AreaFor(string key) => key switch
    {
        "vehiculos" or "conductores" or "asignaciones" => "operaciones",
        "mantenimientos" or "inspecciones" => "mantenimiento",
        "abastecimientos" or "documentos" => "logistica",
        "incidentes" => "seguridad",
        _ => "administracion"
    };

    public static string ResponsibleFor(string key)
        => Areas.First(a => a.Id == AreaFor(key)).Responsible;

    public static int OrderOf(string key)
    {
        for (var i = 0; i < Order.Count; i++)
            if (string.Equals(Order[i], key, StringComparison.OrdinalIgnoreCase)) return i;
        return 999;
    }
}
