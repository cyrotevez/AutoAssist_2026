import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationResult {
  final LatLng? point;
  final String? error;
  const LocationResult(this.point, this.error);
}

Future<LocationResult> getLocation() async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return const LocationResult(null, 'Location is turned off. Turn on GPS and try again.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return const LocationResult(null, 'Location permission was denied.');
    }
    if (perm == LocationPermission.deniedForever) {
      return const LocationResult(
          null, 'Location permission is blocked. Enable it in phone Settings > Apps > AutoAssist > Permissions.');
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult(LatLng(pos.latitude, pos.longitude), null);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LocationResult(LatLng(last.latitude, last.longitude), null);
      return const LocationResult(null, 'Could not get a GPS fix. Try again outdoors or check your GPS.');
    }
  } catch (_) {
    return const LocationResult(null, 'Could not get your location.');
  }
}
