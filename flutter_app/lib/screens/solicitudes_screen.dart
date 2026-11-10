import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  static const _chips = [
    ['pendiente', 'Pendientes'],
    ['aprobada', 'Aprobadas'],
    ['rechazada', 'Rechazadas'],
    ['', 'Todas'],
  ];

  final _search = TextEditingController();
  Timer? _debounce;
  String _estado = 'pendiente';
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<AppState>().api.get(
            '/api/solicitudes?estado=${Uri.encodeQueryComponent(_estado)}'
            '&q=${Uri.encodeQueryComponent(_search.text.trim())}',
          );
      if (!mounted) return;
      setState(() {
        _items = asMapList(data);
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

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _load);
  }

  Future<void> _openDetail(int id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SolicitudDetailScreen(id: id)),
    );
    if (!mounted) return;
    if (changed == true) {
      await context.read<AppState>().refreshMeta();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final resource = app.resource('solicitudes');
    if (resource == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitudes')),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Sin permiso',
          message: 'Su rol no puede revisar solicitudes de empresas.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de empresas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _chips.map((c) {
                  final selected = _estado == c[0];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: selected,
                      label: Text(c[1]),
                      onSelected: (_) {
                        setState(() => _estado = c[0]);
                        _load();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(
              controller: _search,
              hint: 'Buscar RUC, empresa o código…',
              onChanged: _onSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _loading
                    ? 'Cargando…'
                    : '${_items.length} solicitud${_items.length == 1 ? '' : 'es'}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
        title: 'No se pudieron cargar',
        message: _error!,
        onRetry: _load,
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.apartment_outlined,
        title: 'No hay solicitudes',
        message:
            'Las empresas pueden registrarse desde la pantalla de acceso de la web o de la aplicación.',
      );
    }

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final s = _items[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 9),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openDetail(asInt(s['id']) ?? 0),
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
                                  asString(s['razon_social']) ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 7),
                              StatusBadge(asString(s['estado']) ?? '—'),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${asString(s['codigo']) ?? '—'} · RUC ${asString(s['ruc']) ?? '—'}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Contacto: ${asString(s['contacto']) ?? '—'}   ·   '
                            'Vehículos: ${asInt(s['unidades']) ?? 0}   ·   '
                            'Asignados: ${asInt(s['asignados']) ?? 0}',
                            style: const TextStyle(
                                fontSize: 10.5, color: AppColors.muted),
                          ),
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
        },
      ),
    );
  }
}

class SolicitudDetailScreen extends StatefulWidget {
  final int id;
  const SolicitudDetailScreen({super.key, required this.id});

  @override
  State<SolicitudDetailScreen> createState() => _SolicitudDetailScreenState();
}

class _SolicitudDetailScreenState extends State<SolicitudDetailScreen> {
  final _unidad = TextEditingController();
  final _obs = TextEditingController();

  Map<String, dynamic>? _solicitud;
  List<Map<String, dynamic>> _vehiculos = [];
  List<Map<String, dynamic>> _conductores = [];
  final Map<int, int?> _vehiculoPorItem = {};
  final Map<int, int?> _conductorPorItem = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _editable =>
      (_solicitud?['estado']?.toString() ?? '') == 'pendiente' &&
      (context.read<AppState>().resource('solicitudes')?.editar ?? false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _unidad.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        app.api.get('/api/solicitudes/${widget.id}'),
        app.api
            .get('/api/solicitudes/asignables')
            .catchError((_) => <String, dynamic>{'vehiculos': [], 'conductores': []}),
      ]);
      if (!mounted) return;
      final solicitud = asMap(results[0]);
      final asignables = asMap(results[1]);
      _solicitud = solicitud;
      _vehiculos = asMapList(asignables['vehiculos']);
      _conductores = asMapList(asignables['conductores']);
      _unidad.text = asString(solicitud['unidad_solicitada']) ??
          asString(solicitud['razon_social']) ??
          '';
      _obs.text = asString(solicitud['respuesta_admin']) ?? '';
      for (final item in asMapList(solicitud['items'])) {
        final itemId = asInt(item['id']) ?? 0;
        _vehiculoPorItem[itemId] = asInt(item['vehiculo_id']);
        _conductorPorItem[itemId] = asInt(item['conductor_id']);
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _approve() async {
    final s = _solicitud;
    if (s == null) return;
    final items = asMapList(s['items']);
    final asignaciones = <Map<String, dynamic>>[];
    for (final item in items) {
      final itemId = asInt(item['id']) ?? 0;
      final vehiculo = _vehiculoPorItem[itemId];
      if (vehiculo != null && vehiculo > 0) {
        asignaciones.add({
          'itemId': itemId,
          'vehiculoId': vehiculo,
          'conductorId': _conductorPorItem[itemId],
        });
      }
    }
    final used = <int>{};
    for (final a in asignaciones) {
      if (!used.add(a['vehiculoId'] as int)) {
        showToast(context, 'Un vehículo no puede asignarse dos veces.',
            error: true);
        return;
      }
    }
    if (asignaciones.isEmpty) {
      final ok = await confirmDialog(
        context,
        title: 'Aprobar sin vehículos',
        message:
            'No seleccionó vehículos. ¿Aprobar la empresa y dejar los pedidos sin asignar?',
        confirmLabel: 'Aprobar',
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    try {
      final result = asMap(await context.read<AppState>().api.post(
        '/api/solicitudes/${widget.id}/aprobar',
        {
          'observacion': _obs.text.trim(),
          'unidadNombre': _unidad.text.trim(),
          'items': asignaciones,
        },
        timeout: const Duration(seconds: 60),
      ));
      if (!mounted) return;
      await context.read<AppState>().refreshMeta();
      if (!mounted) return;
      showToast(context,
          'Solicitud aprobada. ${asInt(result['asignados']) ?? 0} vehículo(s) asignado(s).');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, e.toString(), error: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _reject() async {
    final motivo = _obs.text.trim();
    if (motivo.length < 5) {
      showToast(context, 'Escriba el motivo del rechazo en Observaciones.',
          error: true);
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Rechazar solicitud',
      message:
          '¿Rechazar la solicitud de «${asString(_solicitud?['razon_social']) ?? ''}»?',
      confirmLabel: 'Rechazar',
      destructive: true,
    );
    if (!ok) return;

    setState(() => _saving = true);
    try {
      await context.read<AppState>().api.post(
        '/api/solicitudes/${widget.id}/rechazar',
        {'observacion': motivo},
      );
      if (!mounted) return;
      await context.read<AppState>().refreshMeta();
      if (!mounted) return;
      showToast(context, 'Solicitud rechazada.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, e.toString(), error: true);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = _editable;
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de empresa')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(AppColors.gold),
              ),
            )
          : _error != null
              ? EmptyState(
                  icon: Icons.warning_amber_rounded,
                  title: 'No se pudo abrir',
                  message: _error!,
                  onRetry: _load,
                )
              : _buildDetail(editable),
      bottomNavigationBar: _loading || _error != null || !editable
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.bad,
                          side: const BorderSide(color: AppColors.bad),
                        ),
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _saving ? null : _approve,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Aprobar y asignar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDetail(bool editable) {
    final s = _solicitud ?? {};
    final items = asMapList(s['items']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        asString(s['razon_social']) ?? '—',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    StatusBadge(asString(s['estado']) ?? '—'),
                  ],
                ),
                const SizedBox(height: 12),
                _kv('RUC', asString(s['ruc'])),
                _kv('Código', asString(s['codigo'])),
                _kv(
                  'Contacto',
                  '${asString(s['contacto']) ?? '—'}${s['cargo'] != null ? ' · ${asString(s['cargo'])}' : ''}',
                ),
                _kv('Teléfono', asString(s['telefono'])),
                _kv('Correo', asString(s['correo'])),
                _kv('Dirección', asString(s['direccion'])),
                _kv('Unidad solicitada', asString(s['unidad_solicitada'])),
              ],
            ),
          ),
        ),
        const SectionTitle('Requisitos y alcance'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              [
                asString(s['requisitos']) ?? '—',
                if (s['observaciones'] != null)
                  '\nObservaciones: ${asString(s['observaciones'])}',
                if (s['respuesta_admin'] != null)
                  '\nRespuesta del administrador: ${asString(s['respuesta_admin'])}',
              ].join(),
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          ),
        ),
        SectionTitle('Vehículos solicitados (${items.length})'),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text('Sin vehículos registrados',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          )
        else
          ...items.map((item) => _itemCard(item, editable)),
        if (editable) ...[
          const SectionTitle('Datos de la asignación'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unidad minera del cliente',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _unidad,
                    maxLength: 150,
                    decoration: const InputDecoration(counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  const Text('Observación o motivo del rechazo',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _obs,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText:
                          'Condiciones de la asignación o motivo del rechazo',
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _kv(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value == null || value.isEmpty ? '—' : value,
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item, bool editable) {
    final itemId = asInt(item['id']) ?? 0;
    final assigned = asInt(item['vehiculo_id']);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${asString(item['tipo']) ?? 'Vehículo'}'
                    '${item['categoria'] != null ? ' · ${asString(item['categoria'])}' : ''}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                StatusBadge(asString(item['estado']) ?? '—'),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Cantidad: ${asInt(item['cantidad']) ?? 1}   ·   '
              'Desde: ${fmtValue(item['fecha_inicio'])}   ·   '
              'Hasta: ${fmtValue(item['fecha_fin'])}   ·   '
              'Conductor: ${asBool(item['requiere_conductor']) ? 'Sí' : 'No'}',
              style:
                  const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
            if (item['detalles'] != null) ...[
              const SizedBox(height: 6),
              Text(
                asString(item['detalles']) ?? '',
                style: const TextStyle(fontSize: 11, height: 1.35),
              ),
            ],
            if (editable) ...[
              const SizedBox(height: 10),
              const Text('Vehículo', style: _labelStyle),
              const SizedBox(height: 5),
              AppDropdown<int>(
                value: _vehiculoPorItem[itemId],
                hint: '— Sin asignar —',
                items: [
                  const DropdownMenuItem<int>(
                      value: 0, child: Text('— Sin asignar —')),
                  ..._vehiculos.map((v) => DropdownMenuItem<int>(
                        value: asInt(v['id']),
                        child: Text(
                          '${asString(v['codigo_interno']) ?? ''}'
                          '${v['placa'] != null && v['placa'].toString().isNotEmpty ? ' · ${v['placa']}' : ''}'
                          '${v['estado'] != null ? ' · ${v['estado']}' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (value) => setState(() =>
                    _vehiculoPorItem[itemId] =
                        (value == null || value == 0) ? null : value),
              ),
              const SizedBox(height: 10),
              const Text('Conductor', style: _labelStyle),
              const SizedBox(height: 5),
              AppDropdown<int>(
                value: _conductorPorItem[itemId],
                hint: '— Sin conductor —',
                items: [
                  const DropdownMenuItem<int>(
                      value: 0, child: Text('— Sin conductor —')),
                  ..._conductores.map((c) => DropdownMenuItem<int>(
                        value: asInt(c['id']),
                        child: Text(
                          '${asString(c['apellidos']) ?? ''}, ${asString(c['nombres']) ?? ''}'
                          '${c['licencia_vence'] != null && c['licencia_vence'].toString().isNotEmpty ? ' · lic. ${c['licencia_vence']}' : ' · sin licencia'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (value) => setState(() =>
                    _conductorPorItem[itemId] =
                        (value == null || value == 0) ? null : value),
              ),
            ] else if (assigned != null) ...[
              const SizedBox(height: 9),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.ok.withOpacity(.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined,
                        size: 15, color: AppColors.ok),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${asString(item['vehiculo_codigo']) ?? 'Vehículo'}'
                        '${item['vehiculo_placa'] != null ? ' · ${item['vehiculo_placa']}' : ''}'
                        '${item['conductor'] != null ? ' · ${item['conductor']}' : ''}',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.ok),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (asString(_solicitud?['estado']) != 'pendiente')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Sin vehículo asignado',
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.muted)),
              ),
          ],
        ),
      ),
    );
  }

  static const _labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
}
