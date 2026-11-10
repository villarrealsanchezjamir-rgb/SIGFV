import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'alerts_tab.dart';
import 'dashboard_tab.dart';
import 'module_list_screen.dart';
import 'modules_tab.dart';
import 'profile_tab.dart';
import 'record_form_screen.dart';
import 'solicitudes_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _openList(String key) {
    if (key == 'solicitudes') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SolicitudesScreen()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ModuleListScreen(resourceKey: key)),
    );
  }

  void _create(String key) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecordFormScreen(resourceKey: key)),
    );
  }

  Future<void> _sync() async {
    final app = context.read<AppState>();
    final applied = await app.syncOutbox(manual: true);
    if (!mounted) return;
    showToast(
      context,
      applied > 0
          ? 'Sincronizados $applied cambio(s).'
          : 'No hay cambios sincronizados.',
      error: applied == 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final meta = app.meta;
    final name = meta?.user ?? 'Usuario';
    final hasAlerts = app.alerts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        titleSpacing: 14,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'SF',
                style: TextStyle(
                  color: AppColors.dark,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SIGFV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                    ),
                  ),
                  Text(
                    meta?.empresa ?? 'Gestión de flota',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFA9A9A9),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (app.pending > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton.icon(
                onPressed: _sync,
                icon: const Icon(Icons.sync_rounded, size: 15, color: AppColors.gold),
                label: Text(
                  '${app.pending}',
                  style: const TextStyle(color: AppColors.gold, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(.06),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Tooltip(
              message: app.online ? 'En línea' : 'Sin conexión',
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: app.online ? AppColors.ok : AppColors.warn,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (app.online ? AppColors.ok : AppColors.warn)
                          .withOpacity(.35),
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _index = 2),
            icon: Badge(
              isLabelVisible: hasAlerts,
              backgroundColor: AppColors.bad,
              smallSize: 7,
              child: const Icon(Icons.notifications_none_rounded, size: 22),
            ),
            tooltip: 'Alertas',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 1),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _index = 3),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF2F2F2F),
                child: Text(
                  initials(name),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardTab(
            onOpenModule: _openList,
            onCreate: _create,
            onNavigateTab: (i) => setState(() => _index = i),
          ),
          ModulesTab(onOpen: _openList),
          const AlertsTab(),
          ProfileTab(onLoggedOut: () => setState(() => _index = 0)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: AppColors.dark,
          unselectedItemColor: const Color(0xFF9A9EA3),
          selectedLabelStyle:
              const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 10.5),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Módulos',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: hasAlerts,
                smallSize: 7,
                backgroundColor: AppColors.bad,
                child: const Icon(Icons.notifications_none_rounded),
              ),
              activeIcon: const Icon(Icons.notifications_rounded),
              label: 'Alertas',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
