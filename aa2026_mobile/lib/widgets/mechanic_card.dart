import 'package:flutter/material.dart';
import '../screens/mechanic_detail.dart';
import 'common.dart';

class MechanicCard extends StatelessWidget {
  final Map<String, dynamic> m;
  const MechanicCard({super.key, required this.m});

  @override
  Widget build(BuildContext context) {
    final id = m['id'] as int;
    final rating = (m['rating'] as num?)?.toDouble() ?? 0;
    final dist = m['distance_km'] as num?;
    final available = m['available'] == true;
    return Tappable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MechanicDetailScreen(mechanic: m)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(fit: StackFit.expand, children: [
          Hero(tag: 'mech-$id', child: AppImage(name: mechanicPhoto(id), icon: Icons.engineering_rounded)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withAlpha(30), Colors.transparent, Colors.black.withAlpha(200)],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: _pill(
              Colors.white,
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFB020)),
                const SizedBox(width: 3),
                Text(rating > 0 ? rating.toStringAsFixed(1) : 'New',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87)),
              ]),
            ),
          ),
          if (dist != null)
            Positioned(
              top: 10,
              right: 10,
              child: _pill(
                Colors.black.withAlpha(110),
                Text(distText(dist),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: Text(displayName(m),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: available ? const Color(0xFF34D27B) : const Color(0xFFFFB020),
                    shape: BoxShape.circle,
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 12, color: Colors.white70),
                const SizedBox(width: 3),
                Expanded(
                  child: Text((m['address'] as String?) ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pill(Color bg, Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: child,
      );
}
