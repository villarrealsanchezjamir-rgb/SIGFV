import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'public_registro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _password = TextEditingController();
  final _operador = TextEditingController();
  int? _empresaId;
  int? _rolId;
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _operador.dispose();
    super.dispose();
  }

  List<CompanyRole> _rolesFor(List<Company> companies, int? empresaId) {
    for (final c in companies) {
      if (c.id == empresaId) return c.roles;
    }
    return <CompanyRole>[];
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    setState(() => _error = null);
    if (_empresaId == null) {
      setState(() => _error = 'Seleccione la empresa.');
      return;
    }
    if (_rolId == null) {
      setState(() => _error = 'Seleccione el rol con el que ingresa.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Ingrese la contraseña del rol.');
      return;
    }

    setState(() => _loading = true);
    try {
      await app.login(
        empresaId: _empresaId!,
        rolId: _rolId!,
        password: _password.text,
        operador: _operador.text.trim().isEmpty ? null : _operador.text.trim(),
      );
      _password.clear();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadContext() async {
    final app = context.read<AppState>();
    setState(() => _error = null);
    try {
      await app.loadContext(force: true);
      if (!app.online) {
        setState(() => _error = 'Sin conexión con el servidor.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final roles = _rolesFor(app.companies, _empresaId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(26, 36, 26, 34),
                decoration: const BoxDecoration(
                  color: AppColors.dark,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Text(
                            'SF',
                            style: TextStyle(
                              color: AppColors.dark,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SIGFV',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .6,
                              ),
                            ),
                            Text(
                              'Gestión de flota vehicular',
                              style: TextStyle(
                                color: Color(0xFFB9B5AC),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Gestión de flota\nvehicular desde su dispositivo.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Elija su empresa y el rol con el que ingresa.',
                      style: TextStyle(color: Color(0xFFB9B5AC), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Conexión segura con el servidor de Render.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _Label('Empresa'),
                        AppDropdown<int>(
                          value: _empresaId,
                          hint: app.companies.isEmpty
                              ? 'Cargando empresas…'
                              : 'Seleccione su empresa…',
                          items: app.companies
                              .map((c) => DropdownMenuItem<int>(
                                    value: c.id,
                                    child: Text(
                                      '${c.razonSocial}${c.id == 0 ? ' · acceso global' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: app.companies.isEmpty
                              ? null
                              : (value) => setState(() {
                                    _empresaId = value;
                                    _rolId = null;
                                  }),
                        ),
                        if (app.companies.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: _reloadContext,
                              child: const Text('Reintentar carga de empresas'),
                            ),
                          ),
                        const SizedBox(height: 16),
                        const _Label('Rol'),
                        AppDropdown<int>(
                          value: _rolId,
                          hint: _empresaId == null
                              ? 'Seleccione una empresa'
                              : 'Seleccione su rol…',
                          enabled: _empresaId != null,
                          items: roles
                              .map((r) => DropdownMenuItem<int>(
                                    value: r.rolId,
                                    child: Text(
                                      '${r.nombre}${r.descripcion != null ? ' · ${r.descripcion}' : ''}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => _rolId = value),
                        ),
                        const SizedBox(height: 16),
                        const _Label('Su nombre (opcional)'),
                        TextField(
                          controller: _operador,
                          maxLength: 120,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Ej. Juan Pérez',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _Label('Contraseña del rol'),
                        TextField(
                          controller: _password,
                          obscureText: !_showPassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.bad.withOpacity(.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.bad,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text('Ingresar'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PublicRegistroScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.apartment_outlined, size: 18),
                          label: const Text('Registrar mi empresa y pedir vehículos'),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            app.online
                                ? 'Conexión segura · SIGFV v2.5'
                                : 'Sin internet: puede seguir trabajando si ya inició sesión antes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: app.online ? AppColors.muted : AppColors.warn,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
