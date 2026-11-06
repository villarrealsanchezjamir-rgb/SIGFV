namespace SIGFV.Domain;

public enum PermissionAction
{
    Consultar,
    Crear,
    Editar,
    Eliminar,
    Aprobar,
    Exportar,
    Configurar
}

public static class PermissionActions
{
    public static readonly string[] All =
    {
        "consultar", "crear", "editar", "eliminar", "aprobar", "exportar", "configurar"
    };
}

public sealed record Empresa(int Id, string Ruc, string RazonSocial, string? Contacto, string? Correo,
    string? Telefono, string? Direccion, bool Activo);

public sealed record Rol(int Id, string Nombre, string? Descripcion, int? EmpresaId, bool Activo,
    bool EsSistema, string? Icono, string? Color);

public sealed record CurrentSession(
    int RoleId,
    string RoleName,
    int EmpresaId,
    string EmpresaName,
    int? UserId,
    string Operador,
    IReadOnlySet<string> Permissions,
    int? RoleEmpresaId = null)
{
    public bool IsGlobal => EmpresaId <= 0;

    // Un rol global (RoleEmpresaId nulo) administra todas las empresas aunque haya
    // elegido una empresa concreta para consultar sus datos operativos.
    public bool IsGlobalRole => RoleEmpresaId is null or <= 0;

    public bool Has(string module, string action) => Permissions.Contains(module + ":" + action);
}
