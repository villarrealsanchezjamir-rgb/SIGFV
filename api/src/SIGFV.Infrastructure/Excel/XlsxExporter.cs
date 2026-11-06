using System.Globalization;
using System.IO.Compression;
using System.Text;
using SIGFV.Application.Abstractions;

namespace SIGFV.Infrastructure.Excel;

/// <summary>
/// Generador XLSX sin dependencias externas. Cada hoja lleva título, encabezados
/// con estilo, filas alternas, bordes, anchos automáticos, filtro y panel congelado.
/// </summary>
public sealed class XlsxExporter : IExcelExporter
{
    public byte[] Build(IReadOnlyList<ExportSheet> sheets, string title)
    {
        if (sheets.Count == 0) throw new AppException("No hay datos para exportar.", 400);

        using var ms = new MemoryStream();
        using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, true))
        {
            Write(zip, "[Content_Types].xml", ContentTypes(sheets.Count));
            Write(zip, "_rels/.rels", RootRels());
            Write(zip, "xl/workbook.xml", Workbook(sheets));
            Write(zip, "xl/_rels/workbook.xml.rels", WorkbookRels(sheets.Count));
            Write(zip, "xl/styles.xml", Styles());
            for (var i = 0; i < sheets.Count; i++)
                Write(zip, $"xl/worksheets/sheet{i + 1}.xml", Sheet(sheets[i], title));
        }
        return ms.ToArray();
    }

    private static void Write(ZipArchive zip, string path, string content)
    {
        var entry = zip.CreateEntry(path, CompressionLevel.Optimal);
        using var stream = entry.Open();
        using var writer = new StreamWriter(stream, new UTF8Encoding(false));
        writer.Write(content);
    }

    private static string ContentTypes(int count)
    {
        var sb = new StringBuilder();
        sb.Append("""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>""");
        sb.Append("""<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">""");
        sb.Append("""<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>""");
        sb.Append("""<Default Extension="xml" ContentType="application/xml"/>""");
        sb.Append("""<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>""");
        sb.Append("""<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>""");
        for (var i = 1; i <= count; i++)
            sb.Append($"""<Override PartName="/xl/worksheets/sheet{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>""");
        sb.Append("</Types>");
        return sb.ToString();
    }

    private static string RootRels()
        => """<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>""";

    private static string Workbook(IReadOnlyList<ExportSheet> sheets)
    {
        var sb = new StringBuilder();
        sb.Append("""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>""");
        sb.Append("""<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>""");
        for (var i = 0; i < sheets.Count; i++)
            sb.Append($"""<sheet name="{Esc(UniqueName(sheets, i))}" sheetId="{i + 1}" r:id="rId{i + 1}"/>""");
        sb.Append("</sheets></workbook>");
        return sb.ToString();
    }

    private static string UniqueName(IReadOnlyList<ExportSheet> sheets, int index)
    {
        var name = CleanName(sheets[index].Name);
        var used = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < index; i++) used.Add(CleanName(sheets[i].Name));
        if (!used.Contains(name)) return name;
        for (var n = 2; ; n++)
        {
            var suffix = $" ({n})";
            var candidate = CleanName(name[..Math.Min(name.Length, 31 - suffix.Length)] + suffix);
            if (!used.Contains(candidate)) return candidate;
        }
    }

    private static string CleanName(string name)
    {
        var cleaned = new string(name.Where(c => c is not ('[' or ']' or ':' or '*' or '?' or '/' or '\\')).ToArray()).Trim();
        if (cleaned.Length == 0) cleaned = "Datos";
        return cleaned.Length > 31 ? cleaned[..31] : cleaned;
    }

    private static string WorkbookRels(int count)
    {
        var sb = new StringBuilder();
        sb.Append("""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>""");
        sb.Append("""<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">""");
        for (var i = 1; i <= count; i++)
            sb.Append($"""<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i}.xml"/>""");
        sb.Append($"""<Relationship Id="rId{count + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>""");
        sb.Append("</Relationships>");
        return sb.ToString();
    }

    private static string Styles()
        => """
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="3">
<numFmt numFmtId="164" formatCode="#,##0.00"/>
<numFmt numFmtId="165" formatCode="dd/mm/yyyy hh:mm"/>
<numFmt numFmtId="166" formatCode="dd/mm/yyyy"/>
</numFmts>
<fonts count="3">
<font><sz val="11"/><name val="Calibri"/><color rgb="FF171717"/></font>
<font><b/><sz val="11"/><name val="Calibri"/><color rgb="FFFFFFFF"/></font>
<font><b/><sz val="14"/><name val="Calibri"/><color rgb="FF171717"/></font>
</fonts>
<fills count="4">
<fill><patternFill patternType="none"/></fill>
<fill><patternFill patternType="gray125"/></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FF171717"/><bgColor indexed="64"/></patternFill></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFF2F2F2"/><bgColor indexed="64"/></patternFill></fill>
</fills>
<borders count="2">
<border><left/><right/><top/><bottom/><diagonal/></border>
<border><left style="thin"><color rgb="FFD9D9D9"/></left><right style="thin"><color rgb="FFD9D9D9"/></right><top style="thin"><color rgb="FFD9D9D9"/></top><bottom style="thin"><color rgb="FFD9D9D9"/></bottom><diagonal/></border>
</borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="9">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf>
<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf>
<xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="0" fontId="0" fillId="3" borderId="1" xfId="0" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf>
<xf numFmtId="164" fontId="0" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="right" vertical="center"/></xf>
<xf numFmtId="165" fontId="0" fillId="3" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
</cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>
""";

    private static string Sheet(ExportSheet sheet, string reportTitle)
    {
        var headers = sheet.Headers;
        var rows = sheet.Rows;
        var cols = Math.Max(1, headers.Count);
        var lastRow = rows.Count + 2;
        var lastCol = ColumnLetter(cols);

        var widths = new int[cols];
        for (var c = 0; c < cols; c++) widths[c] = Math.Min(48, Math.Max(10, (headers[c] ?? string.Empty).Length + 2));
        foreach (var row in rows)
        {
            for (var c = 0; c < cols; c++)
            {
                var len = (c < row.Count ? Convert.ToString(row[c], CultureInfo.InvariantCulture) : null)?.Length ?? 0;
                if (len > widths[c]) widths[c] = Math.Min(48, Math.Max(10, len + 2));
            }
        }

        var sb = new StringBuilder();
        sb.Append("""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>""");
        sb.Append("""<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">""");
        sb.Append($"""<dimension ref="A1:{lastCol}{lastRow}"/>""");
        sb.Append("""<sheetViews><sheetView workbookViewId="0" tabSelected="1"><pane ySplit="2" topLeftCell="A3" activePane="bottomLeft" state="frozen"/><selection pane="bottomLeft" activeCell="A3" sqref="A3"/></sheetView></sheetViews>""");
        sb.Append("<cols>");
        for (var c = 0; c < cols; c++)
            sb.Append($"""<col min="{c + 1}" max="{c + 1}" width="{widths[c]}" customWidth="1"/>""");
        sb.Append("</cols><sheetData>");

        sb.Append($"""<row r="1" ht="24" customHeight="1"><c r="A1" s="5" t="inlineStr"><is><t>{Esc(reportTitle)}</t></is></c></row>""");

        sb.Append("""<row r="2" ht="30" customHeight="1">""");
        for (var c = 0; c < cols; c++)
            sb.Append($"""<c r="{ColumnLetter(c + 1)}2" s="1" t="inlineStr"><is><t>{Esc(headers[c] ?? string.Empty)}</t></is></c>""");
        sb.Append("</row>");

        for (var r = 0; r < rows.Count; r++)
        {
            var rowNumber = r + 3;
            var banded = r % 2 == 1;
            sb.Append($"""<row r="{rowNumber}">""");
            var row = rows[r];
            for (var c = 0; c < cols; c++)
            {
                var value = c < row.Count ? row[c] : null;
                var reference = $"{ColumnLetter(c + 1)}{rowNumber}";
                sb.Append(Cell(reference, value, banded));
            }
            sb.Append("</row>");
        }

        sb.Append("</sheetData>");
        if (rows.Count > 0)
            sb.Append($"""<autoFilter ref="A2:{lastCol}{lastRow}"/>""");
        sb.Append($"""<mergeCells count="1"><mergeCell ref="A1:{lastCol}1"/></mergeCells>""");
        sb.Append("</worksheet>");
        return sb.ToString();
    }

    private static string Cell(string reference, object? value, bool banded)
    {
        if (value is null or DBNull)
            return $"""<c r="{reference}" s="{(banded ? 6 : 2)}"/>""";

        switch (value)
        {
            case bool b:
                return $"""<c r="{reference}" s="{(banded ? 6 : 2)}" t="b"><v>{(b ? 1 : 0)}</v></c>""";
            case byte or sbyte or short or ushort or int or uint or long or ulong or float or double or decimal:
            {
                var number = Convert.ToDecimal(value, CultureInfo.InvariantCulture);
                var style = banded ? 7 : 3;
                return $"""<c r="{reference}" s="{style}"><v>{number.ToString(CultureInfo.InvariantCulture)}</v></c>""";
            }
            case DateTime dt:
            {
                var style = banded ? 8 : 4;
                return $"""<c r="{reference}" s="{style}"><v>{dt.ToOADate().ToString(CultureInfo.InvariantCulture)}</v></c>""";
            }
            case DateOnly d:
            {
                var style = banded ? 8 : 4;
                return $"""<c r="{reference}" s="{style}"><v>{d.ToDateTime(TimeOnly.MinValue).ToOADate().ToString(CultureInfo.InvariantCulture)}</v></c>""";
            }
            default:
            {
                var text = Convert.ToString(value, CultureInfo.InvariantCulture) ?? string.Empty;
                if (text.Length > 32767) text = text[..32767];
                if (text.Length > 0 && text[0] is '=' or '+' or '-' or '@') text = "'" + text;
                var style = banded ? 6 : 2;
                return $"""<c r="{reference}" s="{style}" t="inlineStr"><is><t xml:space="preserve">{Esc(text)}</t></is></c>""";
            }
        }
    }

    private static string ColumnLetter(int column)
    {
        var dividend = column;
        var name = string.Empty;
        while (dividend > 0)
        {
            var modulo = (dividend - 1) % 26;
            name = (char)('A' + modulo) + name;
            dividend = (dividend - modulo) / 26;
        }
        return name;
    }

    private static string Esc(string value)
    {
        var sb = new StringBuilder(value.Length + 16);
        foreach (var c in value)
        {
            switch (c)
            {
                case '&': sb.Append("&amp;"); break;
                case '<': sb.Append("&lt;"); break;
                case '>': sb.Append("&gt;"); break;
                case '"': sb.Append("&quot;"); break;
                case '\'': sb.Append("&apos;"); break;
                default:
                    if (c < 0x20 && c is not '\t' and not '\n' and not '\r') break;
                    sb.Append(c);
                    break;
            }
        }
        return sb.ToString();
    }
}
