import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  static const _filters = [
    ['todas', 'Todas'],
    ['documentos', 'Documentos'],
    ['licencias', 'Licencias'],
    ['inspecciones', 'Inspecciones'],
    ['incidentes', 'Incidentes'],
    ['vehiculos', 'Vehículos'],
  ];

  String _filter = 'todas';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().ensureAlerts(force: force);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _prefix(String filter) {
    switch (filter) {
      case 'documentos':
        return 'documento';
      case 'licencias':
        return 'licencia';
      case 'inspecciones':
        return 'inspecci';
      case 'incidentes':
        return 'incidente';
      case 'vehiculos':
        return 'vehículo';
      default:
        return '';
    }
  }

  IconData _icon(String tipo) {
    final t = tipo.toLowerCase();
    if (t.startsWith('documento')) return Icons.description_outlined;
    if (t.startsWith('licencia')) return Icons.badge_outlined;
    if (t.startsWith('inspecci')) return Icons.assignment_outlined;
    if (t.startsWith('incidente')) return Icons.warning_amber_rounded;
    return Icons.local_shipping_outlined;
  }

  Color _color(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('vencid')) return AppColors.bad;
    if (t.contains('por vencer')) return AppColors.warn;
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final data = app.alerts;
    final meta = app.meta;

    if (meta?.notificaciones != true) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sin acceso a alertas',
        message: 'Su rol no tiene permiso para consultar notificaciones.',
      );
    }

    final counts = <String, int>{};
    for (final f in _filters) {
      final key = f[0];
      final prefix = _prefix(key);
      counts[key] = key == 'todas'
          ? data.length
          : data
              .where((n) =>
                  (n['tipo'] ?? '').toString().toLowerCase().startsWith(prefix))
              .length;
    }
    final items = _filter == 'todas'
        ? data
        : data
            .where((n) => (n['tipo'] ?? '')
                .toString()
                .toLowerCase()
                .startsWith(_prefix(_filter)))
            .toList();

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          SectionTitle(
            'Alertas del sistema',
            trailing: IconButton(
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Actualizar',
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
            )
          else if (_error != null)
            EmptyState(
              icon: Icons.warning_amber_rounded,
              title: 'No se pudieron cargar las alertas',
              message: _error!,
              onRetry: () => _load(),
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _filters.map((f) {
                final selected = _filter == f[0];
                return ChoiceChip(
                  selected: selected,
                  label: Text('${f[1]} (${counts[f[0]] ?? 0})'),
                  onSelected: (_) => setState(() => _filter = f[0]),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: 'Sin alertas en esta categoría',
                message: 'Todo en orden por ahora.',
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 48),
                      _AlertRow(
                        item: items[i],
                        icon: _icon((items[i]['tipo'] ?? '').toString()),
                        color: _color((items[i]['tipo'] ?? '').toString()),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final IconData icon;
  final Color color;

  const _AlertRow({
    required this.item,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asString(item['detalle']) ?? '—',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  asString(item['tipo']) ?? '—',
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmtValue(item['fecha']),
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
