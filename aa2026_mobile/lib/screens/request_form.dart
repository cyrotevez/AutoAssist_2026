import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/location.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/osm_map.dart';
import 'vehicles.dart';

class RequestFormScreen extends StatefulWidget {
  final Map<String, dynamic>? mechanic;
  const RequestFormScreen({super.key, this.mechanic});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  String _problem = 'Flat tyre';
  final _desc = TextEditingController();
  List<Map<String, dynamic>> _vehicles = [];
  int? _vehicleId;
  LatLng? _loc;
  String? _locError;
  bool _locLoading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _getLoc();
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final list = asList(await app.api.get('/vehicles'));
      if (!mounted) return;
      setState(() {
        _vehicles = list;
        final stillThere = list.any((v) => v['id'] == _vehicleId);
        if (!stillThere) _vehicleId = list.isNotEmpty ? list.first['id'] as int : null;
      });
    } on ApiException {
      // Vehicle is optional, so ignore errors here.
    }
  }

  Future<void> _getLoc() async {
    setState(() => _locLoading = true);
    final r = await getLocation();
    if (!mounted) return;
    setState(() {
      if (r.point != null) app.location = r.point;
      _loc = r.point ?? app.location;
      _locError = r.point == null ? r.error : null;
      _locLoading = false;
    });
  }

  Future<void> _submit() async {
    if (_loc == null) {
      showMsg(context, 'We need your location so a mechanic can find you.', error: true);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await app.api.post('/requests', body: {
        'problem': _problem,
        'description': _desc.text.trim(),
        'lat': _loc!.latitude,
        'lng': _loc!.longitude,
        'vehicle_id': _vehicleId,
        'mechanic_id': widget.mechanic?['id'],
      });
      nav.popUntil((r) => r.isFirst);
      shellIndex.value = 2;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Request sent. A mechanic will respond soon.')));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mech = widget.mechanic;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(children: [
              const BackBtn(),
              const SizedBox(width: 14),
              const Text('Request assistance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sendingTo(mech),
                const SizedBox(height: 22),
                const Text('What is the problem?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in problemTypes.entries) _problemChip(e.key, e.value),
                ]),
                const SizedBox(height: 22),
                const Text('Your vehicle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _vehiclePicker(),
                const SizedBox(height: 22),
                const Text('Details (optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                AppField(controller: _desc, hint: 'Describe what happened...', maxLines: 3),
                const SizedBox(height: 22),
                const Text('Your location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _locationCard(),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: PillButton(
              label: 'Send request',
              icon: Icons.send_rounded,
              color: AppColors.accent,
              loading: _busy,
              onTap: _submit,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sendingTo(Map<String, dynamic>? mech) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(context, radius: 18),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: AppColors.accent.withAlpha(30), shape: BoxShape.circle),
          child: Icon(mech == null ? Icons.groups_rounded : Icons.build_rounded, color: AppColors.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mech == null ? 'Nearby mechanics' : displayName(mech),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text(
              mech == null
                  ? 'Your request goes to all available mechanics. The first to accept helps you.'
                  : 'Your request will be sent to this mechanic.',
              style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.35),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _problemChip(String label, IconData icon) {
    final sel = _problem == label;
    return Tappable(
      onTap: () => setState(() => _problem = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: sel ? context.ink : context.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: sel ? context.onInk : context.muted),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: sel ? context.onInk : context.ink)),
        ]),
      ),
    );
  }

  Widget _vehiclePicker() {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final v in _vehicles)
        Tappable(
          onTap: () => setState(() => _vehicleId = v['id'] as int),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _vehicleId == v['id'] ? context.ink : context.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_car_rounded,
                  size: 18, color: _vehicleId == v['id'] ? context.onInk : context.muted),
              const SizedBox(width: 8),
              Text('${v['make']} ${v['model']}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _vehicleId == v['id'] ? context.onInk : context.ink)),
            ]),
          ),
        ),
      Tappable(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VehiclesScreen()));
          _loadVehicles();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.muted.withAlpha(120)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: 18, color: context.muted),
            const SizedBox(width: 6),
            Text('Add vehicle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.muted)),
          ]),
        ),
      ),
    ]);
  }

  Widget _locationCard() {
    return Container(
      decoration: cardDeco(context, radius: 20),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
          height: 170,
          child: _loc != null
              ? IgnorePointer(
                  child: OsmMap(
                    key: ValueKey('${_loc!.latitude},${_loc!.longitude}'),
                    center: _loc!,
                    zoom: 16,
                    markers: [
                      MapMarker(
                        point: _loc!,
                        size: 40,
                        child: pinMarker(selected: true, icon: Icons.warning_amber_rounded),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: _locLoading
                      ? const CircularProgressIndicator(color: AppColors.accent)
                      : Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(_locError ?? 'Location unavailable.',
                              textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
                        ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(children: [
            Icon(Icons.location_on_rounded, size: 18, color: _loc != null ? AppColors.ok : context.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _loc != null
                    ? 'Location found${_locError != null ? ' (last known)' : ''}'
                    : (_locLoading ? 'Finding your location...' : 'Location not available'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _locLoading ? null : _getLoc,
              child: const Text('Refresh', style: TextStyle(color: AppColors.accent)),
            ),
          ]),
        ),
      ]),
    );
  }
}
