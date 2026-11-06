using System.Globalization;
using System.Text;
using SIGFV.Application.Abstractions;
using SIGFV.Application.Resources;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

public sealed record ExportFile(string FileName, byte[] Content);

public sealed class ExportService
{
    private readonly CrudService _crud;
    private readonly IExcelExporter _excel;

    public ExportService(CrudService crud, IExcelExporter excel)
    {
        _crud = crud;
        _excel = excel;
    }

    public async Task<ExportFile> BuildModuleAsync(string key, CurrentSession session, string? q,
        CancellationToken ct = default)
    {
        var r = CrudService.Resolve(key);
        if (!session.Has(r.Mod, "consultar")) throw new AppException("No tiene permiso para consultar este módulo.", 403);
        if (!session.Has(r.Mod, "exportar")) throw new AppException("No tiene permiso para exportar este módulo.", 403);

        var items = await _crud.AllAsync(key, session, q, 50000, ct);
        var sheet = ToSheet(r, items);
        var content = _excel.Build(new[] { sheet }, Title(r.Label, session));
        return new ExportFile(FileName(r.Label, session, "modulo_" + r.Key), content);
    }

    public async Task<ExportFile> BuildAllAsync(CurrentSession session, CancellationToken ct = default)
    {
        var sheets = new List<ExportSheet>();
        var summaryRows = new List<IReadOnlyList<object?>>();
        var included = 0;

        foreach (var r in ResourceCatalog.All.Values
                     .Where(x => session.Has(x.Mod, "consultar") && session.Has(x.Mod, "exportar"))
                     .OrderBy(x => x.Group).ThenBy(x => x.Label))
        {
            List<Dictionary<string, object?>> rows;
            try
            {
                rows = await _crud.AllAsync(r.Key, session, null, 20000, ct);
            }
            catch (AppException)
            {
                continue;
            }

            sheets.Add(ToSheet(r, rows));
            summaryRows.Add(new object?[]
            {
                r.Label, rows.Count, YesNo(session.Has(r.Mod, "crear")), YesNo(session.Has(r.Mod, "editar")),
                YesNo(true)
            });
            included++;
        }

        if (included == 0)
            throw new AppException("No tiene módulos autorizados para exportar.", 403);

        sheets.Insert(0, new ExportSheet("Resumen",
            new[] { "Módulo", "Registros exportados", "Puede crear", "Puede editar", "Incluido" },
            summaryRows));

        var content = _excel.Build(sheets, Title("Todos los módulos", session));
        return new ExportFile(FileName("Todos los modulos", session, "todos"), content);
    }

    private static ExportSheet ToSheet(ResourceDef r, IReadOnlyList<Dictionary<string, object?>> items)
    {
        var headers = r.Cols.Select(c => c.Label).ToList();
        var rows = new List<IReadOnlyList<object?>>(items.Count);
        foreach (var item in items)
        {
            var row = new object?[r.Cols.Count];
            for (var i = 0; i < r.Cols.Count; i++)
                row[i] = item.TryGetValue(r.Cols[i].Key, out var v) ? v : null;
            rows.Add(row);
        }
        return new ExportSheet(r.Label, headers, rows);
    }

    private static string Title(string label, CurrentSession session)
    {
        var company = string.IsNullOrWhiteSpace(session.EmpresaName) ? "Todas las empresas" : session.EmpresaName;
        return $"SIGFV · {label} · {company} · {DateTime.Now:dd/MM/yyyy HH:mm}";
    }

    private static string FileName(string label, CurrentSession session, string kind)
    {
        var slug = new string(label.Normalize(NormalizationForm.FormD)
            .Where(c => char.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
            .Select(c => char.IsLetterOrDigit(c) ? char.ToLowerInvariant(c) : '_')
            .ToArray()).Trim('_');
        if (slug.Length == 0) slug = kind;
        var company = string.IsNullOrWhiteSpace(session.EmpresaName) ? "global"
            : new string(session.EmpresaName.Normalize(NormalizationForm.FormD)
                .Where(c => char.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                .Select(c => char.IsLetterOrDigit(c) ? char.ToLowerInvariant(c) : '_').ToArray()).Trim('_');
        return $"SIGFV_{slug}_{company}_{DateTime.Now:yyyyMMdd_HHmm}.xlsx";
    }

    private static string YesNo(bool value) => value ? "Sí" : "No";
}
