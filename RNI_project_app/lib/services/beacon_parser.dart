import 'package:rni_project_app/BLEPositionEstimator.dart';

/// Converts the raw list returned by ApiService.fetchBeaconsRaw() into the
/// same Map<String, BeaconMeta> shape that beacon_db2.dart used to provide
/// statically.
Map<String, BeaconMeta> parseBeaconsResponse(List<dynamic> raw) {
  final Map<String, BeaconMeta> result = {};

  // ============================================================
  // TEMP DEBUG counters — tells us exactly why beacons are being
  // skipped instead of just "0 usable".
  // ============================================================
  int noName = 0;
  int noLxLy = 0;
  int noProperties = 0;
  int noCentroidField = 0;
  int centroidWrongShape = 0;
  int centroidParsedOk = 0;
  bool printedFirstRaw = false;

  for (final entry in raw) {
    if (entry is! Map<String, dynamic>) continue;

    // Print the very first raw beacon record in full, once, so we can
    // see its exact real shape without scrolling through 113 of them.
    if (!printedFirstRaw) {
      print('=== FIRST RAW BEACON ENTRY: $entry ===');
      printedFirstRaw = true;
    }

    final name = entry['name']?.toString();
    if (name == null || name.isEmpty) {
      noName++;
      continue;
    }

    final floor = _asInt(entry['floor']) ?? 0;

    final lx = _asDouble(entry['coordinateX']);
    final ly = _asDouble(entry['coordinateY']);
    if (lx == null || ly == null) {
      noLxLy++;
      continue; // can't place this beacon
    }

    // ---- ADDED: capture building_ID (top-level field on each beacon entry) ----
    final buildingId = entry['building_ID']?.toString();
    // -----------------------------------------------------------------------------

    double? lat;
    double? lon;
    final props = entry['properties'];
    if (props is Map<String, dynamic>) {
      if (!props.containsKey('centroid')) {
        noCentroidField++;
      } else {
        final centroid = props['centroid'];
        if (centroid is List && centroid.length >= 2) {
          lon = _asDouble(centroid[0]);
          lat = _asDouble(centroid[1]);
          if (lat != null && lon != null) {
            centroidParsedOk++;
          } else {
            centroidWrongShape++;
            if (centroidWrongShape <= 5) {
              print('WRONG SHAPE #$centroidWrongShape — name: $name, centroid: $centroid, '
                  'centroid[0] runtimeType: ${centroid[0].runtimeType}, '
                  'centroid[1] runtimeType: ${centroid[1].runtimeType}');
            }
          }
        } else {
          centroidWrongShape++;
          if (centroidWrongShape <= 5) {
            print('WRONG SHAPE #$centroidWrongShape — name: $name, centroid: $centroid, '
                'centroid runtimeType: ${centroid.runtimeType}, '
                'is List: ${centroid is List}, '
                'length if list: ${centroid is List ? centroid.length : "N/A"}');
          }
        }
      }
    } else {
      noProperties++;
    }

    result[name] = BeaconMeta(
      lx: lx.round(),
      ly: ly.round(),
      floor: floor,
      lat: lat,
      lon: lon,
      buildingId: buildingId, // ADDED
    );
  }

  print('=== BEACON PARSE SUMMARY ===');
  print('Total raw entries: ${raw.length}');
  print('Skipped - no name: $noName');
  print('Skipped - no coordinateX/Y: $noLxLy');
  print('Kept but no "properties" map at all: $noProperties');
  print('Kept but "properties" has no "centroid" key: $noCentroidField');
  print('Kept but centroid present with wrong shape/unparseable: $centroidWrongShape');
  print('Successfully parsed lat/lon from centroid: $centroidParsedOk');
  print('=== END BEACON PARSE SUMMARY ===');

  return result;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString());
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}