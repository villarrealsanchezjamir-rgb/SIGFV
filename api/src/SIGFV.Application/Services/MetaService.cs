using SIGFV.Application.Resources;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

public sealed class MetaService
{
    public Dictionary<string, object?> Build(CurrentSession session)
    {
        var resources = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

        foreach (var r in ResourceCatalog.All.Values.OrderBy(x => ModuleDirectory.OrderOf(x.Key)).ThenBy(x => x.Label))
        {
            if (!session.Has(r.Mod, "consultar")) continue;
            resources[r.Key] = new Dictionary<string, object?>
            {
                ["label"] = r.Label,
                ["group"] = r.Group,
                ["mod"] = r.Mod,
                ["icon"] = r.Icon,
                ["order"] = ModuleDirectory.OrderOf(r.Key),
                ["responsable"] = ModuleDirectory.ResponsibleFor(r.Key),
                ["area"] = ModuleDirectory.AreaFor(r.Key),
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
                ["order"] = ModuleDirectory.OrderOf("roles"),
                ["responsable"] = ModuleDirectory.ResponsibleFor("roles"),
                ["area"] = ModuleDirectory.AreaFor("roles"),
                ["cols"] = new List<object?>(),
                ["fields"] = new List<object?>(),
                ["crear"] = session.Has("usuarios", "crear") || session.Has("usuarios", "editar"),
                ["editar"] = session.Has("usuarios", "editar"),
                ["eliminar"] = session.Has("usuarios", "eliminar"),
                ["exportar"] = false
            };
        }

        if (session.Has("configuracion", "consultar"))
        {
            resources["solicitudes"] = new Dictionary<string, object?>
            {
                ["label"] = "Solicitudes de empresas",
                ["group"] = "Administración",
                ["mod"] = "configuracion",
                ["icon"] = "building",
                ["custom"] = "solicitudes",
                ["order"] = ModuleDirectory.OrderOf("solicitudes"),
                ["responsable"] = ModuleDirectory.ResponsibleFor("solicitudes"),
                ["area"] = ModuleDirectory.AreaFor("solicitudes"),
                ["cols"] = new List<object?>(),
                ["fields"] = new List<object?>(),
                ["crear"] = false,
                ["editar"] = session.Has("configuracion", "editar"),
                ["eliminar"] = false,
                ["exportar"] = false
            };
        }

        var owners = ModuleDirectory.Areas.Select(area => new Dictionary<string, object?>
        {
            ["id"] = area.Id,
            ["title"] = area.Title,
            ["desc"] = area.Description,
            ["responsable"] = area.Responsible,
            ["modules"] = resources
                .Where(kv => ModuleDirectory.AreaFor(kv.Key) == area.Id)
                .OrderBy(kv => ResourceOrder(kv.Value))
                .Select(kv => new Dictionary<string, object?>
                {
                    ["key"] = kv.Key,
                    ["label"] = kv.Value is Dictionary<string, object?> d && d.TryGetValue("label", out var label) ? label : null,
                    ["responsable"] = area.Responsible,
                    ["acciones"] = Actions(kv.Value)
                }).ToList()
        }).ToList();

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
            ["owners"] = owners,
            ["permissions"] = session.Permissions.OrderBy(p => p).ToList()
        };
    }

    private static int ResourceOrder(object? value)
        => value is Dictionary<string, object?> d && d.TryGetValue("order", out var order) && order is int n ? n : 999;

    private static List<string> Actions(object? value)
    {
        var actions = new List<string>();
        if (value is not Dictionary<string, object?> d) return actions;
        actions.Add("consultar");
        foreach (var (key, label) in new[] { ("crear", "crear"), ("editar", "editar"), ("eliminar", "eliminar"), ("exportar", "exportar") })
            if (d.TryGetValue(key, out var flag) && flag is true) actions.Add(label);
        return actions;
    }
}
