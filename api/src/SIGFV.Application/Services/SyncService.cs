using System.Text.Json;
using SIGFV.Application.Abstractions;
using SIGFV.Application.Models;
using SIGFV.Domain;

namespace SIGFV.Application.Services;

/// <summary>
/// Aplica operaciones creadas sin conexión. Cada operación lleva un identificador
/// único generado en el dispositivo; si ya fue aplicada se devuelve el mismo
/// resultado, de modo que reintentar nunca duplica registros.
/// </summary>
public sealed class SyncService
{
    private readonly IDb _db;
    private readonly CrudService _crud;

    public SyncService(IDb db, CrudService crud)
    {
        _db = db;
        _crud = crud;
    }

    public async Task<List<SyncResult>> ApplyAsync(SyncRequest request, CurrentSession session, string? ip,
        CancellationToken ct = default)
    {
        var results = new List<SyncResult>();
        var ops = request.Ops?.Take(200).ToList() ?? new List<SyncOperation>();

        foreach (var op in ops)
        {
            if (string.IsNullOrWhiteSpace(op.OpId) || op.OpId.Length > 100)
            {
                results.Add(new SyncResult(op.OpId ?? "", false, null, "Identificador de operación inválido."));
                continue;
            }

            var existing = await _db.QueryAsync("""
                SELECT ok, record_id, error FROM sync_ops WHERE op_id = @op
                """, new Dictionary<string, object?> { ["op"] = op.OpId }, ct);

            if (existing.Count > 0)
            {
                results.Add(new SyncResult(op.OpId,
                    Convert.ToBoolean(existing[0]["ok"]),
                    existing[0]["record_id"] is null ? null : Convert.ToInt32(existing[0]["record_id"]),
                    existing[0]["error"] as string));
                continue;
            }

            var method = (op.Method ?? "").Trim().ToUpperInvariant();
            int? recordId = null;
            var ok = false;
            string? error = null;

            try
            {
                var r = CrudService.Resolve(op.Resource);
                switch (method)
                {
                    case "POST":
                        if (!session.Has(r.Mod, "crear")) throw new AppException("Sin permiso para crear en este módulo.", 403);
                        var created = await _crud.CreateAsync(op.Resource, session,
                            op.Body ?? new Dictionary<string, object?>(), ip, ct);
                        recordId = created.Id;
                        break;

                    case "PUT":
                        if (!session.Has(r.Mod, "editar")) throw new AppException("Sin permiso para editar en este módulo.", 403);
                        if (op.Id is null or <= 0) throw new AppException("Falta el registro a actualizar.");
                        await _crud.UpdateAsync(op.Resource, session, op.Id.Value,
                            op.Body ?? new Dictionary<string, object?>(), ip, ct);
                        recordId = op.Id;
                        break;

                    case "DELETE":
                        if (!session.Has(r.Mod, "eliminar")) throw new AppException("Sin permiso para eliminar en este módulo.", 403);
                        if (op.Id is null or <= 0) throw new AppException("Falta el registro a eliminar.");
                        await _crud.DeleteAsync(op.Resource, session, op.Id.Value, ip, ct);
                        recordId = op.Id;
                        break;

                    default:
                        throw new AppException("Método no soportado en la sincronización.");
                }

                ok = true;
            }
            catch (AppException ex)
            {
                error = ex.Message;
            }
            catch (Exception ex)
            {
                results.Add(new SyncResult(op.OpId, false, null,
                    "No se pudo aplicar la operación en este momento: " + ex.Message));
                continue;
            }

            await _db.ExecuteAsync("""
                INSERT INTO sync_ops
                    (op_id, role_id, empresa_id, usuario_id, method, resource, record_id, body, ok, error)
                VALUES (@op, @rid, @eid, @uid, @method, @res, @rec, @body::jsonb, @ok, @error)
                ON CONFLICT (op_id) DO NOTHING
                """, new Dictionary<string, object?>
            {
                ["op"] = op.OpId,
                ["rid"] = session.RoleId,
                ["eid"] = session.EmpresaId > 0 ? session.EmpresaId : null,
                ["uid"] = session.UserId,
                ["method"] = method,
                ["res"] = op.Resource,
                ["rec"] = recordId,
                ["body"] = JsonSerializer.Serialize(op.Body ?? new Dictionary<string, object?>()),
                ["ok"] = ok,
                ["error"] = error
            }, ct);

            results.Add(new SyncResult(op.OpId, ok, recordId, error));
        }

        return results;
    }

    public async Task<Dictionary<string, object?>> PendingAsync(CurrentSession session,
        CancellationToken ct = default)
    {
        var rows = await _db.QueryAsync("""
            SELECT op_id FROM sync_ops
            WHERE role_id = @rid AND (@eid = 0 OR empresa_id = @eid) AND aplicado_en >= now() - INTERVAL '30 days'
            """, new Dictionary<string, object?>
        {
            ["rid"] = session.RoleId,
            ["eid"] = session.EmpresaId > 0 ? session.EmpresaId : 0
        }, ct);

        return new Dictionary<string, object?> { ["aplicadas"] = rows.Count };
    }
}
