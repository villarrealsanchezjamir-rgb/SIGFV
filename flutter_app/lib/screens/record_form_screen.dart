import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class RecordFormScreen extends StatefulWidget {
  final String resourceKey;
  final int? id;

  const RecordFormScreen({super.key, required this.resourceKey, this.id});

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _selections = {};
  final Map<String, DateTime?> _dates = {};
  final Map<String, List<Map<String, dynamic>>> _catalogs = {};

  Map<String, dynamic> _item = {};
  ResourceDef? _resource;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _formError;

  bool get _isNew => widget.id == null || (widget.id ?? 0) <= 0;
  bool get _editable {
    final r = _resource;
    if (r == null) return false;
    return _isNew ? r.crear : r.editar;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final app = context.read<AppState>();
    final r = app.resource(widget.resourceKey);
    if (r == null) {
      setState(() {
        _error = 'Módulo no disponible.';
        _loading = false;
      });
      return;
    }
    _resource = r;

    try {
      final catalogNames = <String>{};
      for (final f in r.fields) {
        if (f.catalog != null) catalogNames.add(f.catalog!);
      }
      for (final name in catalogNames) {
        _catalogs[name] = await app.catalog(name);
      }

      if (!_isNew) {
        _item = await app.fetchRecord(widget.resourceKey, widget.id!);
      }

      for (final f in r.fields) {
        final raw = _item[f.name];
        if (f.type == 'date' || f.type == 'datetime') {
          final date = _parseDate(raw);
          _dates[f.name] = date;
          _controllers[f.name] = TextEditingController(
            text: date == null
                ? ''
                : (f.type == 'datetime'
                    ? '${_dateLabel(date)} · ${_timeLabel(date)}'
                    : _dateLabel(date)),
          );
        } else if (f.type == 'select') {
          _selections[f.name] = raw?.toString() ?? '';
        } else {
          _controllers[f.name] =
              TextEditingController(text: raw?.toString() ?? '');
        }
      }

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

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }

  static const _months = [
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

  String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  String _timeLabel(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _dateForBody(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dateTimeForBody(DateTime d) =>
      '${_dateForBody(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(FieldDef f) async {
    FocusScope.of(context).unfocus();
    final initial = _dates[f.name] ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: f.label,
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null) return;

    var value = picked;
    if (f.type == 'datetime') {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dates[f.name] ?? DateTime.now()),
        helpText: f.label,
        cancelText: 'Cancelar',
        confirmText: 'Aceptar',
      );
      if (time != null) {
        value = DateTime(
            picked.year, picked.month, picked.day, time.hour, time.minute);
      }
    }
    setState(() {
      _dates[f.name] = value;
      _controllers[f.name]?.text = f.type == 'datetime'
          ? '${_dateLabel(value)} · ${_timeLabel(value)}'
          : _dateLabel(value);
    });
  }

  void _clearDate(FieldDef f) {
    setState(() {
      _dates[f.name] = null;
      _controllers[f.name]?.clear();
    });
  }

  List<DropdownMenuItem<String>> _itemsFor(FieldDef f) {
    final entries = <MapEntry<String, String>>[];
    if (f.catalog != null) {
      for (final row in _catalogs[f.catalog] ?? const <Map<String, dynamic>>[]) {
        entries.add(MapEntry(
          row['id'].toString(),
          (row['nombre'] ?? row['razon_social'] ?? row['id']).toString(),
        ));
      }
    } else {
      for (final option in f.options) {
        entries.add(MapEntry(option.value, option.label));
      }
    }
    final current = _selections[f.name];
    if (current != null &&
        current.isNotEmpty &&
        !entries.any((e) => e.key == current)) {
      entries.insert(0, MapEntry(current, current));
    }

    return [
      if (!f.required)
        const DropdownMenuItem<String>(value: '', child: Text('—')),
      ...entries.map((e) => DropdownMenuItem<String>(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          )),
    ];
  }

  Map<String, dynamic>? _buildBody() {
    final r = _resource;
    if (r == null) return null;
    _formError = null;

    for (final f in r.fields) {
      if (!f.required) continue;
      if (f.type == 'select') {
        if ((_selections[f.name] ?? '').isEmpty) {
          _formError = '${f.label} es obligatorio.';
          return null;
        }
      } else if (f.type == 'date' || f.type == 'datetime') {
        if (_dates[f.name] == null) {
          _formError = '${f.label} es obligatorio.';
          return null;
        }
      } else if (f.type != 'password') {
        if ((_controllers[f.name]?.text ?? '').trim().isEmpty) {
          _formError = '${f.label} es obligatorio.';
          return null;
        }
      }
    }

    final body = <String, dynamic>{};
    for (final f in r.fields) {
      if (f.type == 'select') {
        body[f.name] = _selections[f.name] ?? '';
      } else if (f.type == 'date') {
        final date = _dates[f.name];
        body[f.name] = date == null ? '' : _dateForBody(date);
      } else if (f.type == 'datetime') {
        final date = _dates[f.name];
        body[f.name] = date == null ? '' : _dateTimeForBody(date);
      } else if (f.type == 'password') {
        final text = _controllers[f.name]?.text ?? '';
        if (!_isNew && text.isEmpty) continue;
        body[f.name] = text;
      } else {
        body[f.name] = (_controllers[f.name]?.text ?? '').trim();
      }
    }
    return body;
  }

  Future<void> _save() async {
    if (!_editable) return;
    final body = _buildBody();
    if (body == null) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().saveRecord(
            widget.resourceKey,
            _isNew ? null : widget.id,
            body,
          );
      if (!mounted) return;
      showToast(context, _isNew ? 'Registro creado.' : 'Cambios guardados.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, e.toString(), error: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final r = _resource;
    if (r == null || widget.id == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Eliminar registro',
      message:
          'El registro se dará de baja y dejará de aparecer en los listados. ¿Desea continuar?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().deleteRecord(widget.resourceKey, widget.id!);
      if (!mounted) return;
      showToast(context, 'Registro eliminado.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, e.toString(), error: true);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resource;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Registrar' : 'Editar'),
        bottom: r == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(18),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      r.label,
                      style: const TextStyle(
                          color: Color(0xFFB9B5AC), fontSize: 11),
                    ),
                  ),
                ),
              ),
      ),
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
                  title: 'No se pudo abrir el formulario',
                  message: _error!,
                  onRetry: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _init();
                  },
                )
              : _buildForm(r!),
      bottomNavigationBar: _loading || _error != null || r == null
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
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(_editable ? 'Cancelar' : 'Volver'),
                      ),
                    ),
                    if (_editable) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(_isNew ? 'Registrar' : 'Guardar'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildForm(ResourceDef r) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (!_editable)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 17, color: AppColors.info),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Su rol permite consultar este módulo, pero no modificarlo.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        if (_formError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.bad.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formError!,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.bad,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ...r.fields.map(_buildField),
        if (!_isNew && r.eliminar && _editable) ...[
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Eliminar registro',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'El registro se dará de baja y dejará de aparecer en los listados.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text('Eliminar ${r.label.toLowerCase()}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bad,
                      side: const BorderSide(color: AppColors.bad),
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

  Widget _buildField(FieldDef f) {
    final controller = _controllers[f.name];
    final enabled = _editable;

    Widget input;
    if (f.type == 'select') {
      input = AppDropdown<String>(
        value: (_selections[f.name]?.isEmpty ?? true) ? null : _selections[f.name],
        hint: f.required ? 'Seleccione…' : '—',
        items: _itemsFor(f),
        enabled: enabled,
        onChanged: (value) => setState(() => _selections[f.name] = value ?? ''),
      );
    } else if (f.type == 'date' || f.type == 'datetime') {
      input = TextField(
        controller: controller,
        readOnly: true,
        enabled: enabled,
        onTap: enabled ? () => _pickDate(f) : null,
        decoration: InputDecoration(
          hintText: f.type == 'datetime'
              ? 'Seleccione fecha y hora'
              : 'Seleccione fecha',
          suffixIcon: enabled
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dates[f.name] != null && !f.required)
                      IconButton(
                        onPressed: () => _clearDate(f),
                        icon: const Icon(Icons.close_rounded, size: 17),
                        tooltip: 'Limpiar',
                      ),
                    IconButton(
                      onPressed: () => _pickDate(f),
                      icon: const Icon(Icons.event_outlined, size: 19),
                    ),
                  ],
                )
              : null,
        ),
      );
    } else if (f.type == 'textarea') {
      input = TextField(
        controller: controller,
        enabled: enabled,
        maxLines: 3,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: f.label),
      );
    } else if (f.type == 'password') {
      input = TextField(
        controller: controller,
        enabled: enabled,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          hintText: f.label,
          helperText: !_isNew
              ? 'Deje en blanco para conservar la contraseña actual.'
              : 'Mínimo 8 caracteres.',
          helperStyle: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      );
    } else if (f.type == 'number') {
      input = TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*[.,]?\d*$')),
        ],
        decoration: InputDecoration(hintText: f.label),
      );
    } else {
      input = TextField(
        controller: controller,
        enabled: enabled,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: f.label),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
                children: [
                  TextSpan(text: f.label),
                  if (f.required)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.bad),
                    ),
                ],
              ),
            ),
          ),
          input,
        ],
      ),
    );
  }
}
