import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../config.dart';
import '../models.dart';

enum AppStatus { boot, bootError, login, ready }

class AppState extends ChangeNotifier {
  AppState();

  final ApiClient api = ApiClient(baseUrl: AppConfig.apiBase);
  late SharedPreferences _prefs;

  AppStatus status = AppStatus.boot;
  String bootMessage = 'Iniciando la aplicación…';
  bool online = false;

  String token = '';
  AuthMeta? meta;
  List<Company> companies = [];
  Map<String, dynamic>? dashboard;
  List<Map<String, dynamic>> alerts = [];
  List<OutboxOp> _outbox = [];
  bool syncing = false;

  int get pending => _outbox.where((o) => o.scope == scope).length;

  String get scope => '${meta?.rolId ?? 0}:${meta?.empresaId ?? 0}';

  ResourceDef? resource(String key) => meta?.resources[key];

  /* ------------------------------------------------------------------ */
  /* Arranque                                                           */
  /* ------------------------------------------------------------------ */

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    token = _prefs.getString('sigfv_token') ?? '';
    api.token = token;
    await _loadOutbox();

    final cachedMeta = _cacheGet('meta');
    if (token.isNotEmpty && cachedMeta != null) {
      meta = AuthMeta.fromJson(asMap(cachedMeta));
      online = true;
      status = AppStatus.ready;
      notifyListeners();
      unawaited(refreshSession());
      return;
    }

    _setBoot('Conectando con SIGFV…');
    final ok = await _wake();
    online = ok;
    if (!ok) {
      bootMessage = 'Sin conexión. Conéctese una vez para habilitar el modo offline.';
      status = AppStatus.bootError;
      notifyListeners();
      return;
    }

    if (token.isEmpty) {
      await _safeLoadContext();
      status = AppStatus.login;
      notifyListeners();
      return;
    }

    try {
      meta = AuthMeta.fromJson(asMap(await api.get('/api/meta')));
      await _cachePut('meta', meta);
      status = AppStatus.ready;
      notifyListeners();
      _backgroundWork();
    } catch (e) {
      if (cachedMeta != null) {
        meta = AuthMeta.fromJson(asMap(cachedMeta));
        status = AppStatus.ready;
        notifyListeners();
        _backgroundWork();
      } else {
        await _safeLoadContext();
        status = AppStatus.login;
        bootMessage = '';
        notifyListeners();
      }
    }
  }

  void _setBoot(String message) {
    bootMessage = message;
    notifyListeners();
  }

  Future<bool> _wake() async {
    for (var i = 1; i <= 6; i++) {
      _setBoot(i == 1 ? 'Conectando con SIGFV…' : 'Despertando el servidor… ($i/6)');
      if (await api.health()) return true;
      if (i < 6) await Future.delayed(const Duration(milliseconds: 2200));
    }
    return false;
  }

  Future<void> retryBoot() async {
    status = AppStatus.boot;
    notifyListeners();
    await init();
  }

  /* ------------------------------------------------------------------ */
  /* Sesión                                                             */
  /* ------------------------------------------------------------------ */

  Future<void> _safeLoadContext() async {
    try {
      await loadContext(force: true);
    } catch (_) {}
  }

  Future<void> loadContext({bool force = false}) async {
    if (companies.isNotEmpty && !force) return;
    try {
      final data = await api.get('/api/auth/context',
          timeout: const Duration(seconds: 35));
      final list = asMap(data)['empresas'];
      companies = (list is List)
          ? list.map((e) => Company.fromJson(asMap(e))).toList()
          : <Company>[];
      await _cachePutGlobal('authContext', (list is List) ? list : []);
      notifyListeners();
    } catch (e) {
      final cached = _cacheGetGlobal('authContext');
      if (cached is List && cached.isNotEmpty) {
        companies = cached.map((e) => Company.fromJson(asMap(e))).toList();
        notifyListeners();
        return;
      }
      rethrow;
    }
  }

  Future<LoginResult> login({
    required int empresaId,
    required int rolId,
    required String password,
    String? operador,
  }) async {
    final data = await api.post(
      '/api/auth/login',
      {
        'empresaId': empresaId,
        'rolId': rolId,
        'password': password,
        'operador': operador,
      },
      timeout: const Duration(seconds: 45),
    );
    final result = LoginResult.fromJson(asMap(data));
    token = result.token;
    api.token = token;
    await _prefs.setString('sigfv_token', token);

    meta = AuthMeta.fromJson(asMap(await api.get('/api/meta')));
    await _cachePut('meta', meta);
    online = true;
    status = AppStatus.ready;
    notifyListeners();
    _backgroundWork();
    return result;
  }

  Future<void> refreshSession() async {
    if (token.isEmpty) return;
    try {
      meta = AuthMeta.fromJson(asMap(await api.get('/api/meta')));
      await _cachePut('meta', meta);
      online = true;
      notifyListeners();
      _backgroundWork();
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await logout(silent: true);
      } else if (e.offline) {
        online = false;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshMeta() async {
    if (token.isEmpty) return;
    try {
      meta = AuthMeta.fromJson(asMap(await api.get('/api/meta')));
      await _cachePut('meta', meta);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout({bool silent = false}) async {
    token = '';
    api.token = '';
    await _prefs.remove('sigfv_token');
    meta = null;
    dashboard = null;
    alerts = [];
    status = AppStatus.login;
    notifyListeners();
    await _safeLoadContext();
  }

  Future<void> changePassword(String actual, String nueva) async {
    await api.post('/api/auth/change-password', {
      'actual': actual,
      'nueva': nueva,
    });
  }

  void _backgroundWork() {
    unawaited(syncOutbox());
    unawaited(prefetchAll());
  }

  /* ------------------------------------------------------------------ */
  /* Panel y alertas                                                    */
  /* ------------------------------------------------------------------ */

  Future<Map<String, dynamic>> ensureDashboard({bool force = false}) async {
    if (!force && dashboard != null) return dashboard!;
    try {
      final data = asMap(await api.get('/api/dashboard'));
      dashboard = data;
      await _cachePut('dashboard', data);
      notifyListeners();
      return data;
    } catch (e) {
      final cached = _cacheGet('dashboard');
      if (cached != null) {
        dashboard = asMap(cached);
        notifyListeners();
        return dashboard!;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> ensureAlerts({bool force = false}) async {
    if (!force && alerts.isNotEmpty) return alerts;
    try {
      final data = await api.get('/api/notificaciones');
      alerts = asMapList(data);
      await _cachePut('alerts', alerts);
      notifyListeners();
      return alerts;
    } catch (e) {
      final cached = _cacheGet('alerts');
      if (cached is List) {
        alerts = asMapList(cached);
        notifyListeners();
        return alerts;
      }
      rethrow;
    }
  }

  /* ------------------------------------------------------------------ */
  /* Listados, catálogos y CRUD                                         */
  /* ------------------------------------------------------------------ */

  Future<Map<String, dynamic>> fetchList(
    String key, {
    String query = '',
    int page = 1,
    int limit = 20,
  }) async {
    final path =
        '/api/r/$key?pagina=$page&limit=$limit&q=${Uri.encodeQueryComponent(query)}';
    try {
      final data = asMap(await api.get(path));
      if (page == 1 && query.isEmpty) {
        await _cachePut('list_$key', data['items']);
      }
      return data;
    } catch (e) {
      final cached = _cacheGet('list_$key');
      if (cached is List && cached.isNotEmpty) {
        var rows = asMapList(cached);
        final q = query.toLowerCase().trim();
        if (q.isNotEmpty) {
          rows = rows
              .where((row) =>
                  row.values.any((v) => v.toString().toLowerCase().contains(q)))
              .toList();
        }
        final start = (page - 1) * limit;
        final end = (start + limit).clamp(0, rows.length);
        final slice = start >= rows.length ? <Map<String, dynamic>>[] : rows.sublist(start, end);
        return {'total': rows.length, 'items': slice, 'offline': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchRecord(String key, int id) async {
    try {
      final data = asMap(await api.get('/api/r/$key/$id'));
      await _cachePut('detail_${key}_$id', data);
      return data;
    } catch (e) {
      final cached = _cacheGet('detail_${key}_$id');
      if (cached != null) return asMap(cached);
      final list = _cacheGet('list_$key');
      if (list is List) {
        for (final row in list) {
          final map = asMap(row);
          if (asInt(map['id']) == id) return map;
        }
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> catalog(String name) async {
    try {
      final data = await api.get('/api/cat/$name');
      final list = asMapList(data);
      await _cachePut('cat_$name', list);
      return list;
    } catch (e) {
      final cached = _cacheGet('cat_$name');
      if (cached is List) return asMapList(cached);
      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> saveRecord(
    String key,
    int? id,
    Map<String, dynamic> body,
  ) async {
    try {
      if (id == null) {
        await api.post('/api/r/$key', body);
      } else if (id > 0) {
        await api.put('/api/r/$key/$id', body);
        await _cacheRemove('detail_${key}_$id');
      } else {
        throw ApiException('Registro pendiente de sincronizar.', offline: true);
      }
      online = true;
      unawaited(syncOutbox());
      return true;
    } on ApiException catch (e) {
      if (!e.offline) rethrow;
      await queueChange(id == null ? 'POST' : 'PUT', key, id, body);
      online = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> deleteRecord(String key, int id) async {
    try {
      if (id <= 0) throw ApiException('Registro pendiente.', offline: true);
      await api.delete('/api/r/$key/$id');
      online = true;
      unawaited(syncOutbox());
      return true;
    } on ApiException catch (e) {
      if (!e.offline) rethrow;
      await queueChange('DELETE', key, id, null);
      online = false;
      notifyListeners();
      return true;
    }
  }

  /* ------------------------------------------------------------------ */
  /* Cola offline                                                       */
  /* ------------------------------------------------------------------ */

  Future<void> _loadOutbox() async {
    final raw = _prefs.getString('sigfv_outbox');
    if (raw == null || raw.isEmpty) {
      _outbox = [];
      return;
    }
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        _outbox = list.map((e) => OutboxOp.fromJson(asMap(e))).toList();
      }
    } catch (_) {
      _outbox = [];
    }
  }

  Future<void> _saveOutbox() async {
    await _prefs.setString(
      'sigfv_outbox',
      jsonEncode(_outbox.map((e) => e.toJson()).toList()),
    );
  }

  String _newOpId() =>
      'op-${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().millisecond}';

  Future<void> queueChange(
    String method,
    String resourceKey,
    int? id,
    Map<String, dynamic>? body,
  ) async {
    if (method == 'POST') {
      final localId = -DateTime.now().millisecondsSinceEpoch;
      final op = OutboxOp(
        opId: _newOpId(),
        scope: scope,
        method: 'POST',
        resource: resourceKey,
        localId: localId,
        body: body,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      _outbox.add(op);
      await _saveOutbox();
      await _applyLocalRecord(resourceKey, 'POST', localId, body);
      notifyListeners();
      return;
    }

    if (id != null && id < 0) {
      final index = _outbox.indexWhere((o) =>
          o.scope == scope &&
          o.method == 'POST' &&
          o.resource == resourceKey &&
          o.localId == id);
      if (index >= 0) {
        final op = _outbox[index];
        if (method == 'DELETE') {
          _outbox.removeAt(index);
          await _applyLocalRecord(resourceKey, 'DELETE', id, null);
        } else {
          op.body = body;
          await _applyLocalRecord(resourceKey, 'PUT', id, body);
        }
        await _saveOutbox();
        notifyListeners();
        return;
      }
    }

    final op = OutboxOp(
      opId: _newOpId(),
      scope: scope,
      method: method,
      resource: resourceKey,
      id: id,
      body: body,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _outbox.add(op);
    await _saveOutbox();
    await _applyLocalRecord(resourceKey, method, id, body);
    notifyListeners();
  }

  Future<void> _applyLocalRecord(
    String key,
    String method,
    int? id,
    Map<String, dynamic>? body,
  ) async {
    final cached = _cacheGet('list_$key');
    final list = cached is List ? asMapList(cached) : <Map<String, dynamic>>[];
    if (method == 'POST' && id != null) {
      list.insert(0, {'id': id, ...?body, '__pending': 'create'});
    } else if (method == 'PUT' && id != null) {
      final i = list.indexWhere((x) => asInt(x['id']) == id);
      if (i >= 0) {
        list[i] = {...list[i], ...?body, '__pending': 'update'};
      }
    } else if (method == 'DELETE' && id != null) {
      list.removeWhere((x) => asInt(x['id']) == id);
    }
    await _cachePut('list_$key', list);
  }

  Future<void> _replaceLocalId(String resourceKey, int localId, int realId) async {
    final cached = _cacheGet('list_$resourceKey');
    if (cached is List) {
      final list = asMapList(cached);
      final i = list.indexWhere((x) => asInt(x['id']) == localId);
      if (i >= 0) {
        list[i] = {...list[i], 'id': realId}..remove('__pending');
        await _cachePut('list_$resourceKey', list);
      }
    }
  }

  Future<int> syncOutbox({bool manual = false}) async {
    if (syncing) return 0;
    final ops = _outbox.where((o) => o.scope == scope).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (ops.isEmpty) {
      if (manual) notifyListeners();
      return 0;
    }
    if (!online) {
      if (manual) notifyListeners();
      return 0;
    }

    syncing = true;
    notifyListeners();
    try {
      final batch = ops.take(100).toList();
      final data = asMap(await api.post(
        '/api/sync',
        {
          'ops': batch
              .map((o) => {
                    'opId': o.opId,
                    'method': o.method,
                    'resource': o.resource,
                    'id': (o.id != null && o.id! > 0) ? o.id : null,
                    'body': o.body,
                  })
              .toList(),
        },
        timeout: const Duration(seconds: 70),
      ));
      final results = asMapList(data['results']);
      final byId = {for (final o in batch) o.opId: o};
      var applied = 0;
      for (final result in results) {
        final op = byId[asString(result['opId'])];
        if (op == null) continue;
        if (asBool(result['ok'])) {
          applied++;
          _outbox.removeWhere((o) => o.opId == op.opId);
          final realId = asInt(result['id']);
          if (op.method == 'POST' && op.localId != null && realId != null) {
            await _replaceLocalId(op.resource, op.localId!, realId);
          }
        } else {
          op.tries++;
          op.error = asString(result['error']) ?? 'No se pudo aplicar.';
        }
      }
      await _saveOutbox();
      if (applied > 0) dashboard = null;
      online = true;
      return applied;
    } catch (_) {
      return 0;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> prefetchAll() async {
    try {
      try {
        final dash = asMap(await api.get('/api/dashboard'));
        dashboard = dash;
        await _cachePut('dashboard', dash);
      } catch (_) {}
      try {
        final notif = asMapList(await api.get('/api/notificaciones'));
        alerts = notif;
        await _cachePut('alerts', notif);
      } catch (_) {}
      final current = meta;
      if (current == null) return;
      for (final entry in current.resources.entries) {
        final r = entry.value;
        if (r.custom != null) continue;
        try {
          final data = asMap(await api.get('/api/r/${entry.key}?pagina=1&limit=300'));
          await _cachePut('list_${entry.key}', data['items']);
        } catch (_) {}
      }
      final names = <String>{};
      for (final r in current.resources.values) {
        for (final f in r.fields) {
          if (f.catalog != null) names.add(f.catalog!);
        }
      }
      for (final name in names) {
        try {
          final list = asMapList(await api.get('/api/cat/$name'));
          await _cachePut('cat_$name', list);
        } catch (_) {}
      }
      notifyListeners();
    } catch (_) {}
  }

  /* ------------------------------------------------------------------ */
  /* Cache local                                                        */
  /* ------------------------------------------------------------------ */

  String _key(String name) => 'sigfv_cache_${scope}_$name';

  dynamic _cacheGet(String name) {
    final raw = _prefs.getString(_key(name));
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cachePut(String name, Object? value) async {
    try {
      await _prefs.setString(_key(name), jsonEncode(value));
    } catch (_) {}
  }

  Future<void> _cacheRemove(String name) async {
    await _prefs.remove(_key(name));
  }

  String _globalKey(String name) => 'sigfv_cache_$name';

  dynamic _cacheGetGlobal(String name) {
    final raw = _prefs.getString(_globalKey(name));
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cachePutGlobal(String name, Object? value) async {
    try {
      await _prefs.setString(_globalKey(name), jsonEncode(value));
    } catch (_) {}
  }

  /* ------------------------------------------------------------------ */
  /* Exportación                                                        */
  /* ------------------------------------------------------------------ */

  String exportUrl(String? key) {
    final suffix = key == null ? '/all' : '/${Uri.encodeComponent(key)}';
    return '${AppConfig.apiBase}/api/export$suffix?token=${Uri.encodeQueryComponent(token)}';
  }
}
