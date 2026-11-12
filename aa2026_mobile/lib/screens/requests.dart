import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'profile.dart';
import 'request_detail.dart';
import 'request_form.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  bool get _isMech => app.role == 'mechanic';

  @override
  void initState() {
    super.initState();
    _load(silent: true);
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await app.api.get('/requests');
      if (!mounted) return;
      setState(() {
        _items = asList(data);
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _items.isEmpty) _error = e.message;
      });
    }
  }

  Future<void> _toggleAvailable(bool v) async {
    try {
      final res = await app.api.put('/me', body: {'available': v});
      await app.updateUser(Map<String, dynamic>.from(res as Map));
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  Future<void> _open(Map<String, dynamic> r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: r['id'] as int)),
    );
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final available = app.user?['available'] == true;
    final noLocation = _isMech && app.user?['lat'] == null;
    return RefreshIndicator(
      color: AppColors.accent,
      edgeOffset: pad.top,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, pad.top + 14, 20, pad.bottom + 24),
        children: [
          Row(children: [
            Expanded(
              child: Text(_isMech ? 'Jobs' : 'My requests',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            ),
            if (!_isMech)
              Tappable(
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestFormScreen()));
                  _load(silent: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 4),
                    Text('New', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          if (_isMech) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: cardDeco(context, radius: 18),
              child: Row(children: [
                Icon(Icons.circle, size: 12, color: available ? AppColors.ok : AppColors.star),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(available ? 'You are available for jobs' : 'You are set as busy',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(value: available, activeTrackColor: AppColors.accent, onChanged: _toggleAvailable),
              ]),
            ),
            const SizedBox(height: 12),
            if (noLocation)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(28),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Set your workshop location',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Drivers can only find you on the map after you set where you work.',
                      style: TextStyle(color: context.muted, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 220,
                    child: PillButton(
                      label: 'Use my current location',
                      color: AppColors.accent,
                      onTap: () async {
                        await useCurrentLocationForWorkshop(context);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ]),
              ),
          ],
          if (_loading)
            const Column(children: [
              Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 84, radius: 20)),
              Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 84, radius: 20)),
              Padding(padding: EdgeInsets.only(bottom: 12), child: Skeleton(height: 84, radius: 20)),
            ])
          else if (_error != null && _items.isEmpty)
            SizedBox(
              height: 320,
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load requests',
                subtitle: _error!,
                actionLabel: 'Try again',
                onAction: _load,
              ),
            )
          else if (_items.isEmpty)
            SizedBox(
              height: 320,
              child: EmptyState(
                icon: Icons.assignment_outlined,
                title: _isMech ? 'No jobs yet' : 'No requests yet',
                subtitle: _isMech
                    ? 'New requests from drivers will appear here.'
                    : 'When you request roadside help it will show up here.',
              ),
            )
          else
            for (final r in _items) _card(r),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final problem = (r['problem'] as String?) ?? 'Other';
    final status = (r['status'] as String?) ?? 'pending';
    final driver = r['driver'] as Map?;
    final mech = r['mechanic'] as Map?;
    String subtitle;
    if (_isMech) {
      subtitle = [
        driver?['name'] as String? ?? 'Driver',
        (r['vehicle'] as String?) ?? '',
      ].where((e) => e.isNotEmpty).join(' • ');
    } else if (mech != null) {
      subtitle = displayName(Map<String, dynamic>.from(mech));
    } else {
      subtitle = 'Waiting for a mechanic';
    }
    final extra = [
      timeAgo(r['created_at'] as String?),
      if (_isMech && r['distance_km'] != null) '${distText(r['distance_km'] as num?)} away',
    ].where((e) => e.isNotEmpty).join(' • ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tappable(
        onTap: () => _open(r),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: cardDeco(context, radius: 20),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: statusColor(status).withAlpha(34), shape: BoxShape.circle),
              child: Icon(problemIcon(problem), color: statusColor(status), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(problem, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.muted, fontSize: 13)),
                const SizedBox(height: 2),
                Text(extra, style: TextStyle(color: context.muted, fontSize: 12)),
              ]),
            ),
            const SizedBox(width: 8),
            StatusBadge(status),
          ]),
        ),
      ),
    );
  }
}
