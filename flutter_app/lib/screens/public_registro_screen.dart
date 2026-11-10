import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api_client.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Registro público de empresas clientes y solicitud de vehículos.
/// Se conecta a /api/public/registro/opciones y /api/public/solicitudes,
/// los mismos endpoints que usa la web pública.
class PublicRegistroScreen extends StatefulWidget {
  const PublicRegistroScreen({super.key});

  @override
  State<PublicRegistroScreen> createState() => _PublicRegistroScreenState();
}

class _PublicRegistroScreenState extends State<PublicRegistroScreen> {
  final _formKey = GlobalKey<FormState>();

  final _ruc = TextEditingController();
  final _razonSocial = TextEditingController();
  final _contacto = TextEditingController();
  final _cargo = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _direccion = TextEditingController();
  final _actividad = TextEditingController();
  final _unidad = TextEditingController();
  final _requisitos = TextEditingController();
  final _observaciones = TextEditingController();
  final _website = TextEditingController(); // campo trampa para bots

  List<Map<String, dynamic>> _tipos = [];
  List<Map<String, dynamic>> _categorias = [];
  List<String> _requisitosInfo = [];
  String _nota = '';

  final List<_VehiculoRow> _vehiculos = [];

  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _vehiculos.add(_VehiculoRow());
    _loadOpciones();
  }

  @override
  void dispose() {
    for (final c in [
      _ruc,
      _razonSocial,
      _contacto,
      _cargo,
      _telefono,
      _correo,
      _direccion,
      _actividad,
      _unidad,
      _requisitos,
      _observaciones,
      _website,
    ]) {
      c.dispose();
    }
    for (final v in _vehiculos) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOpciones() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = asMap(await context.read<AppState>().api.get(
            '/api/public/registro/opciones',
            timeout: const Duration(seconds: 45),
          ));
      if (!mounted) return;
      setState(() {
        _tipos = asMapList(data['tipos']);
        _categorias = asMapList(data['categorias']);
        final req = data['requisitos'];
        _requisitosInfo = req is List ? req.map((e) => e.toString()).toList() : [];
        _nota = asString(data['nota']) ?? '';
        for (final row in _vehiculos) {
          row.setCatalogos(_tipos, _categorias);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  void _addVehiculo() {
    if (_vehiculos.length >= 10) {
      showToast(context, 'Puede agregar hasta 10 líneas de vehículos.',
          error: true);
      return;
    }
    final row = _VehiculoRow()..setCatalogos(_tipos, _categorias);
    setState(() => _vehiculos.add(row));
  }

  void _removeVehiculo(int index) {
    if (_vehiculos.length == 1) return;
    final row = _vehiculos.removeAt(index);
    row.dispose();
    setState(() {});
  }

  String _dateForBody(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ruc = _ruc.text.replaceAll(RegExp(r'\D'), '');
    if (ruc.length != 11) {
      setState(() => _error = 'Ingrese un RUC válido de 11 dígitos.');
      return;
    }
    if (_requisitos.text.trim().length < 10) {
      setState(() =>
          _error = 'Describa con más detalle los requisitos o el servicio.');
      return;
    }

    final vehiculos = <Map<String, dynamic>>[];
    for (var i = 0; i < _vehiculos.length; i++) {
      final row = _vehiculos[i];
      if (row.tipoId == null) {
        setState(() => _error = 'Seleccione el tipo del vehículo ${i + 1}.');
        return;
      }
      final cantidad = int.tryParse(row.cantidad.text.trim()) ?? 1;
      if (cantidad < 1 || cantidad > 50) {
        setState(() =>
            _error = 'La cantidad del vehículo ${i + 1} debe estar entre 1 y 50.');
        return;
      }
      if (row.inicio != null &&
          row.fin != null &&
          row.fin!.isBefore(row.inicio!)) {
        setState(() =>
            _error = 'La fecha final del vehículo ${i + 1} no puede ser anterior al inicio.');
        return;
      }
      vehiculos.add({
        'tipoVehiculoId': row.tipoId,
        'categoriaVehiculoId': row.categoriaId,
        'cantidad': cantidad,
        'fechaInicio': _dateForBody(row.inicio),
        'fechaFin': _dateForBody(row.fin),
        'requiereConductor': row.requiereConductor,
        'detalles': row.detalles.text.trim(),
      });
    }

    setState(() => _sending = true);
    try {
      final result = asMap(await context.read<AppState>().api.post(
            '/api/public/solicitudes',
            {
              'ruc': ruc,
              'razonSocial': _razonSocial.text.trim(),
              'contacto': _contacto.text.trim(),
              'cargo': _cargo.text.trim(),
              'telefono': _telefono.text.trim(),
              'correo': _correo.text.trim(),
              'direccion': _direccion.text.trim(),
              'actividad': _actividad.text.trim(),
              'unidadSolicitada': _unidad.text.trim(),
              'requisitos': _requisitos.text.trim(),
              'observaciones': _observaciones.text.trim(),
              'website': _website.text.trim(),
              'origen': 'apk',
              'vehiculos': vehiculos,
            },
            timeout: const Duration(seconds: 60),
          ));
      if (!mounted) return;
      setState(() => _sending = false);
      final codigo = asString(result['codigo']) ?? 'SOL';
      await _showSuccess(codigo);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  Future<void> _showSuccess(String codigo) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitud enviada',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Su solicitud fue registrada correctamente. El administrador revisará la información y le contactará.',
              style: TextStyle(fontSize: 12.5, height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CÓDIGO DE SOLICITUD',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Color(0xFF7A6220),
                      )),
                  const SizedBox(height: 4),
                  Text(
                    codigo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(_VehiculoRow row, {required bool inicio}) async {
    FocusScope.of(context).unfocus();
    final initial = (inicio ? row.inicio : row.fin) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: inicio ? 'Fecha de inicio' : 'Fecha de fin',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null) return;
    setState(() {
      if (inicio) {
        row.inicio = picked;
      } else {
        row.fin = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar empresa')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(AppColors.gold),
              ),
            )
          : _error != null && _tipos.isEmpty
              ? EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'No se pudo cargar el formulario',
                  message: _error!,
                  onRetry: _loadOpciones,
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.dark,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SOLICITUD DE VEHÍCULOS',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Registre su empresa y pida la flota que necesita.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                height: 1.3,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_nota.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _nota,
                                style: const TextStyle(
                                  color: Color(0xFFB9B5AC),
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_requisitosInfo.isNotEmpty) ...[
                        const SectionTitle('Requisitos'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _requisitosInfo
                                  .map((r) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                                Icons.check_circle_outline_rounded,
                                                size: 14,
                                                color: AppColors.ok),
                                            const SizedBox(width: 7),
                                            Expanded(
                                              child: Text(
                                                r,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  height: 1.35,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                      const SectionTitle('Datos de la empresa'),
                      _field('RUC', _ruc,
                          hint: '11 dígitos',
                          keyboard: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          validator: (v) {
                            final digits =
                                (v ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 11) return 'RUC inválido';
                            return null;
                          }),
                      _field('Razón social', _razonSocial,
                          hint: 'Nombre legal de la empresa',
                          caps: TextCapitalization.words,
                          validator: (v) => (v ?? '').trim().length < 3
                              ? 'Ingrese la razón social'
                              : null),
                      _field('Actividad', _actividad,
                          hint: 'Rubro o actividad principal',
                          caps: TextCapitalization.sentences),
                      _field('Dirección', _direccion,
                          hint: 'Domicilio fiscal',
                          caps: TextCapitalization.sentences),
                      _field('Unidad minera solicitada', _unidad,
                          hint: 'Unidad o sede donde requiere la flota',
                          caps: TextCapitalization.words),
                      const SectionTitle('Persona de contacto'),
                      _field('Contacto', _contacto,
                          hint: 'Nombre y apellidos',
                          caps: TextCapitalization.words,
                          validator: (v) => (v ?? '').trim().length < 3
                              ? 'Ingrese el contacto'
                              : null),
                      _field('Cargo', _cargo, hint: 'Cargo en la empresa',
                          caps: TextCapitalization.words),
                      _field('Teléfono', _telefono,
                          hint: 'Número de contacto',
                          keyboard: TextInputType.phone,
                          validator: (v) {
                            final digits =
                                (v ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 6) return 'Teléfono inválido';
                            return null;
                          }),
                      _field('Correo electrónico', _correo,
                          hint: 'contacto@empresa.com',
                          keyboard: TextInputType.emailAddress,
                          validator: (v) {
                            final text = (v ?? '').trim();
                            final ok = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$')
                                .hasMatch(text);
                            return ok ? null : 'Correo inválido';
                          }),
                      const SectionTitle('Servicio requerido'),
                      _field('Requisitos del servicio', _requisitos,
                          hint:
                              'Describa el servicio, condiciones operativas y requisitos especiales.',
                          maxLines: 4,
                          caps: TextCapitalization.sentences,
                          validator: (v) => (v ?? '').trim().length < 10
                              ? 'Describa el servicio requerido'
                              : null),
                      _field('Observaciones', _observaciones,
                          hint: 'Información adicional (opcional)',
                          maxLines: 2,
                          caps: TextCapitalization.sentences),
                      // Campo trampa: invisible para personas, usado contra bots.
                      SizedBox(
                        height: 0,
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: _website,
                            decoration: const InputDecoration(
                                labelText: 'Sitio web'),
                          ),
                        ),
                      ),
                      SectionTitle(
                        'Vehículos solicitados',
                        trailing: Text(
                          '${_vehiculos.length}/10',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      for (var i = 0; i < _vehiculos.length; i++)
                        _vehiculoCard(i),
                      OutlinedButton.icon(
                        onPressed: _addVehiculo,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Agregar otro vehículo'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bad.withOpacity(.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 17, color: AppColors.bad),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.bad,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _sending ? null : _submit,
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Enviar solicitud'),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'La solicitud no genera un contrato automáticamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    TextCapitalization caps = TextCapitalization.none,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          TextFormField(
            controller: controller,
            keyboardType: keyboard,
            inputFormatters: formatters,
            textCapitalization: caps,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }

  Widget _vehiculoCard(int index) {
    final row = _vehiculos[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.goldSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7A6220),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text('Vehículo',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                if (_vehiculos.length > 1)
                  IconButton(
                    onPressed: () => _removeVehiculo(index),
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    tooltip: 'Quitar',
                    color: AppColors.bad,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _Label('Tipo de vehículo'),
            AppDropdown<int>(
              value: row.tipoId,
              hint: 'Seleccione…',
              items: row.tipos
                  .map((t) => DropdownMenuItem<int>(
                        value: asInt(t['id']),
                        child: Text(asString(t['nombre']) ?? '—',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => row.tipoId = v),
            ),
            const SizedBox(height: 11),
            _Label('Categoría (opcional)'),
            AppDropdown<int>(
              value: row.categoriaId,
              hint: '—',
              items: [
                const DropdownMenuItem<int>(value: 0, child: Text('—')),
                ...row.categorias.map((c) => DropdownMenuItem<int>(
                      value: asInt(c['id']),
                      child: Text(asString(c['nombre']) ?? '—',
                          overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) => setState(
                  () => row.categoriaId = (v == null || v == 0) ? null : v),
            ),
            const SizedBox(height: 11),
            _Label('Cantidad'),
            TextFormField(
              controller: row.cantidad,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: const InputDecoration(hintText: '1'),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Desde'),
                      _dateField(row, inicio: true),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Hasta'),
                      _dateField(row, inicio: false),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              value: row.requiereConductor,
              onChanged: (v) => setState(() => row.requiereConductor = v),
              title: const Text('Requiere conductor',
                  style: TextStyle(fontSize: 12.5)),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 4),
            _Label('Detalles (opcional)'),
            TextFormField(
              controller: row.detalles,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Equipos, turnos, condiciones especiales…',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(_VehiculoRow row, {required bool inicio}) {
    final date = inicio ? row.inicio : row.fin;
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final text = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pickDate(row, inicio: inicio),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_outlined,
                size: 16, color: AppColors.muted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text.isEmpty ? 'Seleccione' : text,
                style: TextStyle(
                  fontSize: 12.5,
                  color: text.isEmpty ? const Color(0xFF9A9EA3) : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehiculoRow {
  final cantidad = TextEditingController(text: '1');
  final detalles = TextEditingController();
  int? tipoId;
  int? categoriaId;
  DateTime? inicio;
  DateTime? fin;
  bool requiereConductor = true;

  List<Map<String, dynamic>> tipos = [];
  List<Map<String, dynamic>> categorias = [];

  void setCatalogos(
    List<Map<String, dynamic>> t,
    List<Map<String, dynamic>> c,
  ) {
    tipos = t;
    categorias = c;
  }

  void dispose() {
    cantidad.dispose();
    detalles.dispose();
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
