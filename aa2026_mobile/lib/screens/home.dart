import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/location.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mechanic_card.dart';
import 'ai_chat.dart';
import 'parts.dart';
import 'request_form.dart';
import 'vehicles.dart';

const mechanicCategories = ['All', 'Towing', 'Battery', 'Tyres', 'Engine', 'Electrical', 'Brakes'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _mechanics = [];
  bool _loading = true;
  String? _error;
  String _category = 'All';
  String _locLabel = 'Locating...';
  bool _locOn = true;

  @override
  void initState() {
    super.initState();
    _load(silent: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refreshLoc = false, bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    if (app.location == null || refreshLoc) {
      final r = await getLocation();
      if (r.point != null) app.location = r.point;
      if (!mounted) return;
      setState(() {
        _locOn = r.point != null || app.location != null;
        _locLabel = _locOn ? 'Near you' : 'Location off';
      });
    } else {
      _locOn = true;
      _locLabel = 'Near you';
    }
    final loc = app.location ?? kampala;
    try {
      final data = await app.api.get('/mechanics', query: {
        'lat': loc.latitude,
        'lng': loc.longitude,
        'q': _search.text.trim(),
        'category': _category == 'All' ? '' : _category,
      });
      if (!mounted) return;
      setState(() {
        _mechanics = asList(data);
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Stack(children: [
      RefreshIndicator(
        color: AppColors.accent,
        edgeOffset: pad.top,
        onRefresh: () => _load(refreshLoc: true, silent: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, pad.top + 12, 20, 0),
                child: _header(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 6),
                child: ChipRow(
                  items: mechanicCategories,
                  selected: _category,
                  onSelected: (c) {
                    setState(() => _category = c);
                    _load();
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: SectionTitle(
                  'Nearby mechanics',
                  trailing: Text(_loading ? '' : '${_mechanics.length} found',
                      style: TextStyle(color: context.muted, fontSize: 13)),
                ),
              ),
            ),
            if (_loading)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, pad.bottom + 80),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate((context, i) => const Skeleton(radius: 24), childCount: 4),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load mechanics',
                    subtitle: _error!,
                    actionLabel: 'Try again',
                    onAction: _load,
                  ),
                ),
              )
            else if (_mechanics.isEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No mechanics found',
                    subtitle: 'Try another category or search term.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, pad.bottom + 80),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => MechanicCard(m: _mechanics[i]),
                    childCount: _mechanics.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      Positioned(
        right: 20,
        bottom: pad.bottom + 12,
        child: Tappable(
          onTap: () => _push(const AiChatScreen()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.ink,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.smart_toy_rounded, color: context.onInk, size: 20),
              const SizedBox(width: 8),
              Text('Ask AI', style: TextStyle(color: context.onInk, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _header(BuildContext context) {
    final fullName = (app.user?['name'] as String?) ?? '';
    final first = fullName.split(' ').first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Tappable(
          onTap: () => _load(refreshLoc: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: context.ink, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_locOn ? Icons.location_on_rounded : Icons.location_off_rounded, size: 15, color: context.onInk),
              const SizedBox(width: 4),
              Text(_locLabel, style: TextStyle(color: context.onInk, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const Spacer(),
        RoundIconButton(icon: Icons.notifications_none_rounded, onTap: () => shellIndex.value = 2),
        const SizedBox(width: 12),
        Tappable(onTap: () => shellIndex.value = 3, child: Avatar(fullName, size: 44)),
      ]),
      const SizedBox(height: 20),
      Text('Hi $first,', style: TextStyle(color: context.muted, fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      const Text('Need help on\nthe road?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15)),
      const SizedBox(height: 18),
      Tappable(
        onTap: () => _push(const RequestFormScreen()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            const PulseIcon(icon: Icons.warning_amber_rounded, color: AppColors.accent),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Broken down?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Request roadside help in seconds',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ]),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      AppField(
        controller: _search,
        hint: 'Search mechanics or services...',
        icon: Icons.search_rounded,
        suffix: Icon(Icons.tune_rounded, color: context.muted, size: 21),
        action: TextInputAction.search,
        onChanged: (_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 450), () => _load());
        },
        onSubmitted: (_) => _load(),
      ),
      const SizedBox(height: 14),
      Row(children: [
        _tile(Icons.inventory_2_rounded, 'Spare parts', () => _push(const PartsScreen())),
        const SizedBox(width: 10),
        _tile(Icons.smart_toy_rounded, 'AI assistant', () => _push(const AiChatScreen())),
        const SizedBox(width: 10),
        _tile(Icons.directions_car_rounded, 'My vehicles', () => _push(const VehiclesScreen())),
      ]),
    ]);
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Tappable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: cardDeco(context, radius: 18),
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.accent.withAlpha(30), shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: AppColors.accent),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
