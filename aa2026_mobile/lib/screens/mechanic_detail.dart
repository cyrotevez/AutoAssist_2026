import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'request_form.dart';

class MechanicDetailScreen extends StatefulWidget {
  final Map<String, dynamic> mechanic;
  const MechanicDetailScreen({super.key, required this.mechanic});

  @override
  State<MechanicDetailScreen> createState() => _MechanicDetailScreenState();
}

class _MechanicDetailScreenState extends State<MechanicDetailScreen> {
  late Map<String, dynamic> _m = widget.mechanic;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loc = app.location;
    try {
      final data = await app.api.get(
        '/mechanics/${_m['id']}',
        query: loc == null ? null : {'lat': loc.latitude, 'lng': loc.longitude},
      );
      if (!mounted) return;
      setState(() {
        _m = Map<String, dynamic>.from(data as Map);
        _loading = false;
      });
    } on ApiException {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const ReviewSheet(),
    );
    if (res == null) return;
    try {
      await app.api.post('/mechanics/${_m['id']}/reviews', body: res);
      if (mounted) showMsg(context, 'Thanks for your review!');
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _m['id'] as int;
    final top = MediaQuery.of(context).padding.top;
    final rating = (_m['rating'] as num?)?.toDouble() ?? 0;
    final count = (_m['reviews_count'] as num?)?.toInt() ?? 0;
    final available = _m['available'] == true;
    final specs = ((_m['specialization'] as String?) ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final services = (_m['services'] as String?) ?? '';
    final bio = (_m['bio'] as String?) ?? '';
    final reviews = ((_m['reviews'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final person = (_m['name'] as String?) ?? '';
    final biz = displayName(_m);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          Stack(children: [
            SizedBox(
              height: 300,
              width: double.infinity,
              child: Hero(tag: 'mech-$id', child: AppImage(name: mechanicPhoto(id), icon: Icons.engineering_rounded)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withAlpha(110), Colors.transparent],
                    stops: const [0, 0.4],
                  ),
                ),
              ),
            ),
            Positioned(top: top + 8, left: 16, child: const BackBtn()),
          ]),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
              decoration: BoxDecoration(
                color: context.page,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(biz, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, height: 1.15)),
                      if (person.isNotEmpty && person != biz) ...[
                        const SizedBox(height: 3),
                        Text('by $person', style: TextStyle(color: context.muted)),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (available ? AppColors.ok : AppColors.star).withAlpha(36),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      available ? 'Available' : 'Busy',
                      style: TextStyle(
                        color: available ? AppColors.ok : AppColors.star,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  StarRow(rating),
                  const SizedBox(width: 8),
                  Text(
                    rating > 0 ? '${rating.toStringAsFixed(1)} ($count reviews)' : 'No reviews yet',
                    style: TextStyle(color: context.muted, fontSize: 13),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 17, color: context.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [(_m['address'] as String?) ?? '', distText(_m['distance_km'] as num?)]
                          .where((e) => e.isNotEmpty)
                          .join('  •  '),
                      style: TextStyle(color: context.muted, fontSize: 13),
                    ),
                  ),
                ]),
                if (specs.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in specs)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(14)),
                        child: Text(s, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ],
                if (services.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text('Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(services, style: TextStyle(color: context.muted, height: 1.45)),
                ],
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(bio, style: TextStyle(color: context.muted, height: 1.45)),
                ],
                const SizedBox(height: 24),
                SectionTitle(
                  'Reviews',
                  trailing: app.role == 'driver'
                      ? TextButton(
                          onPressed: _review,
                          child: const Text('Write a review', style: TextStyle(color: AppColors.accent)),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Skeleton(height: 70, radius: 16)
                else if (reviews.isEmpty)
                  Text('No reviews yet.', style: TextStyle(color: context.muted))
                else
                  for (final r in reviews) _reviewTile(r),
                const SizedBox(height: 90),
              ]),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: context.card, border: Border(top: BorderSide(color: context.line))),
        child: Row(children: [
          RoundIconButton(
            icon: Icons.phone_rounded,
            size: 54,
            bg: context.field,
            onTap: () => callNumber(context, _m['phone'] as String?),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PillButton(
              label: app.role == 'driver' ? 'Request help' : 'Call mechanic',
              color: app.role == 'driver' ? AppColors.accent : null,
              onTap: app.role == 'driver'
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => RequestFormScreen(mechanic: _m)),
                      )
                  : () => callNumber(context, _m['phone'] as String?),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _reviewTile(Map<String, dynamic> r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(context, radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar((r['driver_name'] as String?) ?? 'D', size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text((r['driver_name'] as String?) ?? 'Driver',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
          StarRow(((r['rating'] as num?) ?? 0).toDouble(), size: 14),
        ]),
        if (((r['comment'] as String?) ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(r['comment'] as String, style: TextStyle(color: context.muted, height: 1.4, fontSize: 13.5)),
        ],
      ]),
    );
  }
}

class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key});
  @override
  State<ReviewSheet> createState() => ReviewSheetState();
}

class ReviewSheetState extends State<ReviewSheet> {
  int _rating = 5;
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Rate this mechanic', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Row(children: [
          for (int i = 1; i <= 5; i++)
            GestureDetector(
              onTap: () => setState(() => _rating = i),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 38, color: AppColors.star),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        AppField(controller: _c, hint: 'Share your experience (optional)', maxLines: 3),
        const SizedBox(height: 18),
        PillButton(
          label: 'Submit review',
          onTap: () => Navigator.of(context).pop({'rating': _rating, 'comment': _c.text.trim()}),
        ),
      ]),
    );
  }
}

Future<Map<String, dynamic>?> showReviewSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const ReviewSheet(),
  );
}
