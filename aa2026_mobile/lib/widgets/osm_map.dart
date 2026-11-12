import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';

class MapMarker {
  final LatLng point;
  final Widget child;
  final double size;
  final VoidCallback? onTap;
  const MapMarker({required this.point, required this.child, this.size = 44, this.onTap});
}

/// OpenStreetMap view (free, no API key). Dark mode inverts the tiles.
class OsmMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<MapMarker> markers;
  final MapController? controller;
  final VoidCallback? onMapTap;
  final double attributionBottom;
  const OsmMap({
    super.key,
    required this.center,
    this.zoom = 14,
    this.markers = const [],
    this.controller,
    this.onMapTap,
    this.attributionBottom = 8,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Stack(fit: StackFit.expand, children: [
      FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          minZoom: 3,
          maxZoom: 18,
          onTap: onMapTap == null ? null : (tapPosition, point) => onMapTap!(),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.autoassist.aa2026_mobile',
            tileBuilder: dark
                ? (context, tileWidget, tile) => ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        -0.2126, -0.7152, -0.0722, 0, 255, //
                        -0.2126, -0.7152, -0.0722, 0, 255, //
                        -0.2126, -0.7152, -0.0722, 0, 255, //
                        0, 0, 0, 1, 0,
                      ]),
                      child: tileWidget,
                    )
                : null,
          ),
          MarkerLayer(
            markers: [
              for (final m in markers)
                Marker(
                  point: m.point,
                  width: m.size,
                  height: m.size,
                  child: GestureDetector(onTap: m.onTap, child: m.child),
                ),
            ],
          ),
        ],
      ),
      Positioned(
        left: 8,
        bottom: attributionBottom,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white.withAlpha(200), borderRadius: BorderRadius.circular(8)),
          child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10, color: Colors.black87)),
        ),
      ),
    ]);
  }
}

Widget userDot() => Container(
      decoration: BoxDecoration(
        color: AppColors.info,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: AppColors.info.withAlpha(90), blurRadius: 12, spreadRadius: 3)],
      ),
    );

Widget pinMarker({bool selected = false, IconData icon = Icons.build_rounded, Color color = AppColors.accent}) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    margin: EdgeInsets.all(selected ? 0 : 4),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: [BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Icon(icon, color: Colors.white, size: selected ? 24 : 20),
  );
}
