import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/location.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'auth.dart';
import 'home.dart' show mechanicCategories;
import 'vehicles.dart';

/// Saves the phone's current position as the mechanic's workshop location.
Future<void> useCurrentLocationForWorkshop(BuildContext context) async {
  final r = await getLocation();
  if (!context.mounted) return;
  if (r.point == null) {
    showMsg(context, r.error ?? 'Could not get your location.', error: true);
    return;
  }
  try {
    final address = ((app.user?['address'] as String?) ?? '').isEmpty ? 'My workshop' : app.user!['address'];
    final res = await app.api.put('/me', body: {
      'lat': r.point!.latitude,
      'lng': r.point!.longitude,
      'address': address,
    });
    await app.updateUser(Map<String, dynamic>.from(res as Map));
    if (context.mounted) showMsg(context, 'Workshop location saved.');
  } on ApiException catch (e) {
    if (context.mounted) showMsg(context, e.message, error: true);
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String get _roleLabel {
    switch (app.role) {
      case 'mechanic':
        return 'Mechanic';
      case 'supplier':
        return 'Parts supplier';
      default:
        return 'Driver';
    }
  }

  Future<void> _edit() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _EditSheet(),
    );
    if (res == null) return;
    try {
      final data = await app.api.put('/me', body: res);
      await app.updateUser(Map<String, dynamic>.from(data as Map));
      if (mounted) {
        setState(() {});
        showMsg(context, 'Profile updated.');
      }
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to use AutoAssist.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await app.logout();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final u = app.user ?? {};
    final name = (u['name'] as String?) ?? '';
    final biz = (u['business_name'] as String?) ?? '';
    final isMech = app.role == 'mechanic';
    final hasLoc = u['lat'] != null;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, pad.top + 14, 20, pad.bottom + 24),
      children: [
        const Text('Profile', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: cardDeco(context, radius: 24),
          child: Row(children: [
            Avatar(name, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (biz.isNotEmpty) Text(biz, style: TextStyle(color: context.muted, fontSize: 13)),
                Text((u['email'] as String?) ?? '', style: TextStyle(color: context.muted, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_roleLabel,
                      style: const TextStyle(color: AppColors.accent, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _group([
          _tile(Icons.edit_rounded, 'Edit profile', onTap: _edit),
          if (app.role == 'driver')
            _tile(Icons.directions_car_rounded, 'My vehicles',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VehiclesScreen()))),
          if (isMech)
            _tile(
              Icons.location_on_rounded,
              'Workshop location',
              subtitle: hasLoc ? 'Set. Tap to update to where you are now.' : 'Not set - drivers cannot find you yet',
              onTap: () async {
                await useCurrentLocationForWorkshop(context);
                if (mounted) setState(() {});
              },
            ),
        ]),
        const SizedBox(height: 14),
        _group([
          _tile(
            context.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            'Dark mode',
            trailing: Switch(
              value: context.isDark,
              activeTrackColor: AppColors.accent,
              onChanged: (v) => app.setDark(v),
            ),
          ),
          _tile(Icons.dns_rounded, 'Server address', subtitle: app.serverUrl, onTap: () async {
            await showServerSheet(context);
            if (mounted) setState(() {});
          }),
          _tile(Icons.info_outline_rounded, 'About AutoAssist', onTap: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('AutoAssist'),
                content: const Text(
                  'AI-enabled roadside assistance and automotive service management prototype.\n\n'
                  'Map data © OpenStreetMap contributors. AI guidance is preliminary and does not replace a '
                  'professional mechanic.',
                ),
                actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
              ),
            );
          }),
        ]),
        const SizedBox(height: 22),
        PillButton(label: 'Log out', outlined: true, icon: Icons.logout_rounded, onTap: _logout),
      ],
    );
  }

  Widget _group(List<Widget> children) {
    final items = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(Divider(height: 1, indent: 62, color: context.line));
      }
    }
    return Container(
      decoration: cardDeco(context, radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Column(children: items),
    );
  }

  Widget _tile(IconData icon, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: context.field, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: context.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (subtitle != null)
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.muted, fontSize: 12.5)),
            ]),
          ),
          trailing ?? (onTap != null ? Icon(Icons.chevron_right_rounded, color: context.muted) : const SizedBox.shrink()),
        ]),
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet();
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _u = app.user ?? {};
  late final _name = TextEditingController(text: (_u['name'] as String?) ?? '');
  late final _phone = TextEditingController(text: (_u['phone'] as String?) ?? '');
  late final _biz = TextEditingController(text: (_u['business_name'] as String?) ?? '');
  late final _address = TextEditingController(text: (_u['address'] as String?) ?? '');
  late final _services = TextEditingController(text: (_u['services'] as String?) ?? '');
  late final _bio = TextEditingController(text: (_u['bio'] as String?) ?? '');
  late final Set<String> _specs = ((_u['specialization'] as String?) ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  bool get _isMech => app.role == 'mechanic';
  bool get _isBiz => app.role != 'driver';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _biz.dispose();
    _address.dispose();
    _services.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().length < 2) {
      showMsg(context, 'Enter your name.', error: true);
      return;
    }
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
    };
    if (_isBiz) {
      body['business_name'] = _biz.text.trim();
      body['address'] = _address.text.trim();
    }
    if (_isMech) {
      body['specialization'] = mechanicCategories.where((c) => _specs.contains(c)).join(',');
      body['services'] = _services.text.trim();
      body['bio'] = _bio.text.trim();
    }
    Navigator.of(context).pop(body);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Edit profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        AppField(controller: _name, hint: 'Full name', icon: Icons.person_outline_rounded),
        const SizedBox(height: 12),
        AppField(controller: _phone, hint: 'Phone number', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
        if (_isBiz) ...[
          const SizedBox(height: 12),
          AppField(controller: _biz, hint: 'Business name', icon: Icons.storefront_outlined),
          const SizedBox(height: 12),
          AppField(controller: _address, hint: 'Area / address (e.g. Ntinda, Kampala)', icon: Icons.location_on_outlined),
        ],
        if (_isMech) ...[
          const SizedBox(height: 18),
          const Text('Specialisation', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in mechanicCategories.where((c) => c != 'All'))
              Tappable(
                onTap: () => setState(() => _specs.contains(c) ? _specs.remove(c) : _specs.add(c)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _specs.contains(c) ? context.ink : context.field,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(c,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _specs.contains(c) ? context.onInk : context.muted,
                      )),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          AppField(controller: _services, hint: 'Services you offer', maxLines: 2),
          const SizedBox(height: 12),
          AppField(controller: _bio, hint: 'About you / your garage', maxLines: 3),
        ],
        const SizedBox(height: 22),
        PillButton(label: 'Save changes', onTap: _save),
      ]),
    );
  }
}
