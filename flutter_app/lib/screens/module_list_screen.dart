import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'record_form_screen.dart';

class ModuleListScreen extends StatefulWidget {
  final String resourceKey;
  const ModuleListScreen({super.key, required this.resourceKey});

  @override
  State<ModuleListScreen> createState() => _ModuleListScreenState();
}

class _ModuleListScreenState extends State<ModuleListScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  List<Map<String, dynamic>> _items = [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _offlineData = false;
  String? _error;

  ResourceDef? get _resource => context.read<AppState>().resource(widget.resourceKey);

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _page = 1;
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final data = await context.read<AppState>().fetchList(
            widget.resourceKey,
            query: _search.text.trim(),
            page: _page,
            limit: 20,
          );
      if (!mounted) return;
      final items = asMapList(data['items']);
      setState(() {
        _total = asInt(data['total']) ?? items.length;
        _items = reset ? items : [..._items, ...items];
        _offlineData = data['offline'] == true;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      _load(reset: true);
    });
  }

  Future<void> _openForm({int? id}) async {
    final r = _resource;
    if (r == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordFormScreen(resourceKey: widget.resourceKey, id: id),
      ),
    );
    if (changed == true) {
      _load(reset: true);
    }
  }

  Future<void> _export() async {
    final app = context.read<AppState>();
    final uri = Uri.parse(app.exportUrl(widget.resourceKey));
    showToast(context, 'Generando Excel…');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showToast(context, 'No se pudo abrir el archivo.', error: true);
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'No se pudo abrir el archivo.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.watch<AppState>().resource(widget.resourceKey);
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Módulo')),
        body: const EmptyState(
          title: 'Módulo no disponible',
          message: 'Su rol no tiene acceso a este módulo.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(r.label),
        actions: [
          if (r.exportar)
            IconButton(
              onPressed: _export,
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Exportar Excel',
            ),
          if (r.crear)
            IconButton(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Registrar',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: SearchField(
              controller: _search,
              hint: 'Buscar en ${r.label.toLowerCase()}…',
              onChanged: _onSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  _loading
                      ? 'Cargando…'
                      : '$_total registro${_total == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
                const Spacer(),
                if (_offlineData)
                  const Row(
                    children: [
                      Icon(Icons.cloud_off_outlined,
                          size: 13, color: AppColors.warn),
                      SizedBox(width: 4),
                      Text('Datos guardados',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.warn)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(r)),
        ],
      ),
    );
  }

  Widget _buildBody(ResourceDef r) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation(AppColors.gold),
        ),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.warning_amber_rounded,
        title: 'No se pudo cargar',
        message: _error!,
        onRetry: () => _load(reset: true),
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: _search.text.isEmpty
            ? Icons.inventory_2_outlined
            : Icons.search_off_rounded,
        title: _search.text.isEmpty ? 'Aún no hay registros' : 'Ningún resultado',
        message: _search.text.isEmpty
            ? (r.crear
                ? 'Use el botón + para crear el primero.'
                : 'No hay datos disponibles.')
            : 'Pruebe con otro término de búsqueda.',
        onRetry: _search.text.isEmpty ? null : () => _load(reset: true),
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _items.length + (_items.length < _total ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: OutlinedButton(
                onPressed: _loadingMore
                    ? null
                    : () {
                        _page++;
                        _load(reset: false);
                      },
                child: Text(_loadingMore
                    ? 'Cargando…'
                    : 'Cargar más (${_items.length} de $_total)'),
              ),
            );
          }
          return _RecordCard(
            resource: r,
            row: _items[index],
            onTap: () => _openForm(id: asInt(_items[index]['id'])),
          );
        },
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final ResourceDef resource;
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  const _RecordCard({
    required this.resource,
    required this.row,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cols = resource.cols;
    final first = cols.isNotEmpty ? cols.first : null;
    final second = cols.length > 1 ? cols[1] : null;
    final badgeCol = cols.where((c) => c.isBadge).cast<ColumnDef?>().firstWhere(
          (c) => true,
          orElse: () => null,
        );
    final rest = cols
        .skip(2)
        .where((c) => !c.isBadge)
        .take(3)
        .toList();

    final title = first == null
        ? 'Registro #${row['id']}'
        : (first.isBadge ? 'Registro #${row['id']}' : fmtValue(row[first.key]));
    final subtitle = (second == null || second.isBadge)
        ? null
        : fmtValue(row[second.key]);
    final pending = row['__pending'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badgeCol != null && row[badgeCol.key] != null) ...[
                          const SizedBox(width: 7),
                          StatusBadge(row[badgeCol.key].toString()),
                        ],
                        if (pending) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.cloud_upload_outlined,
                              size: 14, color: AppColors.warn),
                        ],
                      ],
                    ),
                    if (subtitle != null && subtitle != '—') ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                    if (rest.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 3,
                        children: rest
                            .map((c) => RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.muted,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${c.label}: ',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      TextSpan(
                                        text: c.isBadge
                                            ? row[c.key]?.toString() ?? '—'
                                            : fmtValue(row[c.key]),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(0xFFB9B5AC)),
            ],
          ),
        ),
      ),
    );
  }
}
