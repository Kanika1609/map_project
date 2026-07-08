import 'dart:convert';
import 'dart:io';
import 'dart:developer';
import 'package:localization_engine/src/network/model/beaconData.dart';
import 'package:localization_engine/src/statisticalMode.dart';

void testFilterByBinsAndAverage(String csvPath) {
  // ── Step 1: Parse CSV ──────────────────────────────────────────────────────
  final file = File(csvPath);
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

  print('── Parsed ${data.length} beacons ──────────────────────────────');
  data.forEach((id, entries) {
    print('  $id → ${entries.length} readings');
  });

  // ── Step 2: Run filterByBinsAndAverage ────────────────────────────────────
  final result = filterByBinsAndAverage(data);

  // ── Step 3: Print results ─────────────────────────────────────────────────
  print('\n── Results ─────────────────────────────────────────────────────');

  // Sort by avg RSSI descending (strongest first)
  final sorted = result.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (final entry in sorted) {
    final beaconId   = entry.key;
    final avg        = entry.value;
    final rawEntries = data[beaconId]!;
    final rawAvg     = rawEntries.map((e) => e.value).reduce((a, b) => a + b) /
        rawEntries.length;

    print('  $beaconId'
        ' | raw avg: ${rawAvg.toStringAsFixed(2)}'
        ' | bin avg: ${avg.toStringAsFixed(2)}'
        ' | diff: ${(avg - rawAvg).toStringAsFixed(2)}'
        ' | readings: ${rawEntries.length}');
  }

  // ── Step 4: Validate ──────────────────────────────────────────────────────
  print('\n── Validation ──────────────────────────────────────────────────');

  // Every beacon in data should have a result
  final missingBeacons = data.keys.where((id) => !result.containsKey(id));
  if (missingBeacons.isEmpty) {
    print('  ✅ All ${data.length} beacons have a result');
  } else {
    print('  ❌ Missing results for: $missingBeacons');
  }

  // All avg RSSI values should be within valid range
  final outOfRange = result.entries.where((e) => e.value < -105 || e.value > -60);
  if (outOfRange.isEmpty) {
    print('  ✅ All bin averages are within expected RSSI range [-105, -60]');
  } else {
    print('  ❌ Out of range averages: $outOfRange');
  }

  // Bin avg should always be >= raw avg (since densest bin clusters near mean)
  final worseAvg = result.entries.where((e) {
    final rawAvg = data[e.key]!.map((r) => r.value).reduce((a, b) => a + b) /
        data[e.key]!.length;
    return e.value.abs() > rawAvg.abs(); // bin avg is weaker than raw
  });
  if (worseAvg.isEmpty) {
    print('  ✅ Bin avg is always stronger (less negative) than raw avg');
  } else {
    print('  ⚠️  These beacons have bin avg weaker than raw avg: '
        '${worseAvg.map((e) => e.key).toList()}');
  }

  print('── Test complete ────────────────────────────────────────────────');
}

Map<String, List<MapEntry<DateTime, int>>> extractBeaconReadings(String path){
  final file = File(path);
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

int getBestFloor(List<dynamic> result) {
  // ---- Find top 2 by RSSI (no full sort) ----
  var top1 = result[0];
  var top2 = result.length > 1 ? result[1] : result[0];

  if (top2.result!.beacon1ModeRssi > top1.result!.beacon1ModeRssi) {
    final temp = top1;
    top1 = top2;
    top2 = temp;
  }

  for (int i = 2; i < result.length; i++) {
    final r = result[i];
    final rssi = r.result!.beacon1ModeRssi;

    if (rssi > top1.result!.beacon1ModeRssi) {
      top2 = top1;
      top1 = r;
    } else if (rssi > top2.result!.beacon1ModeRssi) {
      top2 = r;
    }
  }

  final rssi1 = top1.result!.beacon1ModeRssi;
  final rssi2 = top2.result!.beacon1ModeRssi;

  // ---- Rule 1: RSSI dominance ----
  if ((rssi1 - rssi2).abs() >= 5 && top1.floor < top2.floor) {
    return top1.floor;
  }

  // ---- Find top 2 by distance ----
  var d1 = result[0];
  var d2 = result.length > 1 ? result[1] : result[0];

  if (d2.result!.averageDistanceToCircles <
      d1.result!.averageDistanceToCircles) {
    final temp = d1;
    d1 = d2;
    d2 = temp;
  }

  for (int i = 2; i < result.length; i++) {
    final r = result[i];
    final dist = r.result!.averageDistanceToCircles;

    if (dist < d1.result!.averageDistanceToCircles) {
      d2 = d1;
      d1 = r;
    } else if (dist < d2.result!.averageDistanceToCircles) {
      d2 = r;
    }
  }

  final dist1 = d1.result!.averageDistanceToCircles;
  final dist2 = d2.result!.averageDistanceToCircles;

  // ---- Rule 2: Distance proximity ----
  if ((dist1 - dist2).abs() <= 1) {
    return d1.floor < d2.floor ? d1.floor : d2.floor;
  }

  return d1.floor;
}


// ── Entry point ───────────────────────────────────────────────────────────────
Future<void> main() async {
  final file = File("test/response.json");
  final jsonString = await file.readAsString();
  final List<dynamic> jsonList = jsonDecode(jsonString);

  final beaconList = jsonList
      .map((data) => Beacon.fromJson(data as Map<String, dynamic>))
      .toList();

  final dir = Directory("test/output/floor_B1");

  int totalCsv = 0;
  final Map<int, int> floorFrequency = {};

  await for (final entity in dir.list()) {
    if (entity is! File || !entity.path.endsWith(".csv")) continue;

    totalCsv++;

    final data = extractBeaconReadings(entity.path);

    var p = entity.path.split('/');
    var l = p.last.split('_');
    List<int> location = [int.parse(l[0]), int.parse(l[1])];

    final result = analyseTopBeaconsCircleProximity(
      data,
      beaconList,
      location: location
    )..removeWhere((r) => r.result == null);

    if (result.isEmpty) continue;

    final bestFloor = getBestFloor(result);

    var bestResult = result.where((r)=>r.floor == bestFloor).first.result;
    if(bestResult != null && bestResult.locationError! >5){
      print("locationError ${bestResult?.locationError} m error between $location and ${bestResult?.estimateLocation}");
      print(bestResult);
    }

    if (bestFloor != -1) {
      print("wrong floor detected ${entity.path}");
      for (var r in result) {
        print(r);
      }
      print("\n\n");
    }

    floorFrequency.update(bestFloor, (v) => v + 1, ifAbsent: () => 1);
  }

  print("\nTotal CSV files: $totalCsv");

  print("Best floor frequency:");
  floorFrequency.forEach((floor, count) {
    print("Floor $floor -> $count times");
  });
}