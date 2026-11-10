import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ModulesTab extends StatefulWidget {
  final void Function(String key) onOpen;
  const ModulesTab({super.key, required this.onOpen});

  @override
  State<ModulesTab> createState() => _ModulesTabState();
}

class _ModulesTabState extends State<ModulesTab> {
  final _search = TextEditingController();

  static const _groups = [
    _Group('operaciones', 'Gestión de Operaciones', 'truck',
        'Flota, conductores y asignaciones', 'Supervisor de flota'),
    _Group('mantenimiento', 'Gestión de Mantenimiento', 'wrench',
        'Servicios e inspecciones', 'Responsable de mantenimiento'),
    _Group('logistica', 'Gestión Logística', 'fuel',
        'Combustible y documentación', 'Encargado de logística'),
    _Group('seguridad', 'Gestión de Seguridad', 'shield',
        'Incidentes y acciones', 'Personal de seguridad'),
    _Group('administracion', 'Administración', 'settings',
        'Usuarios y catálogos', 'Administrador'),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _groupFor(String key, ResourceDef r) {
    switch (key) {
      case 'vehiculos':
      case 'conductores':
      case 'asignaciones':
        return 'operaciones';
      case 'mantenimientos':
      case 'inspecciones':
        return 'mantenimiento';
      case 'abastecimientos':
      case 'documentos':
        return 'logistica';
      case 'incidentes':
        return 'seguridad';
      case 'solicitudes':
        return 'administracion';
      default:
        return r.mod == 'configuracion' ? 'administracion' : 'operaciones';
    }
  }

  Map<String, List<ResourceDef>> _byGroup(AuthMeta meta) {
    final map = <String, List<ResourceDef>>{
      for (final g in _groups) g.id: <ResourceDef>[],
    };
    for (final entry in meta.resources.entries) {
      final r = entry.value;
      if (r.custom != null && entry.key != 'solicitudes') continue;
      final gid = _groupFor(entry.key, r);
      (map[gid] ?? map['operaciones']!).add(r);
    }
    for (final list in map.values) {
      list.sort((a, b) {
        final cmp = a.order.compareTo(b.order);
        return cmp != 0 ? cmp : a.label.compareTo(b.label);
      });
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final meta = app.meta;
    if (meta == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = _search.text.toLowerCase().trim();
    final byGroup = _byGroup(meta);
    final groups = _groups.where((g) {
      final items = byGroup[g.id] ?? [];
      return items.any((r) =>
          query.isEmpty || r.label.toLowerCase().contains(query));
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        if (app.pending > 0)
          _Banner(
            color: AppColors.gold,
            icon: Icons.sync_rounded,
            title: '${app.pending} cambio(s) sin sincronizar',
            subtitle: 'Tocar para sincronizar con el servidor',
            onTap: () async {
              final applied = await app.syncOutbox(manual: true);
              if (!mounted) return;
              showToast(
                context,
                applied > 0
                    ? 'Sincronizados $applied cambio(s).'
                    : 'Aún no se pudo sincronizar.',
                error: applied == 0,
              );
            },
          )
        else if (!app.online)
          const _Banner(
            color: AppColors.warn,
            icon: Icons.info_outline_rounded,
            title: 'Sin conexión',
            subtitle: 'Puede consultar y registrar; se sincronizará al volver internet.',
          ),
        const SizedBox(height: 2),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Buscar módulo…',
            prefixIcon: Icon(Icons.search_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 6),
        if (groups.isEmpty)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Ningún módulo coincide',
            message: 'Pruebe con otro término de búsqueda.',
          ),
        for (final g in groups) ...[
          _GroupHeader(group: g),
          _GroupCard(
            group: g,
            items: (byGroup[g.id] ?? [])
                .where((r) =>
                    query.isEmpty || r.label.toLowerCase().contains(query))
                .toList(),
            pendingRequests: meta.solicitudesPendientes,
            onOpen: widget.onOpen,
          ),
        ],
      ],
    );
  }
}

class _Group {
  final String id;
  final String title;
  final String icon;
  final String desc;
  final String owner;
  const _Group(this.id, this.title, this.icon, this.desc, this.owner);
}

class _GroupHeader extends StatelessWidget {
  final _Group group;
  const _GroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconFor(group.icon), color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  group.desc,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    group.owner,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A6220),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final _Group group;
  final List<ResourceDef> items;
  final int pendingRequests;
  final void Function(String key) onOpen;

  const _GroupCard({
    required this.group,
    required this.items,
    required this.pendingRequests,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = group.id == 'administracion';
    final users = isAdmin ? items.where((r) => r.mod == 'usuarios').toList() : <ResourceDef>[];
    final rest = isAdmin ? items.where((r) => r.mod != 'usuarios').toList() : items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (users.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Usuarios',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                    letterSpacing: .8)),
          ),
          _card(users),
          const SizedBox(height: 10),
        ],
        if (isAdmin && rest.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Catálogos maestros',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                    letterSpacing: .8)),
          ),
        _card(rest),
      ],
    );
  }

  Widget _card(List<ResourceDef> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 58),
            _ModuleTile(
              resource: list[i],
              badge: list[i].key == 'solicitudes' ? pendingRequests : 0,
              onTap: () => onOpen(list[i].key),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final ResourceDef resource;
  final int badge;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.resource,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hint = resource.key == 'solicitudes'
        ? 'Revisar, aprobar y asignar'
        : resource.crear
            ? 'Consultar y registrar'
            : 'Solo consulta';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconFor(resource.icon),
                  size: 18, color: AppColors.dark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$hint · ${resource.responsable ?? 'Administrador'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bad,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFFB9B5AC)),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.muted)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
