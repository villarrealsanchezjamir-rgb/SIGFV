using SIGFV.Domain;

namespace SIGFV.Application.Abstractions;

public sealed class AppException : Exception
{
    public int Status { get; }
    public AppException(string message, int status = 400) : base(message) => Status = status;
}

public interface IDb
{
    Task<List<Dictionary<string, object?>>> QueryAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken ct = default);

    Task<int> ExecuteAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken ct = default);

    Task<T> TransactionAsync<T>(Func<IDbTransaction, Task<T>> action, CancellationToken ct = default);
}

public interface IDbTransaction : IAsyncDisposable
{
    Task<List<Dictionary<string, object?>>> QueryAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken ct = default);

    Task<int> ExecuteAsync(string sql, IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken ct = default);

    Task CommitAsync(CancellationToken ct = default);
    Task RollbackAsync(CancellationToken ct = default);
}

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string hash);
    bool NeedsRehash(string hash);
}

public interface ITokenService
{
    string Create(CurrentSession session, string operador);
}

public interface IExcelExporter
{
    byte[] Build(IReadOnlyList<ExportSheet> sheets, string title);
}

public sealed record ExportSheet(string Name, IReadOnlyList<string> Headers, IReadOnlyList<IReadOnlyList<object?>> Rows);

public sealed record ImportResult(int Created, int Updated, int Skipped, IReadOnlyList<string> Errors);
