import 'dart:ui' show Offset;
import 'package:rni_project_app/BLEPositionEstimator.dart';

/// Coefficients for: local = a*lon + b*lat + c
class AffineCoeffs {
  final double a, b, c;
  const AffineCoeffs(this.a, this.b, this.c);
}

class FloorAffine {
  final AffineCoeffs x;
  final AffineCoeffs y;
  const FloorAffine(this.x, this.y);
}

/// Solves a 3x3 linear system Ax = b using Gaussian elimination with
/// partial pivoting. Used to solve the least-squares normal equations
/// for the affine fit below (no external math package needed).
List<double> _solve3x3(List<List<double>> A, List<double> b) {
  final m = [
    [A[0][0], A[0][1], A[0][2], b[0]],
    [A[1][0], A[1][1], A[1][2], b[1]],
    [A[2][0], A[2][1], A[2][2], b[2]],
  ];

  for (int col = 0; col < 3; col++) {
    int pivot = col;
    for (int row = col + 1; row < 3; row++) {
      if (m[row][col].abs() > m[pivot][col].abs()) pivot = row;
    }
    final tmp = m[col];
    m[col] = m[pivot];
    m[pivot] = tmp;

    if (m[col][col].abs() < 1e-12) {
      // Degenerate (collinear control points) — bail with zeros; caller
      // should fall back to another floor's coefficients in this case.
      return [0, 0, 0];
    }

    for (int row = 0; row < 3; row++) {
      if (row == col) continue;
      final factor = m[row][col] / m[col][col];
      for (int k = col; k < 4; k++) {
        m[row][k] -= factor * m[col][k];
      }
    }
  }

  return [m[0][3] / m[0][0], m[1][3] / m[1][1], m[2][3] / m[2][2]];
}

/// Fits local = a*lon + b*lat + c (separately for x and y) via least
/// squares, given control points that have both GPS and local coordinates.
/// Needs at least 3 non-collinear points.
FloorAffine? _fitAffine(List<(double lon, double lat, double lx, double ly)> pts) {
  if (pts.length < 3) return null;

  double sLon = 0, sLat = 0, sN = pts.length.toDouble();
  double sLonLon = 0, sLonLat = 0, sLatLat = 0;
  double sLonX = 0, sLatX = 0, sX = 0;
  double sLonY = 0, sLatY = 0, sY = 0;

  for (final p in pts) {
    final (lon, lat, lx, ly) = p;
    sLon += lon;
    sLat += lat;
    sLonLon += lon * lon;
    sLonLat += lon * lat;
    sLatLat += lat * lat;
    sLonX += lon * lx;
    sLatX += lat * lx;
    sX += lx;
    sLonY += lon * ly;
    sLatY += lat * ly;
    sY += ly;
  }

  final A = [
    [sLonLon, sLonLat, sLon],
    [sLonLat, sLatLat, sLat],
    [sLon, sLat, sN],
  ];

  final coefX = _solve3x3(A, [sLonX, sLatX, sX]);
  final coefY = _solve3x3(A, [sLonY, sLatY, sY]);

  return FloorAffine(
    AffineCoeffs(coefX[0], coefX[1], coefX[2]),
    AffineCoeffs(coefY[0], coefY[1], coefY[2]),
  );
}

Offset _apply(FloorAffine f, double lon, double lat) {
  final x = f.x.a * lon + f.x.b * lat + f.x.c;
  final y = f.y.a * lon + f.y.b * lat + f.y.c;
  return Offset(x, y);
}

/// Fits one affine transform per floor using that floor's beacons as
/// control points (mirrors the offline Python script used for RGCI).
Map<int, FloorAffine> fitPerFloor(Map<String, BeaconMeta> beacons) {
  final byFloor = <int, List<(double, double, double, double)>>{};
  for (final b in beacons.values) {
    // Skip beacons missing GPS coordinates — they can't be used as
    // control points for the affine fit (BeaconMeta.lat/lon may be null
    // if the API didn't return global coordinates for this beacon).
    final lat = b.lat;
    final lon = b.lon;
    if (lat == null || lon == null) continue;

    byFloor.putIfAbsent(b.floor, () => []).add(
        (lon, lat, b.lx.toDouble(), b.ly.toDouble()));
  }

  final result = <int, FloorAffine>{};
  for (final entry in byFloor.entries) {
    final fit = _fitAffine(entry.value);
    if (fit != null) result[entry.key] = fit;
  }
  return result;
}

/// Recursively projects every [lon, lat] pair in a GeoJSON `coordinates`
/// structure into local x/y, preserving nesting (Point / LineString /
/// Polygon / MultiPolygon all fall out of this naturally).
dynamic _projectCoords(dynamic coords, FloorAffine affine) {
  if (coords.isEmpty) return coords;
  if (coords[0] is num) {
    final lon = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    final p = _apply(affine, lon, lat);
    return [double.parse(p.dx.toStringAsFixed(2)), double.parse(p.dy.toStringAsFixed(2))];
  }
  return coords.map<dynamic>((c) => _projectCoords(c, affine)).toList();
}

/// Takes the raw GeoJSON (lon/lat coordinates) fetched from the API and the
/// beacon map for the same venue, fits a per-floor affine transform, and
/// returns a new GeoJSON where every feature also carries a
/// `coordinatesLocal` field aligned to the beacon lx/ly coordinate system.
///
/// If a floor has fewer than 3 beacons (can't fit its own transform), it
/// falls back to another floor's transform as a best-effort approximation
/// — a warning is left in `properties._alignmentFallback` on those
/// features so you can spot it while debugging.
Map<String, dynamic> alignGeoJson(
    Map<String, dynamic> rawGeoJson,
    Map<String, BeaconMeta> beacons,
    ) {
  final perFloor = fitPerFloor(beacons);
  final fallback = perFloor.values.isNotEmpty ? perFloor.values.first : null;

  final features = (rawGeoJson['features'] as List<dynamic>? ?? []);
  final outFeatures = <Map<String, dynamic>>[];

  for (final feature in features) {
    final props = Map<String, dynamic>.from(feature['properties'] ?? {});
    final geom = feature['geometry'] as Map<String, dynamic>;
    final floor = (props['floor'] ?? props['level'] ?? 0) as int;

    final affine = perFloor[floor] ?? fallback;
    if (affine == null) continue; // no control points at all for this venue

    if (perFloor[floor] == null) {
      props['_alignmentFallback'] = true;
    }

    final local = _projectCoords(geom['coordinates'], affine);

    outFeatures.add({
      'type': 'Feature',
      'geometry': {
        'type': geom['type'],
        'coordinates': geom['coordinates'],
        'coordinatesLocal': local,
      },
      'properties': props,
    });
  }

  return {'type': 'FeatureCollection', 'features': outFeatures};
}