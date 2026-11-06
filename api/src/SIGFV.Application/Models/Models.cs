using System.Text.Json.Serialization;

namespace SIGFV.Application.Models;

public sealed record LoginRequest(int EmpresaId, int RolId, string Password, string? Operador);

public sealed record LoginResponse(string Token, string Rol, string Empresa, int? EmpresaId, string Operador,
    IReadOnlyList<string> Permisos);

public sealed record CompanyRoleDto(int RolId, string Nombre, string? Descripcion, string? Icono, string? Color,
    bool Global);

public sealed record CompanyDto(int Id, string RazonSocial, string Ruc, IReadOnlyList<CompanyRoleDto> Roles);

public sealed record AuthContextResponse(IReadOnlyList<CompanyDto> Empresas);

public sealed record MetaResponse(string User, IReadOnlyList<string> Roles, string Empresa, int? EmpresaId, int? RolId,
    bool Dashboard, bool Notificaciones, IReadOnlyDictionary<string, object?> Resources,
    IReadOnlyList<string> Permissions);

public sealed record PagedResult(int Total, IReadOnlyList<Dictionary<string, object?>> Items);

public sealed record SaveResult(int Id, bool Created);

public sealed record SyncOperation(string OpId, string Method, string Resource, int? Id,
    Dictionary<string, object?>? Body);

public sealed record SyncRequest(IReadOnlyList<SyncOperation> Ops);

public sealed record SyncResult(string OpId, bool Ok, int? Id, string? Error);

public sealed record RoleListItem(int Id, string Nombre, string? Descripcion, int? EmpresaId, string? Empresa,
    bool Activo, bool TienePassword, string? Icono, string? Color, IReadOnlyList<string> Permisos);

public sealed record RoleSaveRequest(string Nombre, string? Descripcion, int? EmpresaId, string? Password,
    string? Icono, string? Color, bool Activo, IReadOnlyList<string>? Permisos);

public sealed record PermissionGroup(string Modulo, string Label, IReadOnlyList<string> Acciones);

public sealed record CompanySummary(int Id, string Ruc, string RazonSocial, bool Activo, int Unidades, int Vehiculos,
    int Conductores);

public sealed record CompanySaveRequest(string? Ruc, string? RazonSocial, string? Direccion, string? Telefono,
    string? Correo, string? Contacto, string? Notas, bool Activo);

public sealed record NotificationDto(string Tipo, string Detalle, DateTime Fecha);
