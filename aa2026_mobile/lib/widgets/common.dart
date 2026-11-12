import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';

// ------------------------------------------------------------------ constants
const Map<String, IconData> problemTypes = {
  'Flat tyre': Icons.tire_repair_rounded,
  'Dead battery': Icons.battery_alert_rounded,
  'Engine trouble': Icons.engineering_rounded,
  'Overheating': Icons.thermostat_rounded,
  'Out of fuel': Icons.local_gas_station_rounded,
  'Towing needed': Icons.local_shipping_rounded,
  'Brake problem': Icons.car_repair_rounded,
  'Other': Icons.build_rounded,
};

IconData problemIcon(String p) => problemTypes[p] ?? Icons.build_rounded;

String statusLabel(String s) {
  switch (s) {
    case 'pending':
      return 'Waiting';
    case 'accepted':
      return 'Accepted';
    case 'en_route':
      return 'On the way';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return s;
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'pending':
      return AppColors.star;
    case 'accepted':
      return AppColors.info;
    case 'en_route':
      return AppColors.accent;
    case 'completed':
      return AppColors.ok;
    default:
      return const Color(0xFF8A8A92);
  }
}

// ------------------------------------------------------------------ helpers
String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String ugx(num n) =>
    'UGX ${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

String timeAgo(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return '${d.day}/${d.month}/${d.year}';
}

String hhmm(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String displayName(Map<String, dynamic> m) {
  final b = (m['business_name'] as String?) ?? '';
  return b.isNotEmpty ? b : ((m['name'] as String?) ?? '');
}

String mechanicPhoto(int id) => 'mechanic_${(id % 7) + 1}';

String distText(num? d) {
  if (d == null) return '';
  if (d < 1) return '${(d * 1000).round()} m';
  return '${d.toStringAsFixed(1)} km';
}

/// Removes markdown symbols from plain-text messages.
/// (No longer used for AI replies, which are now rendered as markdown.)
String cleanAi(String s) {
  return s
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('`', '')
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
      .trim();
}

void showMsg(BuildContext context, String text, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: error ? AppColors.danger : AppColors.ok, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ]),
  ));
}

Future<void> callNumber(BuildContext context, String? phone) async {
  if (phone == null || phone.trim().isEmpty) {
    showMsg(context, 'No phone number available.', error: true);
    return;
  }
  try {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone.trim()));
    if (!ok && context.mounted)
      showMsg(context, 'Could not open the phone app.', error: true);
  } catch (_) {
    if (context.mounted)
      showMsg(context, 'Could not open the phone app.', error: true);
  }
}

Future<void> openDirections(
    BuildContext context, double lat, double lng) async {
  try {
    final ok = await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted)
      showMsg(context, 'Could not open maps.', error: true);
  } catch (_) {
    if (context.mounted) showMsg(context, 'Could not open maps.', error: true);
  }
}

// ------------------------------------------------------------------ widgets
class Tappable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Tappable(
      {super.key, required this.child, this.onTap, this.scale = 0.97});

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _down = false;

  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        child: widget.child,
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outlined;
  final IconData? icon;
  final Color? color;
  const PillButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.outlined = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fill = color ?? context.ink;
    final fg = color != null ? Colors.white : context.onInk;
    final enabled = onTap != null && !loading;
    final textColor = outlined ? context.ink : fg;
    return Tappable(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: outlined
              ? Colors.transparent
              : (enabled || loading ? fill : fill.withAlpha(110)),
          borderRadius: BorderRadius.circular(30),
          border:
              outlined ? Border.all(color: context.muted.withAlpha(120)) : null,
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: textColor),
              )
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: textColor),
                  const SizedBox(width: 8)
                ],
                Text(label,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ]),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? bg;
  final Color? fg;
  final double size;
  const RoundIconButton(
      {super.key,
      required this.icon,
      this.onTap,
      this.bg,
      this.fg,
      this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg ?? context.card,
          shape: BoxShape.circle,
          boxShadow: context.isDark || bg != null
              ? null
              : [
                  BoxShadow(
                      color: Colors.black.withAlpha(16),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
        ),
        child: Icon(icon, size: 20, color: fg ?? context.ink),
      ),
    );
  }
}

class BackBtn extends StatelessWidget {
  const BackBtn({super.key});
  @override
  Widget build(BuildContext context) => RoundIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: () => Navigator.of(context).maybePop(),
      );
}

class AppField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboard;
  final int maxLines;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? action;
  const AppField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.keyboard,
    this.maxLines = 1,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLines: obscure ? 1 : maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: action,
      style: TextStyle(color: context.ink, fontSize: 15),
      cursorColor: AppColors.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.muted),
        prefixIcon:
            icon == null ? null : Icon(icon, color: context.muted, size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: context.field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
      ),
    );
  }
}

class ChipRow extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsets padding;
  const ChipRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final sel = items[i] == selected;
          return Tappable(
            onTap: () => onSelected(items[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? context.ink : context.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                items[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sel ? context.onInk : context.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: c.withAlpha(36), borderRadius: BorderRadius.circular(12)),
      child: Text(statusLabel(status),
          style:
              TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;
  const Skeleton({super.key, this.width, this.height, this.radius = 16});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: 0.45 + 0.55 * _c.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
              color: context.field,
              borderRadius: BorderRadius.circular(widget.radius)),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration:
                BoxDecoration(color: context.field, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: context.muted),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.muted, height: 1.4)),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            SizedBox(
                width: 190,
                child: PillButton(label: actionLabel!, onTap: onAction)),
          ],
        ]),
      ),
    );
  }
}

class PulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  const PulseIcon({super.key, required this.icon, required this.color});

  @override
  State<PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(alignment: Alignment.center, children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Transform.scale(
            scale: 0.75 + _c.value * 0.6,
            child: Opacity(
              opacity: 1 - _c.value,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: Colors.white.withAlpha(90), shape: BoxShape.circle),
              ),
            ),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(widget.icon, color: widget.color, size: 24),
        ),
      ]),
    );
  }
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_c.value - i * 0.18) % 1.0;
          final o = 0.25 + 0.75 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
                color: context.muted.withAlpha((o * 255).round()),
                shape: BoxShape.circle),
          );
        }),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: context.ink, shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: TextStyle(
            color: context.onInk,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const StarRow(this.rating, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: AppColors.star,
        ),
      ),
    );
  }
}

class AppImage extends StatelessWidget {
  final String name;
  final IconData icon;
  const AppImage(
      {super.key,
      required this.name,
      this.icon = Icons.directions_car_rounded});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/$name.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF45454D), Color(0xFF1C1C20)],
          ),
        ),
        child: Center(child: Icon(icon, size: 44, color: Colors.white24)),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final String? time;

  /// When true, [text] is rendered as Markdown (bold, bullets, numbered lists).
  /// Used for AI assistant replies.
  final bool markdown;

  const ChatBubble({
    super.key,
    required this.text,
    required this.mine,
    this.time,
    this.markdown = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = mine ? context.onInk : context.ink;
    final baseStyle = TextStyle(color: fg, fontSize: 15, height: 1.4);

    final Widget content = markdown
        ? MarkdownBody(
            data: text,
            styleSheet: MarkdownStyleSheet(
              p: baseStyle,
              strong: baseStyle.copyWith(fontWeight: FontWeight.w800),
              em: baseStyle.copyWith(fontStyle: FontStyle.italic),
              listBullet: baseStyle,
              listIndent: 18,
              blockSpacing: 10,
              pPadding: EdgeInsets.zero,
            ),
          )
        : Text(text, style: TextStyle(color: fg, fontSize: 15, height: 1.35));

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
            bottom: 8, left: mine ? 56 : 0, right: mine ? 0 : 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? context.ink : context.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: content,
            ),
            if (time != null && time!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(time!,
                    style: TextStyle(fontSize: 10.5, color: fg.withAlpha(150))),
              ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Text(text,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
      if (trailing != null) trailing!,
    ]);
  }
}