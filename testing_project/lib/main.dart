import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:localization_engine/localization_engine.dart';

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

// ─────────────────────────────────────────────────────────────────────────────
// Kalman Filter
// ─────────────────────────────────────────────────────────────────────────────
class KalmanFilter {
  double q;
  double r;
  double x = 0;
  double p = 1;
  double k = 0;

  KalmanFilter({this.q = 0.01, this.r = 1});

  double update(double measurement) {
    p = p + q;
    k = p / (p + r);
    x = x + k * (measurement - x);
    p = (1 - k) * p;
    return x;
  }
}

Future<void> requestPermissions() async {
  await Permission.location.request();
  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OrtEnv.instance.init(); // FIX 1: must init OrtEnv before any session use
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String resultText = "Press Simulate Walk";
  int selectedFloor = 0; // FIX 2: default to floor 3 since that's the test data

  double buildingLat = 28.5436;
  double buildingLon = 77.1874;
  double? lastX;
  double? lastY;

  List<Map<String, List<int>>> simulatedData = [];
  int currentStep = 0;
  Timer? simulationTimer;
  Map<String, List<int>> scannedBeacons = {};
  Map<int, List<String>> floorBeaconOrders = {};

  OrtSession? session;
  bool _modelLoading = false; // FIX 3: guard against double-loading

  List<Polygon> polygons = [];
  Map<String, dynamic>? geoJsonData;
  Marker? userMarker;
  Map<String, dynamic>? patchData;

  KalmanFilter kalmanX = KalmanFilter();
  KalmanFilter kalmanY = KalmanFilter();

  // Realtime
  Timer? realtimeTimer;

  @override
  void initState() {
    super.initState();
    initializeApp();
    buildMap();
  }

  Future<void> buildMap() async {
    await fetchPatchData();
    await loadGeoJson();
    setState(() {});
  }

  @override
  void dispose() {
    simulationTimer?.cancel();
    realtimeTimer?.cancel();
    session?.release(); // FIX 4: release ONNX session on dispose
    OrtEnv.instance.release();
    LocalizationEngine.dispose();
    super.dispose();
  }

  Future<void> initializeApp() async {
    await loadBeaconOrders();
    await loadModel();
  }

  // ─── Patch API ──────────────────────────────────────────────────────────────
  Future<void> fetchPatchData() async {
    try {
      final response = await http.post(
        Uri.parse(
            "https://dev.iwayplus.in/secured/patch/get?api_key=7cc62870-d67e-11f0-91ed-2f0eb903e7db"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id": "65d887a5db333f89457145f6",
          "manufacturer": "android",
          "devicemodel": "moto g64"
        }),
      );
      if (response.statusCode == 200) {
        patchData = json.decode(response.body);
        debugPrint("PATCH LOADED");
      } else {
        debugPrint("PATCH HTTP ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("PATCH ERROR: $e");
    }
  }

  // ─── Coordinate helpers ─────────────────────────────────────────────────────
  double _dist(Map<String, double> p1, Map<String, double> p2) {
    double dx = p1["localx"]! - p2["localx"]!;
    double dy = p1["localy"]! - p2["localy"]!;
    return sqrt(dx * dx + dy * dy);
  }

  Map<String, double> _obtainCoords(
      Map<String, double> base, double ver, double hor) {
    return {
      "lat": base["lat"]! + (ver / 111320),
      "lon": base["lon"]! + (hor / (111320 * cos(base["lat"]! * pi / 180))),
    };
  }

  double _haversine(
      Map<String, double> a, Map<String, double> b) {
    const R = 6371.0;
    double dLat = (b["lat"]! - a["lat"]!) * pi / 180;
    double dLon = (b["lon"]! - a["lon"]!) * pi / 180;
    double arc = sin(dLat / 2) * sin(dLat / 2) +
        cos(a["lat"]! * pi / 180) *
            cos(b["lat"]! * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(arc), sqrt(1 - arc)) * 1000;
  }

  List<double> localToGlobal(double x, double y) {
    if (patchData == null) return [buildingLat, buildingLon];

    try {
      List coordinates = patchData!["patchData"]["coordinates"];

      List<Map<String, double>> ref = [
        {
          "lat": double.parse(coordinates[2]["globalRef"]["lat"]),
          "lon": double.parse(coordinates[2]["globalRef"]["lng"]),
          "localx": double.parse(coordinates[2]["localRef"]["lng"]),
          "localy": double.parse(coordinates[2]["localRef"]["lat"]),
        },
        {
          "lat": double.parse(coordinates[1]["globalRef"]["lat"]),
          "lon": double.parse(coordinates[1]["globalRef"]["lng"]),
          "localx": double.parse(coordinates[1]["localRef"]["lng"]),
          "localy": double.parse(coordinates[1]["localRef"]["lat"]),
        },
        {
          "lat": double.parse(coordinates[0]["globalRef"]["lat"]),
          "lon": double.parse(coordinates[0]["globalRef"]["lng"]),
          "localx": double.parse(coordinates[0]["localRef"]["lng"]),
          "localy": double.parse(coordinates[0]["localRef"]["lat"]),
        },
        {
          "lat": double.parse(coordinates[3]["globalRef"]["lat"]),
          "lon": double.parse(coordinates[3]["globalRef"]["lng"]),
          "localx": double.parse(coordinates[3]["localRef"]["lng"]),
          "localy": double.parse(coordinates[3]["localRef"]["lat"]),
        },
      ];

      int leastLat = 0;
      for (int i = 0; i < ref.length; i++) {
        if (ref[i]["lat"] == ref[leastLat]["lat"]) {
          if (ref[i]["lon"]! > ref[leastLat]["lon"]!) leastLat = i;
        } else if (ref[i]["lat"]! < ref[leastLat]["lat"]!) {
          leastLat = i;
        }
      }

      int c1 = (leastLat == 3) ? 0 : (leastLat + 1);
      int c2 = (leastLat == 0) ? 3 : (leastLat - 1);
      int highLon = (ref[c1]["lon"]! > ref[c2]["lon"]!) ? c1 : c2;

      double b = _haversine(ref[leastLat], ref[highLon]);
      Map<String, double> horizontal = _obtainCoords(ref[leastLat], 0, b);

      double c = _haversine(ref[leastLat], horizontal);
      double a = _haversine(ref[highLon], horizontal);

      double cosVal = (b * b + c * c - a * a) / (2 * b * c);
      cosVal = cosVal.clamp(-1.0, 1.0); // FIX 5: clamp before acos to avoid NaN
      double out = acos(cosVal) * 180 / pi;

      // FIX 6: removed broken diff logic; use x/y directly
      Map<String, double> localRef = {"localx": x, "localy": y};

      double l = _dist(ref[leastLat], ref[highLon]);
      double m = _dist(localRef, ref[highLon]);
      double n = _dist(ref[leastLat], localRef);

      double theta = 0;
      if (l > 0 && n > 0 && m > 0) {
        double cosTheta = (l * l + n * n - m * m) / (2 * l * n);
        cosTheta = cosTheta.clamp(-1.0, 1.0); // FIX 7: clamp here too
        theta = acos(cosTheta) * 180 / pi;
      }

      double ang = theta + out;
      double dist = _dist(ref[leastLat], localRef) * 0.3048;

      double ver = dist * sin(ang * pi / 180.0);
      double hor = dist * cos(ang * pi / 180.0);

      Map<String, double> finalCoords = _obtainCoords(ref[leastLat], ver, hor);
      return [finalCoords["lat"]!, finalCoords["lon"]!];
    } catch (e) {
      debugPrint("localToGlobal error: $e");
      return [buildingLat, buildingLon];
    }
  }

  // ─── Asset loading ──────────────────────────────────────────────────────────
  Future<void> loadBeaconOrders() async {
    try {
      final jsonString =
      await rootBundle.loadString('assets/data/floor_beacon_order.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      floorBeaconOrders = jsonData.map(
            (key, value) => MapEntry(
          int.parse(key),
          List<String>.from(value)
              .map((e) => e.toString().trim().toUpperCase())
              .toList(),
        ),
      );
      debugPrint("Beacon orders loaded for floors: ${floorBeaconOrders.keys}");
    } catch (e) {
      debugPrint("loadBeaconOrders error: $e");
    }
  }

  Future<void> loadModel() async {
    if (_modelLoading) return; // FIX 8: prevent concurrent loads
    _modelLoading = true;
    try {
      session?.release();
      session = null;

      final rawModel = await rootBundle
          .load("assets/model/floor${selectedFloor}_model.onnx");

      session = OrtSession.fromBuffer(
        rawModel.buffer.asUint8List(),
        OrtSessionOptions(),
      );
      debugPrint("Model loaded for floor $selectedFloor. "
          "Input: ${session!.inputNames}, Output: ${session!.outputNames}");
    } catch (e) {
      debugPrint("loadModel error: $e");
      setState(() => resultText = "Model load failed: $e");
    } finally {
      _modelLoading = false;
    }
  }

  Future<void> loadGeoJson() async {
    try {
      final geojsonString =
      await rootBundle.loadString('assets/maps/converted_geojson.geojson');
      geoJsonData = json.decode(geojsonString);
      drawFloor(selectedFloor);
    } catch (e) {
      debugPrint("loadGeoJson error: $e");
    }
  }

  // ─── CSV simulation loader ──────────────────────────────────────────────────
  // FIX 9: robust CSV parsing - handles spaces in values, bad rows, int.tryParse
  Future<List<Map<String, List<int>>>> loadCSVTimedData() async {
    final raw = await rootBundle.loadString('assets/data/beacon_data_B.csv');
    final lines = raw.split('\n');

    // header: device,name,rssi,timestamp,...
    // index:     0     1   2      3
    final Map<String, Map<String, List<int>>> timeGrouped = {};

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length < 4) continue; // FIX 10: skip short rows

      final name = parts[1].trim().toUpperCase();
      final rssi = int.tryParse(parts[2].trim()); // FIX 11: tryParse not parse
      if (rssi == null || name.isEmpty) continue;

      // timestamp is "2026-04-02 18:14:42.465" — no commas so parts[3] is safe
      // but the space means we need parts[3] + parts[4] if split by comma captures space
      // Actually timestamp column has no commas, so parts[3] = full timestamp string
      final timestamp = parts[3].trim();
      final secondKey = timestamp.split('.').first; // "2026-04-02 18:14:42"

      timeGrouped.putIfAbsent(secondKey, () => {});
      timeGrouped[secondKey]!.putIfAbsent(name, () => []);
      timeGrouped[secondKey]![name]!.add(rssi);
    }

    // Sort windows by time
    final sortedKeys = timeGrouped.keys.toList()
      ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));

    return sortedKeys.map((k) => timeGrouped[k]!).toList();
  }

  // ─── Map drawing ────────────────────────────────────────────────────────────
  void drawFloor(int floor) {
    if (geoJsonData == null) return;
    polygons.clear();

    for (var feature in geoJsonData!["features"]) {
      if (feature["properties"]["floor"] != floor) continue;

      final geom = feature["geometry"];
      if (geom == null) continue;
      if (geom["type"] == "LineString" || geom["type"] == "Point") continue;
      if (geom["coordinnatesLocal"] == null) continue; // note: typo in source

      List<LatLng> points = [];
      for (var coord in geom["coordinnatesLocal"][0]) {
        if (coord == null || (coord is List && coord.isEmpty)) continue;
        try {
          final val = localToGlobal(
            (coord[0] as num).toDouble(),
            (coord[1] as num).toDouble(),
          );
          points.add(LatLng(val[0], val[1]));
        } catch (_) {}
      }

      if (points.length >= 3) {
        polygons.add(Polygon(
          points: points,
          color: Colors.blue.withOpacity(0.3),
          borderColor: Colors.black,
          borderStrokeWidth: 1,
        ));
      }
    }
    setState(() {});
  }

  // ─── Position update ────────────────────────────────────────────────────────
  void updateUserPosition(double x, double y) {
    debugPrint("Raw prediction → x=$x, y=$y");

    if (patchData == null) {
      setState(() => resultText = "No patch data – map not calibrated");
      return;
    }

    // Jump filter
    if (lastX != null && lastY != null) {
      final d = sqrt(pow(x - lastX!, 2) + pow(y - lastY!, 2));
      if (d > 40) {
        debugPrint("Jump $d > 40 – ignored");
        return;
      }
    }

    // Smooth
    if (lastX != null && lastY != null) {
      x = lastX! + (x - lastX!) * 0.3;
      y = lastY! + (y - lastY!) * 0.3;

      const maxStep = 10.0;
      final dx = x - lastX!;
      final dy = y - lastY!;
      final step = sqrt(dx * dx + dy * dy);
      if (step > maxStep) {
        x = lastX! + (dx / step) * maxStep;
        y = lastY! + (dy / step) * maxStep;
      }
    }

    lastX = x;
    lastY = y;

    final yShifted = y + 18;
    final coords = localToGlobal(x, yShifted);

    userMarker = Marker(
      point: LatLng(coords[0], coords[1]),
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
    setState(() {});
  }

  // ─── Inference helper ───────────────────────────────────────────────────────
  // FIX 12: safe output extraction compatible with onnxruntime 1.x API
  (double, double)? _runInference(List<double> featureVector) {
    if (session == null) {
      debugPrint("Session is null – model not loaded");
      return null;
    }

    final inputName = session!.inputNames.first; // usually 'float_input'

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(featureVector),
      [1, featureVector.length],
    );

    try {
      final outputs = session!.run(
        OrtRunOptions(),
        {inputName: inputTensor},
      );

      // FIX 13: onnxruntime value is List<List<double>> for shape [1,2]
      final raw = outputs.first?.value;
      if (raw == null) return null;

      // Handle both possible return shapes from onnxruntime
      double x, y;
      if (raw is List && raw.isNotEmpty && raw[0] is List) {
        x = (raw[0][0] as num).toDouble();
        y = (raw[0][1] as num).toDouble();
      } else if (raw is List && raw.length >= 2) {
        x = (raw[0] as num).toDouble();
        y = (raw[1] as num).toDouble();
      } else {
        debugPrint("Unexpected output shape: $raw");
        return null;
      }

      // Clean up
      for (final o in outputs) o?.release();
      return (x, y);
    } finally {
      inputTensor.release();
    }
  }

  // ─── Simulation ─────────────────────────────────────────────────────────────
  Future<void> startSimulation() async {
    if (floorBeaconOrders.isEmpty) {
      setState(() => resultText = "Beacon order not loaded yet. Wait...");
      return;
    }
    if (session == null) {
      setState(() => resultText = "Model not loaded yet. Wait...");
      return;
    }

    simulatedData = await loadCSVTimedData();
    if (simulatedData.isEmpty) {
      setState(() => resultText = "CSV has no data");
      return;
    }

    currentStep = 0;
    lastX = null;
    lastY = null;
    kalmanX = KalmanFilter();
    kalmanY = KalmanFilter();

    simulationTimer?.cancel();
    simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (currentStep >= simulatedData.length) {
        timer.cancel();
        setState(() => resultText = "Simulation complete ✓");
        return;
      }
      processStep(simulatedData[currentStep]);
      currentStep++;
    });
  }

  void processStep(Map<String, List<int>> stepData) {
    // FIX 14: guard missing floor in beacon orders
    final beaconOrder = floorBeaconOrders[selectedFloor];
    if (beaconOrder == null) {
      debugPrint("No beacon order for floor $selectedFloor");
      setState(() => resultText = "No beacon order for floor $selectedFloor");
      return;
    }

    final featureVector = <double>[];

    for (final beacon in beaconOrder) {
      if (stepData.containsKey(beacon)) {
        List<int> values = List.of(stepData[beacon]!);

        // Trim outliers if enough samples
        values.sort();
        if (values.length > 4) {
          values = values.sublist(1, values.length - 1);
        }

        final avg = values.reduce((a, b) => a + b) / values.length;
        featureVector.add(avg);
      } else {
        featureVector.add(-110.0); // unseen beacon
      }
    }

    final result = _runInference(featureVector);
    if (result == null) return;

    double newX = result.$1;
    double newY = result.$2;

    // Kalman smooth
    newX = kalmanX.update(newX);
    newY = kalmanY.update(newY);

    // Weighted interpolation
    if (lastX != null && lastY != null) {
      newX = lastX! + (newX - lastX!) * 0.25;
      newY = lastY! + (newY - lastY!) * 0.25;
    }

    updateUserPosition(newX, newY);

    setState(() {
      resultText =
      "Step $currentStep / ${simulatedData.length}\nX: ${newX.toStringAsFixed(2)}  Y: ${newY.toStringAsFixed(2)}";
    });
  }

  void stopSimulation() {
    simulationTimer?.cancel();
    setState(() => resultText = "Stopped");
  }

  // ─── Realtime BLE scanning ──────────────────────────────────────────────────
  Future<void> scanAndPredict() async {
    if (session == null) return;

    await requestPermissions();
    scannedBeacons.clear();

    await LocalizationEngine.startScanning(
      venueName: "IITDelhi",
      immediateEmit: true,
    );

    final sub = LocalizationEngine.scanResultsForAllBeacons.listen((event) {
      if (event == null) return;
      final beaconData = Map<String, dynamic>.from(event);
      beaconData.forEach((key, value) {
        final name = key.toUpperCase();
        if (!name.startsWith("IW")) return;
        final readings = List<MapEntry<DateTime, int>>.from(value);
        for (final entry in readings) {
          scannedBeacons.putIfAbsent(name, () => []);
          scannedBeacons[name]!.add(entry.value);
        }
      });
    });

    await Future.delayed(const Duration(seconds: 3));
    await LocalizationEngine.stopScanning();
    await sub.cancel();

    final beaconOrder = floorBeaconOrders[selectedFloor];
    if (beaconOrder == null) return;

    final featureVector = beaconOrder.map((beacon) {
      if (scannedBeacons.containsKey(beacon)) {
        final vals = scannedBeacons[beacon]!;
        return vals.reduce((a, b) => a + b) / vals.length;
      }
      return -110.0;
    }).toList();

    final result = _runInference(featureVector);
    if (result == null) return;

    double x = result.$1;
    double y = result.$2;

    if (lastX != null && lastY != null) {
      x = lastX! + (x - lastX!) * 0.3;
      y = lastY! + (y - lastY!) * 0.3;
    }

    updateUserPosition(x, y);
    setState(() {
      resultText = "X: ${x.toStringAsFixed(2)}\nY: ${y.toStringAsFixed(2)}";
    });
  }

  void startRealtimePositioning() {
    if (realtimeTimer != null) return;
    realtimeTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => scanAndPredict());
    setState(() => resultText = "Real-time scanning...");
  }

  void stopRealtimePositioning() {
    realtimeTimer?.cancel();
    realtimeTimer = null;
    setState(() => resultText = "Stopped");
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE Indoor Localization")),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(buildingLat, buildingLon),
                initialZoom: 20,
              ),
              children: [
                PolygonLayer(polygons: polygons),
                if (userMarker != null) MarkerLayer(markers: [userMarker!]),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Floor selector
                Row(
                  children: [
                    const Text("Floor: ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<int>(
                      value: selectedFloor,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text("Floor 0")),
                        DropdownMenuItem(value: 1, child: Text("Floor 1")),
                        DropdownMenuItem(value: 2, child: Text("Floor 2")),
                        DropdownMenuItem(value: 3, child: Text("Floor 3")),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() {
                          selectedFloor = value;
                          resultText = "Loading floor $value model...";
                        });
                        await loadModel();
                        drawFloor(selectedFloor);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Status text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(resultText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13)),
                ),

                const SizedBox(height: 10),

                // Simulation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: startSimulation,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Simulate Walk"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: stopSimulation,
                      icon: const Icon(Icons.stop),
                      label: const Text("Stop"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade300),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Real-time buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: startRealtimePositioning,
                      icon: const Icon(Icons.bluetooth_searching),
                      label: const Text("Start Live"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: stopRealtimePositioning,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text("Stop Live"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade300),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}