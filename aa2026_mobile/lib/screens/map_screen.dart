import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/location.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/osm_map.dart';
import 'home.dart' show mechanicCategories;
import 'mechanic_detail.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  List<Map<String, dynamic>> _mechanics = [];
  Map<String, dynamic>? _selected;
  String _category = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (app.location == null) {
      final r = await getLocation();
      if (r.point != null) {
        app.location = r.point;
        if (mounted) {
          setState(() {});
          _moveTo(r.point!);
        }
      }
    }
    await _load();
  }

  void _moveTo(LatLng p) {
    try {
      _map.move(p, 14);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final loc = app.location ?? kampala;
    try {
      final data = await app.api.get('/mechanics', query: {
        'lat': loc.latitude,
        'lng': loc.longitude,
        'category': _category == 'All' ? '' : _category,
      });
      if (!mounted) return;
      setState(() {
        _mechanics = asList(data);
        _selected = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMsg(context, e.message, error: true);
    }
  }

  Future<void> _recenter() async {
    final r = await getLocation();
    if (r.point != null) {
      app.location = r.point;
      if (mounted) setState(() {});
      _moveTo(r.point!);
    } else if (mounted && r.error != null) {
      showMsg(context, r.error!, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final center = app.location ?? kampala;
    final sel = _selected;
    final lift = sel != null ? 112.0 : 4.0;
    return Stack(fit: StackFit.expand, children: [
      OsmMap(
        center: center,
        zoom: 14,
        controller: _map,
        attributionBottom: pad.bottom + lift,
        onMapTap: () => setState(() => _selected = null),
        markers: [
          if (app.location != null) MapMarker(point: app.location!, size: 26, child: userDot()),
          for (final m in _mechanics)
            if (m['lat'] != null && m['lng'] != null)
              MapMarker(
                point: LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
                size: sel != null && sel['id'] == m['id'] ? 54 : 44,
                onTap: () => setState(() => _selected = m),
                child: pinMarker(selected: sel != null && sel['id'] == m['id']),
              ),
        ],
      ),
      Positioned(
        top: pad.top + 12,
        left: 0,
        right: 0,
        child: ChipRow(
          items: mechanicCategories,
          selected: _category,
          onSelected: (c) {
            setState(() => _category = c);
            _load();
          },
        ),
      ),
      if (_loading)
        Positioned(
          top: pad.top + 64,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: context.card, shape: BoxShape.circle),
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent),
              ),
            ),
          ),
        ),
      Positioned(
        right: 16,
        bottom: pad.bottom + (sel != null ? 112 : 12),
        child: RoundIconButton(icon: Icons.my_location_rounded, onTap: _recenter, size: 48),
      ),
      if (sel != null)
        Positioned(
          left: 16,
          right: 16,
          bottom: pad.bottom + 12,
          child: _selectedCard(sel),
        ),
    ]);
  }

  Widget _selectedCard(Map<String, dynamic> m) {
    final rating = (m['rating'] as num?)?.toDouble() ?? 0;
    return Tappable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MechanicDetailScreen(mechanic: m)),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: cardDeco(context, radius: 22),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 68,
              height: 68,
              child: AppImage(name: mechanicPhoto(m['id'] as int), icon: Icons.engineering_rounded),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(displayName(m), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.star_rounded, size: 15, color: AppColors.star),
                const SizedBox(width: 2),
                Text(rating > 0 ? rating.toStringAsFixed(1) : 'New',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Icon(Icons.near_me_rounded, size: 13, color: context.muted),
                const SizedBox(width: 3),
                Text(distText(m['distance_km'] as num?), style: TextStyle(fontSize: 12.5, color: context.muted)),
              ]),
              const SizedBox(height: 3),
              Text((m['specialization'] as String?) ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.muted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: context.muted),
        ]),
      ),
    );
  }
}
