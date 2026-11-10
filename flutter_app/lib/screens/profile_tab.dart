import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileTab extends StatelessWidget {
  final VoidCallback onLoggedOut;
  const ProfileTab({super.key, required this.onLoggedOut});

  Future<void> _sync(BuildContext context) async {
    final app = context.read<AppState>();
    final applied = await app.syncOutbox(manual: true);
    if (!context.mounted) return;
    showToast(
      context,
      applied > 0
          ? 'Sincronizados $applied cambio(s).'
          : 'No hay cambios pendientes o no hay conexión.',
      error: applied == 0,
    );
  }

  Future<void> _exportAll(BuildContext context) async {
    final app = context.read<AppState>();
    final uri = Uri.parse(app.exportUrl(null));
    showToast(context, 'Generando libro completo…');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        showToast(context, 'No se pudo abrir el archivo.', error: true);
      }
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (changed == true && context.mounted) {
      showToast(context, 'Contraseña actualizada.');
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Cerrar sesión',
      message: '¿Desea cerrar la sesión actual?',
      confirmLabel: 'Cerrar sesión',
      destructive: true,
    );
    if (!ok) return;
    if (!context.mounted) return;
    await context.read<AppState>().logout();
    onLoggedOut();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final meta = app.meta;
    final name = meta?.user ?? 'Usuario';
    final roles = meta?.roles ?? <String>[];
    final modulesCount = meta?.resources.length ?? 0;
    final hasExport =
        meta?.resources.values.any((r) => r.exportar) ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.darkSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: Text(
                  initials(name),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                roles.isNotEmpty ? roles.join(' · ') : 'Sin rol asignado',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFB9B5AC), fontSize: 11.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: (roles.isEmpty ? ['Usuario SIGFV'] : roles)
                    .map((r) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.07),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white.withOpacity(.08)),
                          ),
                          child: Text(
                            r,
                            style: const TextStyle(
                                color: AppColors.gold, fontSize: 10),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SectionTitle('Cuenta y sistema'),
        Card(
          child: Column(
            children: [
              InfoRow(
                icon: Icons.apartment_outlined,
                title: 'Empresa',
                subtitle: 'Cliente del servicio',
                value: meta?.empresa ?? 'Todas las empresas',
              ),
              const Divider(height: 1, indent: 58),
              InfoRow(
                icon: Icons.shield_outlined,
                title: 'Rol',
                subtitle: 'Acceso actual',
                value: roles.isNotEmpty ? roles.first : '—',
              ),
              const Divider(height: 1, indent: 58),
              InfoRow(
                icon: Icons.person_outline,
                title: 'Operador',
                subtitle: 'Nombre registrado en auditoría',
                value: name,
              ),
              const Divider(height: 1, indent: 58),
              InfoRow(
                icon: Icons.speed_outlined,
                title: 'Módulos disponibles',
                subtitle: 'Según sus permisos',
                value: '$modulesCount',
              ),
              const Divider(height: 1, indent: 58),
              InfoRow(
                icon: Icons.sync_rounded,
                title: 'Cambios pendientes',
                subtitle: 'Operaciones por sincronizar',
                value: '${app.pending}',
              ),
              const Divider(height: 1, indent: 58),
              InfoRow(
                icon: Icons.wifi_rounded,
                title: 'Servidor',
                subtitle: app.online ? 'Conexión cifrada' : 'Sin conexión',
                value: app.online ? 'Operativo' : 'Guardado local',
                valueColor: app.online ? AppColors.ok : AppColors.warn,
              ),
              const Divider(height: 1, indent: 58),
              InfoRow(
                icon: Icons.info_outline_rounded,
                title: 'Versión',
                subtitle: 'Aplicación Flutter',
                value: AppConfig.appVersion,
              ),
            ],
          ),
        ),
        const SectionTitle('Módulos y responsables'),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < (meta?.owners.length ?? 0); i++) ...[
                if (i > 0) const Divider(height: 1, indent: 58),
                InfoRow(
                  icon: iconFor(_ownerIcon(meta!.owners[i].id)),
                  title: meta.owners[i].title,
                  subtitle: meta.owners[i].desc,
                  value: meta.owners[i].responsable,
                ),
              ],
            ],
          ),
        ),
        const SectionTitle('Sincronización y reportes'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _sync(context),
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: Text(
                    'Sincronizar ahora${app.pending > 0 ? ' (${app.pending})' : ''}',
                  ),
                ),
                if (hasExport) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _exportAll(context),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Exportar todos los módulos'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SectionTitle('Seguridad'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: OutlinedButton.icon(
              onPressed: () => _changePassword(context),
              icon: const Icon(Icons.vpn_key_outlined, size: 18),
              label: const Text('Cambiar contraseña del rol'),
            ),
          ),
        ),
        const SectionTitle('Sesión'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bad,
                    side: const BorderSide(color: AppColors.bad),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SIGFV · Sistema Integral de Gestión de Flota Vehicular',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _ownerIcon(String id) {
    switch (id) {
      case 'operaciones':
        return 'truck';
      case 'mantenimiento':
        return 'wrench';
      case 'logistica':
        return 'fuel';
      case 'seguridad':
        return 'shield';
      default:
        return 'settings';
    }
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repite = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repite.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_actual.text.isEmpty) {
      setState(() => _error = 'Ingrese la contraseña actual.');
      return;
    }
    if (_nueva.text.length < 8) {
      setState(() => _error = 'La nueva contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (_nueva.text != _repite.text) {
      setState(() => _error = 'Las contraseñas nuevas no coinciden.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().changePassword(_actual.text, _nueva.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña del rol',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La contraseña es del rol: todos los que ingresen con este rol usarán la nueva clave.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _actual,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nueva,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _repite,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repetir nueva contraseña'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.bad,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Text('Actualizar'),
        ),
      ],
    );
  }
}
