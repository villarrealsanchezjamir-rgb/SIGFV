import 'package:flutter/material.dart';

import '../theme.dart';

const _months = [
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

String fmtValue(dynamic value) {
  if (value == null || value == '') return '—';
  final s = value.toString();
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
    final date = DateTime.tryParse(s);
    if (date != null) {
      return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
    }
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}').hasMatch(s)) {
    final date = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (date != null) {
      return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} · '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
  return s;
}

String fmtNum(dynamic value) {
  if (value == null || value == '') return '—';
  final number = value is num ? value : num.tryParse(value.toString());
  if (number == null) return value.toString();
  final negative = number < 0;
  final fixed = number.abs() % 1 == 0
      ? number.abs().toStringAsFixed(0)
      : number.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final decimals = parts.length > 1 ? ',${parts[1]}' : '';
  return '${negative ? '-' : ''}$buffer$decimals';
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0]).join().toUpperCase();
}

Color badgeColor(dynamic value) {
  final key = value?.toString().toLowerCase() ?? '';
  const map = {
    'conforme': AppColors.ok,
    'activo': AppColors.ok,
    'vigente': AppColors.ok,
    'completado': AppColors.ok,
    'cerrado': AppColors.ok,
    'finalizada': AppColors.ok,
    'cumplida': AppColors.ok,
    'operativo': AppColors.ok,
    'no_conforme': AppColors.bad,
    'vencido': AppColors.bad,
    'inhabilitado': AppColors.bad,
    'inactivo': AppColors.bad,
    'cancelada': AppColors.bad,
    'cancelado': AppColors.bad,
    'pendiente': AppColors.bad,
    'por vencer': AppColors.warn,
    'en_proceso': AppColors.warn,
    'en_investigacion': AppColors.warn,
    'en mantenimiento': AppColors.warn,
    'programado': AppColors.info,
    'programada': AppColors.info,
    'activa': AppColors.info,
    'alquilado': AppColors.info,
    'en_curso': AppColors.info,
    'fuera de servicio': AppColors.bad,
    'de baja': const Color(0xFF42464B),
  };
  return map[key] ?? const Color(0xFF42464B);
}

class StatusBadge extends StatelessWidget {
  final String value;
  const StatusBadge(this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = badgeColor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            value.replaceAll('_', ' '),
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .1,
            ),
          ),
        ],
      ),
    );
  }
}

IconData iconFor(String? name) {
  switch ((name ?? '').toLowerCase()) {
    case 'truck':
      return Icons.local_shipping_outlined;
    case 'id-card':
      return Icons.badge_outlined;
    case 'calendar':
    case 'calendar-range':
      return Icons.date_range_outlined;
    case 'wrench':
      return Icons.build_outlined;
    case 'clipboard':
      return Icons.assignment_outlined;
    case 'clipboard-check':
      return Icons.assignment_turned_in_outlined;
    case 'file':
    case 'file-text':
      return Icons.description_outlined;
    case 'fuel':
      return Icons.local_gas_station_outlined;
    case 'shield':
      return Icons.shield_outlined;
    case 'alert':
      return Icons.warning_amber_rounded;
    case 'settings':
      return Icons.settings_outlined;
    case 'key':
      return Icons.vpn_key_outlined;
    case 'building':
      return Icons.apartment_outlined;
    case 'user':
      return Icons.person_outline;
    case 'home':
      return Icons.home_outlined;
    case 'grid':
      return Icons.grid_view_rounded;
    case 'bell':
      return Icons.notifications_none_rounded;
    case 'gauge':
      return Icons.speed_outlined;
    case 'wifi':
      return Icons.wifi_rounded;
    case 'refresh':
      return Icons.refresh_rounded;
    case 'download':
      return Icons.download_outlined;
    case 'logout':
      return Icons.logout_rounded;
    case 'plus':
      return Icons.add_rounded;
    case 'search':
      return Icons.search_rounded;
    case 'chevron':
      return Icons.chevron_right_rounded;
    case 'check':
      return Icons.check_rounded;
    case 'x':
      return Icons.close_rounded;
    case 'trash':
      return Icons.delete_outline_rounded;
    case 'info':
      return Icons.info_outline_rounded;
    default:
      return Icons.inventory_2_outlined;
  }
}

void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: error ? AppColors.bad : AppColors.dark,
      duration: const Duration(seconds: 3),
    ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Continuar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor:
                destructive ? AppColors.bad : AppColors.dark,
            minimumSize: const Size(0, 42),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inventory_2_outlined,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: const Color(0xFFB9B5AC)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: Icon(icon, size: 18, color: AppColors.muted),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  const AppDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF5F4F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF9A9EA3))),
          icon: const Icon(Icons.expand_more_rounded, size: 20),
          borderRadius: BorderRadius.circular(12),
          items: items,
          onChanged: enabled ? onChanged : null,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged?.call('');
                },
              ),
      ),
    );
  }
}
