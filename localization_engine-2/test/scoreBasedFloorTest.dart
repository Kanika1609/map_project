import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../lib/src/network/model/beaconData.dart';

// ----------------- MODELS -----------------

class _BeaconReading {
  final String name;
  final double distance;
  final double weight;
  final double x;
  final double y;
  final int floor;

  const _BeaconReading({
    required this.name,
    required this.distance,
    required this.weight,
    required this.x,
    required this.y,
    required this.floor,
  });
}

class FloorDetectionResult {
  final int floor;
  final double confidence;
  final Map<int, double> allConfidences;

  const FloorDetectionResult({
    required this.floor,
    required this.confidence,
    required this.allConfidences,
  });

  @override
  String toString() =>
      'Floor: $floor | Confidence: ${(confidence * 100).toStringAsFixed(1)}% | '
          'All: { ${allConfidences.entries.map((e) => 'F${e.key}: ${(e.value * 100).toStringAsFixed(1)}%').join(', ')} }';
}

// ----------------- CONFIG -----------------

const int _topNBeacons = 3;
const double _txPower = -70;
const double _pathLossN = 2.5;

// ----------------- HELPERS -----------------

double _rssiToDistance(double rssi) {
  return pow(10, (_txPower - rssi) / (10 * _pathLossN)).toDouble();
}

double _median(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid].toDouble()
      : (sorted[mid - 1] + sorted[mid]) / 2.0;
}

double _mean(List<double> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

({double x, double y, double error}) _trilaterate(List<_BeaconReading> beacons) {
  double posX = _mean(beacons.map((b) => b.x).toList());
  double posY = _mean(beacons.map((b) => b.y).toList());

  const int maxIter = 100;
  const double eps = 1e-6;

  for (int iter = 0; iter < maxIter; iter++) {
    double jTjA = 0, jTjB = 0, jTjC = 0, jTjD = 0;
    double jTrA = 0, jTrB = 0;

    for (final b in beacons) {
      final dx = posX - b.x;
      final dy = posY - b.y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < eps) continue;

      final residual = b.weight * (dist - b.distance);
      final jx = b.weight * dx / dist;
      final jy = b.weight * dy / dist;

      jTjA += jx * jx;
      jTjB += jx * jy;
      jTjC += jy * jx;
      jTjD += jy * jy;
      jTrA += jx * residual;
      jTrB += jy * residual;
    }

    final det = jTjA * jTjD - jTjB * jTjC;
    if (det.abs() < eps) break;

    final deltaX = -(jTjD * jTrA - jTjB * jTrB) / det;
    final deltaY = -(-jTjC * jTrA + jTjA * jTrB) / det;

    posX += deltaX;
    posY += deltaY;

    if (sqrt(deltaX * deltaX + deltaY * deltaY) < eps) break;
  }

  double totalError = 0;
  for (final b in beacons) {
    final dx = posX - b.x;
    final dy = posY - b.y;
    totalError += (sqrt(dx * dx + dy * dy) - b.distance).abs();
  }

  return (x: posX, y: posY, error: totalError / beacons.length);
}

// ----------------- MAIN FUNCTION -----------------

/// Detects the floor from a single collected scan window.
///
/// [data]    — beaconName → list of (timestamp, rssi) entries collected over 5–15s
/// [beacons] — metadata list (name, x, y, floor) for all known beacons
FloorDetectionResult? detectFloor(
    Map<String, List<MapEntry<DateTime, int>>> data,
    List<Beacon> beacons,
    ) {
  final beaconDict = {for (final b in beacons) b.name: b};
  final floorsAll = (beacons.map((b) => b.floor).toSet().toList()..sort());

  // ---------- AGGREGATE: median RSSI per beacon ----------
  final List<_BeaconReading> agg = [];

  for (final entry in data.entries) {
    final meta = beaconDict[entry.key];
    if (meta == null || entry.value.isEmpty) continue;

    final rssiValues = entry.value.map((e) => e.value).toList();
    final medianRssi = _median(rssiValues);
    final distance = _rssiToDistance(medianRssi);
    final weight = 1.0 / (distance + 1e-6);

    agg.add(_BeaconReading(
      name: entry.key,
      distance: distance,
      weight: weight,
      x: meta.coordinateX!.toDouble(),
      y: meta.coordinateY!.toDouble(),
      floor: meta.floor!,
    ));
  }

  if (agg.isEmpty) return null;

  // ---------- SCORE EACH FLOOR ----------
  final Map<int, double> floorScores = {};

  for (final f in floorsAll) {
    var fb = agg.where((b) => b.floor == f).toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));

    if (fb.length < 3) continue;
    fb = fb.take(_topNBeacons).toList();

    final tril = _trilaterate(fb);
    final meanWeight = _mean(fb.map((b) => b.weight).toList());

    final cx = _mean(fb.map((b) => b.x).toList());
    final cy = _mean(fb.map((b) => b.y).toList());
    final spread = _mean(fb.map((b) {
      final dx = b.x - cx, dy = b.y - cy;
      return sqrt(dx * dx + dy * dy);
    }).toList());

    final geometryScore = 1.0 / (spread + 1);
    final residualScore = 1.0 / (tril.error + 1);

    floorScores[f!] = 0.25 * meanWeight +
        0.25 * log(fb.length + 1) +
        0.25 * geometryScore +
        0.25 * residualScore;
  }

  if (floorScores.isEmpty) return null;

  // ---------- NORMALIZE → CONFIDENCE ----------
  final total = floorScores.values.reduce((a, b) => a + b);
  final Map<int, double> floorConf = {
    for (final e in floorScores.entries) e.key: e.value / total,
  };

  final bestEntry =
  floorConf.entries.reduce((a, b) => a.value > b.value ? a : b);

  return FloorDetectionResult(
    floor: bestEntry.key,
    confidence: bestEntry.value,
    allConfidences: floorConf,
  );
}

// ----------------- EXAMPLE USAGE -----------------

Map<String, List<MapEntry<DateTime, int>>> extractBeaconReadings(){
  final file = File("test/yellow_left.csv");
  final lines = file.readAsLinesSync();
  final header = lines.first.split(','); // device,name,rssi,timestamp

  final deviceIndex    = header.indexOf('name');
  final rssiIndex      = header.indexOf('rssi');
  final timestampIndex = header.indexOf('timestamp');

  final Map<String, List<MapEntry<DateTime, int>>> data = {};

  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;

    final cols      = line.split(',');
    final beaconId  = cols[deviceIndex].trim();
    final rssi      = int.parse(cols[rssiIndex].trim());
    final timestamp = DateTime.parse(cols[timestampIndex].trim());

    data.putIfAbsent(beaconId, () => []);
    data[beaconId]!.add(MapEntry(timestamp, rssi));
  }

  return data;
}

Future<void> main() async {

  final file = File("test/response.json");
  final jsonString = await file.readAsString();
  final List<dynamic> jsonList = jsonDecode(jsonString);

  List<Beacon> beaconList =
  jsonList.map((data) => Beacon.fromJson(data as Map<String, dynamic>)).toList();

  final now = DateTime.now();

  var data = extractBeaconReadings();

  final result = detectFloor(data, beaconList);
  print(result ?? 'Not enough data to detect floor.');
}