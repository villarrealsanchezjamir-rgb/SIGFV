import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DashboardTab extends StatefulWidget {
  final void Function(String key) onOpenModule;
  final void Function(String key) onCreate;
  final void Function(int index) onNavigateTab;

  const DashboardTab({
    super.key,
    required this.onOpenModule,
    required this.onCreate,
    required this.onNavigateTab,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  static const _kpis = <_KpiDef>[
    _KpiDef('total', 'Vehículos', 'truck', AppColors.gold),
    _KpiDef('conductores', 'Conductores activos', 'id-card', AppColors.ok),
    _KpiDef('insp_nc', 'Inspecciones no conformes', 'clipboard', AppColors.bad),
    _KpiDef('docs', 'Docs por vencer', 'file', AppColors.warn),
    _KpiDef('mant', 'Mantenimientos', 'wrench', AppColors.info),
    _KpiDef('litros', 'Combustible (L)', 'fuel', AppColors.ink),
    _KpiDef('incidentes', 'Incidentes abiertos', 'alert', AppColors.bad),
  ];

  static const _quick = [
    ['vehiculos', 'Vehículo', 'truck'],
    ['conductores', 'Conductor', 'id-card'],
    ['asignaciones', 'Asignación', 'calendar'],
    ['inspecciones', 'Inspección', 'clipboard'],
    ['abastecimientos', 'Combustible', 'fuel'],
    ['mantenimientos', 'Mantenimiento', 'wrench'],
    ['incidentes', 'Incidente', 'alert'],
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final app = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await app.ensureDashboard(force: force);
      if (app.meta?.notificaciones == true) {
        try {
          await app.ensureAlerts(force: force);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final meta = app.meta;
    final user = meta?.user ?? 'Usuario';
    final firstName = user.split(' ').first;

    if (meta?.dashboard != true) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sin acceso al panel',
        message: 'Su rol no tiene permiso para consultar el dashboard.',
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _buildHero(app, firstName),
          const SizedBox(height: 4),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 50),
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
              title: 'No se pudo cargar el panel',
              message: _error!,
              onRetry: () => _load(force: true),
            )
          else ..._buildData(app, _data ?? const {}),
        ],
      ),
    );
  }

  Widget _buildHero(AppState app, String firstName) {
    final meta = app.meta;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF232323), Color(0xFF141414)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PANEL DE CONTROL',
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hola, $firstName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${_todayLabel()} · ${(meta?.roles.isNotEmpty ?? false) ? meta!.roles.join(', ') : 'Usuario SIGFV'}',
            style: const TextStyle(color: Color(0xFFB9B5AC), fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.07),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(.08)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 13, color: AppColors.gold),
                    SizedBox(width: 5),
                    Text(
                      'Conexión segura',
                      style: TextStyle(color: Colors.white, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _load(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Actualizar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  minimumSize: const Size(0, 34),
                  textStyle: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildData(AppState app, Map<String, dynamic> data) {
    final k = asMap(data['k']);
    final estados = asMapList(data['estados']);
    final mant = asMapList(data['mant']);
    final docs = asMapList(data['docs']);
    final totalFleet = estados.fold<int>(0, (sum, e) => sum + (asInt(e['n']) ?? 0));

    final quickItems = _quick
        .where((q) => app.resource(q[0])?.crear == true)
        .toList();

    return [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        itemCount: _kpis.length,
        itemBuilder: (context, i) {
          final def = _kpis[i];
          final value = k[def.key];
          final display =
              def.key == 'litros' ? fmtNum(value) : fmtNum(value ?? 0);
          return _KpiCard(
            icon: iconFor(def.icon),
            color: def.color,
            value: display,
            label: def.label,
          );
        },
      ),
      const SectionTitle('Acciones rápidas'),
      if (quickItems.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Su rol no permite registrar datos.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        )
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: quickItems
                  .map((q) => _QuickButton(
                        icon: iconFor(q[2]),
                        label: q[1],
                        onTap: () => widget.onCreate(q[0]),
                      ))
                  .toList(),
            ),
          ),
        ),
      SectionTitle(
        'Estado de la flota',
        trailing: Text(
          '$totalFleet unidades',
          style: const TextStyle(
              fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: estados.isEmpty
              ? const Text('Sin datos.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted))
              : Column(
                  children: estados.map((e) {
                    final n = asInt(e['n']) ?? 0;
                    final ratio = totalFleet == 0 ? 0.0 : n / totalFleet;
                    final color = _hexColor(asString(e['color'])) ?? AppColors.dark;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(
                              asString(e['nombre']) ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 7,
                                backgroundColor: AppColors.bg,
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            child: Text(
                              '$n',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
      SectionTitle(
        'Próximos mantenimientos',
        trailing: app.resource('mantenimientos') != null
            ? TextButton(
                onPressed: () => widget.onOpenModule('mantenimientos'),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 6)),
                child: const Text('Ver todos',
                    style: TextStyle(fontSize: 11.5)),
              )
            : null,
      ),
      Card(
        child: mant.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: Text('Sin mantenimientos programados',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              )
            : Column(
                children: mant
                    .map((m) => _listRow(
                          icon: Icons.build_outlined,
                          title: asString(m['vehiculo']) ?? '—',
                          subtitle: asString(m['tipo']) ?? '—',
                          trailing: fmtValue(m['fecha']),
                        ))
                    .toList(),
              ),
      ),
      SectionTitle(
        'Documentos por vencer',
        trailing: app.resource('documentos') != null
            ? TextButton(
                onPressed: () => widget.onOpenModule('documentos'),
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 6)),
                child: const Text('Ver todos',
                    style: TextStyle(fontSize: 11.5)),
              )
            : null,
      ),
      Card(
        child: docs.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: Text('Sin documentos por vencer',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              )
            : Column(
                children: docs
                    .map((d) => _listRow(
                          icon: Icons.description_outlined,
                          iconColor: AppColors.warn,
                          title: asString(d['titular']) ?? '—',
                          subtitle: asString(d['documento']) ?? '—',
                          trailing: fmtValue(d['vence']),
                        ))
                    .toList(),
              ),
      ),
    ];
  }

  Widget _listRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 19, color: iconColor ?? AppColors.muted),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(trailing,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  String _todayLabel() {
    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}';
  }

  Color? _hexColor(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return null;
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}

class _KpiDef {
  final String key;
  final String label;
  final String icon;
  final Color color;

  const _KpiDef(this.key, this.label, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _KpiCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: color),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.1,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: SizedBox(
          width: 74,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.goldSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: AppColors.dark),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
