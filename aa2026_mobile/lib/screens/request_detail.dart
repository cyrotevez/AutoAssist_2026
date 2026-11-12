import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/osm_map.dart';
import 'chat.dart';
import 'mechanic_detail.dart';

class RequestDetailScreen extends StatefulWidget {
  final int requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  Map<String, dynamic>? _r;
  String? _error;
  bool _busy = false;
  Timer? _timer;

  bool get _isMech => app.role == 'mechanic';

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final data = await app.api.get('/requests/${widget.requestId}');
      if (!mounted) return;
      setState(() {
        _r = Map<String, dynamic>.from(data as Map);
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (!silent || _r == null) setState(() => _error = e.message);
    }
  }

  Future<void> _status(String status, String doneText) async {
    setState(() => _busy = true);
    try {
      final res = await app.api.patch('/requests/${widget.requestId}/status', body: {'status': status});
      if (!mounted) return;
      setState(() => _r = Map<String, dynamic>.from(res as Map));
      showMsg(context, doneText);
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text('The mechanic will be told that you no longer need help.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep it')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel request', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await _status('cancelled', 'Request cancelled.');
  }

  Future<void> _rate(int mechanicId) async {
    final res = await showReviewSheet(context);
    if (res == null) return;
    try {
      await app.api.post('/mechanics/$mechanicId/reviews', body: res);
      if (mounted) showMsg(context, 'Thanks for your review!');
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  void _openChat(Map<String, dynamic> r, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(requestId: r['id'] as int, title: title),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(children: [
              const BackBtn(),
              const SizedBox(width: 14),
              Expanded(
                child: Text(r == null ? 'Request' : 'Request #${r['id']}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              if (r != null) StatusBadge(r['status'] as String),
            ]),
          ),
          Expanded(
            child: r == null
                ? (_error != null
                    ? EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load request',
                        subtitle: _error!,
                        actionLabel: 'Try again',
                        onAction: _load,
                      )
                    : const Center(child: CircularProgressIndicator(color: AppColors.accent)))
                : _body(r),
          ),
          if (r != null) _actions(r),
        ]),
      ),
    );
  }

  Widget _body(Map<String, dynamic> r) {
    final status = r['status'] as String;
    final problem = (r['problem'] as String?) ?? 'Other';
    final desc = (r['description'] as String?) ?? '';
    final mech = r['mechanic'] == null ? null : Map<String, dynamic>.from(r['mechanic'] as Map);
    final driver = r['driver'] == null ? null : Map<String, dynamic>.from(r['driver'] as Map);
    final approx = r['approximate'] == true;
    final help = LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble());
    final canChat = mech != null && status != 'cancelled';

    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
      if (status != 'cancelled') ...[
        Container(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 14),
          decoration: cardDeco(context),
          child: _timeline(status),
        ),
        const SizedBox(height: 14),
      ],
      Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.accent.withAlpha(30), shape: BoxShape.circle),
              child: Icon(problemIcon(problem), color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(problem, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text(timeAgo(r['created_at'] as String?), style: TextStyle(color: context.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(desc, style: TextStyle(color: context.muted, height: 1.4)),
          ],
          if (r['vehicle'] != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.directions_car_rounded, size: 18, color: context.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(r['vehicle'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      if (_isMech && driver != null)
        _personCard(
          title: 'Driver',
          name: driver['name'] as String? ?? 'Driver',
          subtitle: approx ? 'Phone and exact location unlock after you accept' : (driver['phone'] as String? ?? ''),
          phone: driver['phone'] as String?,
          onChat: canChat ? () => _openChat(r, driver['name'] as String? ?? 'Driver') : null,
        )
      else if (!_isMech && mech != null)
        _personCard(
          title: 'Your mechanic',
          name: displayName(mech),
          subtitle: mech['name'] as String? ?? '',
          phone: mech['phone'] as String?,
          onChat: canChat ? () => _openChat(r, displayName(mech)) : null,
        )
      else if (!_isMech)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(context),
          child: Row(children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(status == 'cancelled' ? 'This request was cancelled.' : 'Waiting for a mechanic to accept...',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      const SizedBox(height: 14),
      Container(
        decoration: cardDeco(context),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          SizedBox(
            height: 210,
            child: IgnorePointer(
              child: OsmMap(
                key: ValueKey('${help.latitude},${help.longitude}'),
                center: help,
                zoom: approx ? 13 : 15,
                markers: [
                  MapMarker(
                    point: help,
                    size: 44,
                    child: pinMarker(selected: true, icon: Icons.warning_amber_rounded),
                  ),
                  if (mech != null && mech['lat'] != null && mech['lng'] != null && !_isMech)
                    MapMarker(
                      point: LatLng((mech['lat'] as num).toDouble(), (mech['lng'] as num).toDouble()),
                      size: 40,
                      child: pinMarker(color: AppColors.info),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.location_on_rounded, size: 18, color: context.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  approx
                      ? 'Approximate area. Exact spot unlocks after you accept.'
                      : (_isMech ? 'Driver location' : 'Your location'),
                  style: TextStyle(color: context.muted, fontSize: 13),
                ),
              ),
              if (r['distance_km'] != null)
                Text('${distText(r['distance_km'] as num?)} away',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _timeline(String status) {
    const labels = ['Sent', 'Accepted', 'On the way', 'Done'];
    const order = {'pending': 0, 'accepted': 1, 'en_route': 2, 'completed': 3};
    final cur = order[status] ?? 0;
    return Row(
      children: List.generate(4, (i) {
        final done = i <= cur;
        return Expanded(
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Container(
                  height: 3,
                  color: i == 0 ? Colors.transparent : (i <= cur ? AppColors.accent : context.field),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: done ? AppColors.accent : context.field, shape: BoxShape.circle),
                child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
              Expanded(
                child: Container(
                  height: 3,
                  color: i == 3 ? Colors.transparent : (i < cur ? AppColors.accent : context.field),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(labels[i],
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                  color: done ? context.ink : context.muted,
                )),
          ]),
        );
      }),
    );
  }

  Widget _personCard({
    required String title,
    required String name,
    required String subtitle,
    String? phone,
    VoidCallback? onChat,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(context),
      child: Row(children: [
        Avatar(name, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(),
                style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w700, color: context.muted)),
            const SizedBox(height: 2),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subtitle.isNotEmpty)
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.muted, fontSize: 12.5)),
          ]),
        ),
        if (phone != null && phone.isNotEmpty) ...[
          RoundIconButton(icon: Icons.phone_rounded, bg: context.field, onTap: () => callNumber(context, phone)),
          const SizedBox(width: 8),
        ],
        if (onChat != null) RoundIconButton(icon: Icons.chat_bubble_rounded, bg: AppColors.accent, fg: Colors.white, onTap: onChat),
      ]),
    );
  }

  Widget _actions(Map<String, dynamic> r) {
    final status = r['status'] as String;
    final children = <Widget>[];
    if (_isMech) {
      if (status == 'pending') {
        children.add(PillButton(
          label: 'Accept request',
          color: AppColors.accent,
          loading: _busy,
          onTap: () => _status('accepted', 'Request accepted. Contact the driver.'),
        ));
      } else if (status == 'accepted' || status == 'en_route') {
        if (r['approximate'] != true) {
          children.add(PillButton(
            label: 'Navigate to driver',
            icon: Icons.near_me_rounded,
            outlined: true,
            onTap: () => openDirections(context, (r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()),
          ));
          children.add(const SizedBox(height: 10));
        }
        children.add(status == 'accepted'
            ? PillButton(
                label: "I'm on my way",
                color: AppColors.accent,
                loading: _busy,
                onTap: () => _status('en_route', 'Driver notified that you are on the way.'),
              )
            : PillButton(
                label: 'Mark as completed',
                color: AppColors.ok,
                loading: _busy,
                onTap: () => _status('completed', 'Job completed. Well done!'),
              ));
      }
    } else {
      if (status == 'pending' || status == 'accepted' || status == 'en_route') {
        children.add(PillButton(label: 'Cancel request', outlined: true, loading: _busy, onTap: _cancel));
      } else if (status == 'completed' && r['mechanic'] != null) {
        final mid = (r['mechanic'] as Map)['id'] as int;
        children.add(PillButton(label: 'Rate your mechanic', color: AppColors.accent, onTap: () => _rate(mid)));
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
