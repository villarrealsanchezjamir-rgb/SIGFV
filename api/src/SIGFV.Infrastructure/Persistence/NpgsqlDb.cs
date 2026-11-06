using System.Globalization;
using Npgsql;
using SIGFV.Application.Abstractions;

namespace SIGFV.Infrastructure.Persistence;

public sealed class NpgsqlDb : IDb
{
    private readonly NpgsqlDataSource _dataSource;

    public NpgsqlDb(string connectionString)
    {
        var normalized = Normalize(connectionString);
        var builder = new NpgsqlDataSourceBuilder(normalized);
        // El pooler de Supabase no permite cargar el catálogo de tipos con fiabilidad.
        // Con tipos no mapeados, los enums se leen como texto y las consultas funcionan.
        builder.EnableUnmappedTypes();
        _dataSource = builder.Build();
    }

    public static string Normalize(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException("Falta SUPABASE_DB_URL / ConnectionStrings:Supabase.");

        if (!value.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) &&
            !value.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
            return value;

        var uri = new Uri(value);
        var userInfo = uri.UserInfo.Split(':', 2);
        // Supabase expone el pooler en modo transacción en el puerto 6543; Npgsql
        // funciona de forma estable contra el pooler en modo sesión (5432).
        var poolerPort = uri.Port == 6543 ? 5432 : uri.Port;
        var builder = new NpgsqlConnectionStringBuilder
        {
            Host = uri.Host,
            Port = poolerPort > 0 ? poolerPort : 5432,
            Username = Uri.UnescapeDataString(userInfo[0]),
            Password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : string.Empty,
            Database = uri.AbsolutePath.Trim('/'),
            SslMode = SslMode.Require,
            Pooling = true,
            MaxPoolSize = 10,
            Timeout = 20,
            CommandTimeout = 60
        };
        return builder.ConnectionString;
    }

    public async Task<List<Dictionary<string, object?>>> QueryAsync(string sql,
        IReadOnlyDictionary<string, object?>? parameters = null, CancellationToken ct = default)
    {
        await using var conn = _dataSource.CreateConnection();
        await conn.OpenAsync(ct);
        await using var cmd = Build(conn, sql, parameters);
        await using var reader = await cmd.ExecuteReaderAsync(ct);
        return await ReadAllAsync(reader, ct);
    }

    public async Task<int> ExecuteAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken ct = default)
    {
        await using var conn = _dataSource.CreateConnection();
        await conn.OpenAsync(ct);
        await using var cmd = Build(conn, sql, parameters);
        return await cmd.ExecuteNonQueryAsync(ct);
    }

    public async Task<T> TransactionAsync<T>(Func<IDbTransaction, Task<T>> action, CancellationToken ct = default)
    {
        await using var conn = _dataSource.CreateConnection();
        await conn.OpenAsync(ct);
        await using var tx = await conn.BeginTransactionAsync(System.Data.IsolationLevel.ReadCommitted, ct);
        var wrapper = new Tx(conn, tx);
        try
        {
            var result = await action(wrapper);
            await tx.CommitAsync(ct);
            return result;
        }
        catch
        {
            try { await tx.RollbackAsync(ct); } catch { /* ignored */ }
            throw;
        }
    }

    internal static NpgsqlCommand Build(NpgsqlConnection conn, string sql,
        IReadOnlyDictionary<string, object?>? parameters)
    {
        var cmd = new NpgsqlCommand(sql, conn);
        if (parameters is null) return cmd;
        foreach (var (key, value) in parameters)
        {
            var p = new NpgsqlParameter(key, value ?? DBNull.Value);
            cmd.Parameters.Add(p);
        }
        return cmd;
    }

    internal static async Task<List<Dictionary<string, object?>>> ReadAllAsync(NpgsqlDataReader reader,
        CancellationToken ct)
    {
        var rows = new List<Dictionary<string, object?>>();
        while (await reader.ReadAsync(ct))
        {
            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            for (var i = 0; i < reader.FieldCount; i++)
            {
                var value = await reader.IsDBNullAsync(i, ct) ? null : reader.GetValue(i);
                row[reader.GetName(i)] = value switch
                {
                    DateOnly d => d.ToDateTime(TimeOnly.MinValue),
                    TimeOnly t => t.ToTimeSpan(),
                    DateTime dt => dt,
                    _ => value
                };
            }
            rows.Add(row);
        }
        return rows;
    }

    private sealed class Tx : IDbTransaction
    {
        private readonly NpgsqlConnection _conn;
        private readonly NpgsqlTransaction _tx;
        private bool _done;

        public Tx(NpgsqlConnection conn, NpgsqlTransaction tx)
        {
            _conn = conn;
            _tx = tx;
        }

        public async Task<List<Dictionary<string, object?>>> QueryAsync(string sql,
            IReadOnlyDictionary<string, object?>? parameters = null, CancellationToken ct = default)
        {
            await using var cmd = Build(_conn, sql, parameters);
            cmd.Transaction = _tx;
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            return await ReadAllAsync(reader, ct);
        }

        public async Task<int> ExecuteAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null,
            CancellationToken ct = default)
        {
            await using var cmd = Build(_conn, sql, parameters);
            cmd.Transaction = _tx;
            return await cmd.ExecuteNonQueryAsync(ct);
        }

        public async Task CommitAsync(CancellationToken ct = default)
        {
            if (_done) return;
            await _tx.CommitAsync(ct);
            _done = true;
        }

        public async Task RollbackAsync(CancellationToken ct = default)
        {
            if (_done) return;
            try { await _tx.RollbackAsync(ct); } catch { /* ignored */ }
            _done = true;
        }

        public async ValueTask DisposeAsync()
        {
            if (!_done)
            {
                try { await _tx.RollbackAsync(); } catch { /* ignored */ }
            }
            await _tx.DisposeAsync();
        }
    }
}

public static class SqlValues
{
    public static string? Text(object? value)
        => value is null or DBNull ? null : Convert.ToString(value, CultureInfo.InvariantCulture);

    public static int? Int(object? value)
        => value is null or DBNull ? null : Convert.ToInt32(value, CultureInfo.InvariantCulture);

    public static long? Long(object? value)
        => value is null or DBNull ? null : Convert.ToInt64(value, CultureInfo.InvariantCulture);

    public static decimal? Decimal(object? value)
        => value is null or DBNull ? null : Convert.ToDecimal(value, CultureInfo.InvariantCulture);

    public static bool? Bool(object? value)
    {
        if (value is null or DBNull) return null;
        if (value is bool b) return b;
        var s = Convert.ToString(value, CultureInfo.InvariantCulture)?.Trim().ToLowerInvariant();
        return s is "1" or "true" or "si" or "sí" or "t" or "y" or "yes";
    }

    public static DateTime? Date(object? value)
    {
        if (value is null or DBNull) return null;
        if (value is DateTime dt) return dt;
        if (value is DateOnly d) return d.ToDateTime(TimeOnly.MinValue);
        var s = Convert.ToString(value, CultureInfo.InvariantCulture);
        return DateTime.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.None, out var parsed) ? parsed : null;
    }
}
