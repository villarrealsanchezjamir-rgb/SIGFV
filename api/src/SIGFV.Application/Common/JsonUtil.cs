using System.Globalization;
using System.Text.Json;

namespace SIGFV.Application.Common;

public static class JsonUtil
{
    public static Dictionary<string, object?> ToDictionary(JsonElement element)
    {
        var result = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        if (element.ValueKind != JsonValueKind.Object) return result;
        foreach (var property in element.EnumerateObject())
            result[property.Name] = ToValue(property.Value);
        return result;
    }

    public static object? ToValue(JsonElement element) => element.ValueKind switch
    {
        JsonValueKind.Null or JsonValueKind.Undefined => null,
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Number => element.TryGetInt64(out var l) ? l : element.GetDecimal(),
        JsonValueKind.String => element.GetString(),
        JsonValueKind.Array => element.EnumerateArray().Select(ToValue).ToList(),
        JsonValueKind.Object => ToDictionary(element),
        _ => element.ToString()
    };

    public static string? Str(this IReadOnlyDictionary<string, object?> data, string key)
        => data.TryGetValue(key, out var v) ? Convert.ToString(v, CultureInfo.InvariantCulture) : null;

    public static int? Int(this IReadOnlyDictionary<string, object?> data, string key)
    {
        if (!data.TryGetValue(key, out var v) || v is null) return null;
        return v switch
        {
            int i => i,
            long l => (int)l,
            decimal d => (int)d,
            double db => (int)db,
            _ => int.TryParse(Convert.ToString(v, CultureInfo.InvariantCulture), out var parsed) ? parsed : null
        };
    }

    public static bool? Bool(this IReadOnlyDictionary<string, object?> data, string key)
    {
        if (!data.TryGetValue(key, out var v) || v is null) return null;
        if (v is bool b) return b;
        var s = Convert.ToString(v, CultureInfo.InvariantCulture)?.Trim().ToLowerInvariant();
        return s is "1" or "true" or "si" or "sí" or "yes" or "y" or "t";
    }
}
