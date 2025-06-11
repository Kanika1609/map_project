import 'package:flutter/services.dart' show rootBundle;
import 'package:geojson_vi/geojson_vi.dart';
import 'package:latlong2/latlong.dart';

Future<List<LatLng>> loadGeoJsonPoints() async {
  final rawGeoJson = await rootBundle.loadString('assets/landmarks_output.geojson');

  final geoJson = GeoJsonVi.fromJson(rawGeoJson);

  // Filter features of type 'Point'
  final points = geoJson.features.where((feature) {
    return feature.geometry.type == GeoJsonViGeometryType.point;
  }).map((feature) {
    final coords = feature.geometry.coordinates;
    // coords is List<dynamic> [lon, lat]
    return LatLng(coords[1] as double, coords[0] as double);
  }).toList();

  return points;
}
