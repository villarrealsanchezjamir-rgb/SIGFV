using SIGFV.Application.Resources;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

public sealed class MetaService
{
    public Dictionary<string, object?> Build(CurrentSession session)
    {
        var resources = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

        foreach (var r in ResourceCatalog.All.Values.OrderBy(x => x.Group).ThenBy(x => x.Label))
        {
            if (!session.Has(r.Mod, "consultar")) continue;
            resources[r.Key] = new Dictionary<string, object?>
            {
                ["label"] = r.Label,
                ["group"] = r.Group,
                ["mod"] = r.Mod,
                ["icon"] = r.Icon,
                ["cols"] = r.Cols.Select(c => new object?[] { c.Key, c.Label, c.Kind }).ToList(),
                ["fields"] = r.Fields.Select(f => new Dictionary<string, object?>
                {
                    ["n"] = f.Name,
                    ["l"] = f.Label,
                    ["t"] = f.Type,
                    ["req"] = f.Required,
                    ["cat"] = f.Catalog,
                    ["o"] = f.Options?.Select(o => new object?[] { o.Value, o.Label }).ToList(),
                    ["virtual"] = f.Virtual
                }).ToList(),
                ["crear"] = session.Has(r.Mod, "crear"),
                ["editar"] = session.Has(r.Mod, "editar"),
                ["eliminar"] = session.Has(r.Mod, "eliminar") && r.Soft is not null,
                ["exportar"] = session.Has(r.Mod, "exportar")
            };
        }

        if (session.Has("usuarios", "consultar"))
        {
            resources["roles"] = new Dictionary<string, object?>
            {
                ["label"] = "Roles y accesos",
                ["group"] = "Administración",
                ["mod"] = "usuarios",
                ["icon"] = "key",
                ["custom"] = "roles",
                ["cols"] = new List<object?>(),
                ["fields"] = new List<object?>(),
                ["crear"] = session.Has("usuarios", "crear") || session.Has("usuarios", "editar"),
                ["editar"] = session.Has("usuarios", "editar"),
                ["eliminar"] = session.Has("usuarios", "eliminar"),
                ["exportar"] = false
            };
        }

        return new Dictionary<string, object?>
        {
            ["user"] = string.IsNullOrWhiteSpace(session.Operador) ? session.RoleName : session.Operador,
            ["roles"] = new[] { session.RoleName },
            ["empresa"] = session.EmpresaName,
            ["empresaId"] = session.EmpresaId,
            ["rolId"] = session.RoleId,
            ["dashboard"] = session.Has("dashboard", "consultar"),
            ["notificaciones"] = session.Has("notificaciones", "consultar"),
            ["resources"] = resources,
            ["permissions"] = session.Permissions.OrderBy(p => p).ToList()
        };
    }
}
