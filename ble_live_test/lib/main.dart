// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:onnxruntime/onnxruntime.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:localization_engine/localization_engine.dart';
// import 'package:sensors_plus/sensors_plus.dart'; // NEW: for barometer (altitude)
// import 'package:geolocator/geolocator.dart';     // NEW: for GPS/accuracy fused signal
//
// import 'dart:async';
// import 'dart:typed_data';
// import 'dart:convert';
// import 'dart:math';
// import 'package:http/http.dart' as http;
// import 'package:flutter/services.dart' show rootBundle;
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Kalman Filter — used for X, Y, and GPS-confidence-weighted fusion
// // q=0.02: low process noise → smooth path
// // r=8.0 : high measurement noise → don't chase every RSSI twitch
// // ─────────────────────────────────────────────────────────────────────────────
// class KalmanFilter {
//   final double q;
//   final double r;
//   double? x;
//   double p = 1;
//   double k = 0;
//
//   KalmanFilter({this.q = 0.02, this.r = 8.0});
//
//   double update(double measurement) {
//     if (x == null) { x = measurement; return x!; }
//     p += q;
//     k = p / (p + r);
//     x = x! + k * (measurement - x!);
//     p = (1 - k) * p;
//     return x!;
//   }
//
//   void reset() { x = null; p = 1; k = 0; }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // GPS + Barometer fusion state
// // Holds the latest GPS fix and barometric altitude so inference can
// // use them as auxiliary features for better accuracy.
// // ─────────────────────────────────────────────────────────────────────────────
// class _SensorState {
//   // GPS
//   double? gpsLat;
//   double? gpsLon;
//   double  gpsAccuracy   = 999.0; // metres — lower is better
//   bool    gpsAvailable  = false;
//
//   // Barometer / pressure → altitude (metres above sea level)
//   // Floor 0 ≈ 194–210 m, Floor 1 ≈ 194–213 m, Floor 2 ≈ 201–204 m, Floor 3 ≈ 197–206 m
//   double? baroAltitude;
//
//   // Derived: GPS-to-local-coordinate (filled when GPS accuracy ≤ gpsGoodThresh)
//   double? gpsLocalX;
//   double? gpsLocalY;
//
//   // GPS trust: accuracy ≤ 5 m → fully trust GPS anchor, > 20 m → ignore it
//   static const double gpsGoodThresh = 5.0;
//   static const double gpsBadThresh  = 20.0;
//
//   // Returns 0.0 (ignore) … 1.0 (fully trust) based on GPS accuracy
//   double get gpsTrustWeight {
//     if (!gpsAvailable || gpsAccuracy >= gpsBadThresh) return 0.0;
//     if (gpsAccuracy <= gpsGoodThresh) return 1.0;
//     return 1.0 - (gpsAccuracy - gpsGoodThresh) / (gpsBadThresh - gpsGoodThresh);
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Constants
// //
// // SCAN APPROACH — SLIDING WINDOW for ~1 s updates:
// //   Instead of a hard stop-scan / wait / restart cycle, we keep scanning
// //   continuously and snapshot the last _windowSeconds of readings every
// //   _updateInterval seconds.  This gives a fresh inference every second
// //   while using 2 s of RSSI history for averaging — much smoother than
// //   the 3 s cold-start cycle.
// //
// // GPS FUSION:
// //   When GPS accuracy is good (< 5 m), the BLE-predicted local (X,Y) is
// //   blended toward the GPS-derived local position proportionally to
// //   gpsTrustWeight.  When GPS is poor (> 20 m), only BLE is used.
// //   GPS accuracy is also used as a feature hint: very high accuracy
// //   signals the user may be near an exterior wall → downweight that cycle.
// //
// // ALTITUDE:
// //   Barometric altitude disambiguates floors at scan start.  Each floor
// //   has a distinct altitude band (from cleaned_data.xlsx):
// //     Floor 0/1: 193–213 m   Floor 2: 200–204 m   Floor 3: 197–206 m
// //   If the baro reading strongly contradicts the selected floor a warning
// //   is shown so the user knows to switch.
// // ─────────────────────────────────────────────────────────────────────────────
// const double _missingRssi     = -100.0;
// const int    _windowSeconds   = 2;          // rolling RSSI history window
// const int    _updateIntervalMs = 1000;      // emit new position every 1 s
// const int    _sparseThresh    = 2;          // min beacons to apply Kalman
// const double _jumpThreshold   = 80.0;       // local units — filters teleports
//
// // Altitude bands per floor (from data analysis)
// const Map<int, Map<String, double>> _floorAltitudeBands = {
//   0: {"min": 193.0, "max": 213.0},
//   1: {"min": 193.0, "max": 213.0},
//   2: {"min": 200.5, "max": 204.5},
//   3: {"min": 197.0, "max": 206.5},
// };
//
// Future<void> requestPermissions() async {
//   await Permission.location.request();
//   await Permission.bluetoothScan.request();
//   await Permission.bluetoothConnect.request();
// }
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   OrtEnv.instance.init();
//   await requestPermissions();
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) => MaterialApp(
//     debugShowCheckedModeBanner: false,
//     theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
//     home: const HomePage(),
//   );
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// class HomePage extends StatefulWidget {
//   const HomePage({super.key});
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   int    selectedFloor = 3;
//   bool   isScanning    = false;
//   bool   modelReady    = false;
//   String statusText    = "Initialising…";
//   int    beaconsSeen   = 0;
//   String coordText     = "";
//   String signalText    = "";        // NEW: shows fused signal info
//
//   double? lastX, lastY;
//   KalmanFilter kalmanX = KalmanFilter();
//   KalmanFilter kalmanY = KalmanFilter();
//
//   // NEW: sensor state
//   final _SensorState _sensors = _SensorState();
//   StreamSubscription? _gpsSub;
//   StreamSubscription? _baroSub;
//
//   OrtSession?            session;
//   bool                   _modelLoading = false;
//   Map<int, List<String>> floorBeaconOrders = {};
//   Map<String, dynamic>?  patchData;
//   Map<String, dynamic>?  geoJsonData;
//
//   final MapController    _mapController = MapController();
//   final double buildingLat = 28.5436;
//   final double buildingLon = 77.1874;
//   List<Polygon> polygons  = [];
//   Marker?       userMarker;
//
//   // NEW: continuous BLE scan state (sliding window)
//   bool _scanRunning = false;
//   StreamSubscription? _bleSub;
//   // Rolling buffer: beacon name → list of (timestamp, rssi)
//   final Map<String, List<({DateTime ts, int rssi})>> _rssiBuffer = {};
//   Timer? _updateTimer;          // fires every _updateIntervalMs to run inference
//
//   @override
//   void initState() {
//     super.initState();
//     _boot();
//   }
//
//   @override
//   void dispose() {
//     _stopScanning();
//     _gpsSub?.cancel();
//     _baroSub?.cancel();
//     session?.release();
//     OrtEnv.instance.release();
//     LocalizationEngine.dispose();
//     super.dispose();
//   }
//
//   Future<void> _boot() async {
//     _setStatus("Loading beacon map…");
//     await _loadBeaconOrders();
//     _setStatus("Loading model…");
//     await _loadModel();
//     _setStatus("Loading floor map…");
//     await _fetchPatchData();
//     await _loadGeoJson();
//     _setStatus("Starting sensors…");
//     await _startSensors();         // NEW
//     _setStatus("Ready — tap ▶ to start");
//     setState(() => modelReady = true);
//   }
//
//   void _setStatus(String s) => setState(() => statusText = s);
//
//   // ─── NEW: Start GPS + Barometer ──────────────────────────────────────────
//   Future<void> _startSensors() async {
//     // GPS — continuous low-power updates
//     try {
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       LocationPermission perm = await Geolocator.checkPermission();
//       if (serviceEnabled && perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
//         _gpsSub = Geolocator.getPositionStream(
//           locationSettings: const LocationSettings(
//             accuracy: LocationAccuracy.best,
//             distanceFilter: 1, // update every 1 metre
//           ),
//         ).listen(_onGpsUpdate, onError: (e) {
//           debugPrint("GPS stream error: $e");
//         });
//         debugPrint("GPS stream started");
//       } else {
//         debugPrint("GPS unavailable or permission denied");
//       }
//     } catch (e) {
//       debugPrint("GPS init error: $e — continuing without GPS");
//     }
//
//     // Barometer disabled — sensors_plus_platform_interface v2 (currently installed)
//     // does not expose barometerEvents. Upgrade to platform_interface v3+ to enable.
//     // For now, baroAltitude stays null and _checkFloorHint() uses BLE-only floor detection.
//     debugPrint("Barometer skipped (platform interface <3.0)");
//   }
//
//   void _onGpsUpdate(Position pos) {
//     _sensors.gpsLat      = pos.latitude;
//     _sensors.gpsLon      = pos.longitude;
//     _sensors.gpsAccuracy = pos.accuracy;
//     _sensors.gpsAvailable = true;
//
//     // Convert GPS global → local coordinates using existing patchData / linear fallback
//     // This gives us a GPS-derived (X,Y) to blend with BLE prediction.
//     if (_sensors.gpsTrustWeight > 0) {
//       final local = _globalToLocal(pos.latitude, pos.longitude);
//       if (local != null) {
//         _sensors.gpsLocalX = local[0];
//         _sensors.gpsLocalY = local[1];
//       }
//     }
//
//     if (mounted) {
//       setState(() {
//         signalText = "GPS ±${pos.accuracy.toStringAsFixed(1)} m"
//             "${_sensors.baroAltitude != null ? "  •  Alt ${_sensors.baroAltitude!.toStringAsFixed(0)} m" : ""}";
//       });
//     }
//   }
//
//   // ─── NEW: Floor hint from barometric altitude ────────────────────────────
//   void _checkFloorHint() {
//     final alt = _sensors.baroAltitude;
//     if (alt == null || !isScanning) return;
//
//     final band = _floorAltitudeBands[selectedFloor];
//     if (band == null) return;
//
//     // If altitude is clearly outside the current floor's band, show a hint
//     if (alt < band["min"]! - 2.0 || alt > band["max"]! + 2.0) {
//       // Find the best matching floor
//       int bestFloor = selectedFloor;
//       double bestDist = double.infinity;
//       for (final entry in _floorAltitudeBands.entries) {
//         final mid = (entry.value["min"]! + entry.value["max"]!) / 2.0;
//         final dist = (alt - mid).abs();
//         if (dist < bestDist) { bestDist = dist; bestFloor = entry.key; }
//       }
//       if (bestFloor != selectedFloor && mounted) {
//         _setStatus("⚠ Altitude ${alt.toStringAsFixed(0)} m → Floor $bestFloor? Tap to switch");
//       }
//     }
//   }
//
//   // ─── NEW: Global GPS → local (X,Y) inverse transform ────────────────────
//   // This is the reverse of _localToGlobal.  Used to convert a GPS fix
//   // into local coordinates so it can be blended with BLE-predicted position.
//   List<double>? _globalToLocal(double lat, double lon) {
//     try {
//       final b = _floorBounds[selectedFloor];
//       if (b == null) return null;
//       final tX = ((lon - b["lonMin"]!) / (b["lonMax"]! - b["lonMin"]!)).clamp(0.0, 1.0);
//       final tY = ((lat - b["latMin"]!) / (b["latMax"]! - b["latMin"]!)).clamp(0.0, 1.0);
//       final x = b["xMin"]! + tX * (b["xMax"]! - b["xMin"]!);
//       final y = b["yMin"]! + tY * (b["yMax"]! - b["yMin"]!);
//       return [x, y];
//     } catch (_) { return null; }
//   }
//
//   Future<void> _loadBeaconOrders() async {
//     try {
//       final raw = await rootBundle.loadString('assets/data/floor_beacon_order.json');
//       final Map<String, dynamic> j = json.decode(raw);
//       floorBeaconOrders = j.map((k, v) => MapEntry(
//         int.parse(k),
//         List<String>.from(v).map((e) => e.trim().toUpperCase()).toList(),
//       ));
//       debugPrint("Beacon orders: ${floorBeaconOrders.map((k, v) => MapEntry(k, v.length))}");
//     } catch (e) { debugPrint("loadBeaconOrders error: $e"); }
//   }
//
//   Future<void> _loadModel() async {
//     if (_modelLoading) return;
//     _modelLoading = true;
//     try {
//       session?.release();
//       session = null;
//       final raw = await rootBundle.load("assets/model/floor${selectedFloor}_model.onnx");
//       session = OrtSession.fromBuffer(raw.buffer.asUint8List(), OrtSessionOptions());
//       debugPrint("Model loaded — floor $selectedFloor  "
//           "in:${session!.inputNames}  out:${session!.outputNames}");
//     } catch (e) {
//       debugPrint("loadModel error: $e");
//       _setStatus("Model load failed: $e");
//     } finally { _modelLoading = false; }
//   }
//
//   Future<void> _fetchPatchData() async {
//     try {
//       final res = await http.post(
//         Uri.parse("https://dev.iwayplus.in/secured/patch/get"
//             "?api_key=7cc62870-d67e-11f0-91ed-2f0eb903e7db"),
//         headers: {"Content-Type": "application/json"},
//         body: json.encode({
//           "id": "65d887a5db333f89457145f6",
//           "manufacturer": "android",
//           "devicemodel": "moto g64",
//         }),
//       ).timeout(const Duration(seconds: 8));
//       if (res.statusCode == 200) {
//         patchData = json.decode(res.body);
//         debugPrint("Patch loaded: ${patchData!.keys}");
//       }
//     } catch (e) {
//       debugPrint("fetchPatchData error: $e");
//     }
//   }
//
//   Future<void> _loadGeoJson() async {
//     try {
//       final raw = await rootBundle.loadString('assets/maps/converted_geojson.geojson');
//       geoJsonData = json.decode(raw);
//       _drawFloor(selectedFloor);
//     } catch (e) { debugPrint("loadGeoJson error: $e"); }
//   }
//
//   void _drawFloor(int floor) {
//     if (geoJsonData == null) return;
//     final List<Polygon> built = [];
//     for (final f in geoJsonData!["features"]) {
//       if (f["properties"]["floor"] != floor) continue;
//       final geom = f["geometry"];
//       if (geom == null) continue;
//       if (geom["type"] == "LineString" || geom["type"] == "Point") continue;
//       if (geom["coordinnatesLocal"] == null) continue;
//       final List<LatLng> pts = [];
//       for (final c in geom["coordinnatesLocal"][0]) {
//         if (c == null || (c is List && c.isEmpty)) continue;
//         try {
//           final g = _localToGlobal((c[0] as num).toDouble(), (c[1] as num).toDouble());
//           pts.add(LatLng(g[0], g[1]));
//         } catch (_) {}
//       }
//       if (pts.length >= 3) {
//         built.add(Polygon(
//           points: pts,
//           color: Colors.indigo.withOpacity(0.15),
//           borderColor: Colors.indigo.withOpacity(0.6),
//           borderStrokeWidth: 1.2,
//         ));
//       }
//     }
//     setState(() => polygons = built);
//   }
//
//   // ─── Coordinate helpers ───────────────────────────────────────────────────
//   double _dist(Map<String, double> a, Map<String, double> b) {
//     final dx = a["localx"]! - b["localx"]!;
//     final dy = a["localy"]! - b["localy"]!;
//     return sqrt(dx * dx + dy * dy);
//   }
//
//   Map<String, double> _obtainCoords(Map<String, double> base, double ver, double hor) => {
//     "lat": base["lat"]! + (ver / 111320),
//     "lon": base["lon"]! + (hor / (111320 * cos(base["lat"]! * pi / 180))),
//   };
//
//   double _haversine(Map<String, double> a, Map<String, double> b) {
//     const R = 6371.0;
//     final dLat = (b["lat"]! - a["lat"]!) * pi / 180;
//     final dLon = (b["lon"]! - a["lon"]!) * pi / 180;
//     final arc = sin(dLat / 2) * sin(dLat / 2) +
//         cos(a["lat"]! * pi / 180) * cos(b["lat"]! * pi / 180) *
//             sin(dLon / 2) * sin(dLon / 2);
//     return R * 2 * atan2(sqrt(arc), sqrt(1 - arc)) * 1000;
//   }
//
//   // Floor coordinate bounds derived from cleaned_data.xlsx
//   static const Map<int, Map<String, double>> _floorBounds = {
//     0: {"xMin": 9,  "xMax": 264, "yMin": 48,  "yMax": 220,
//       "latMin": 28.542762, "latMax": 28.544040,
//       "lonMin": 77.186632, "lonMax": 77.188651},
//     1: {"xMin": 9,  "xMax": 243, "yMin": 24,  "yMax": 244,
//       "latMin": 28.542977, "latMax": 28.543612,
//       "lonMin": 77.186956, "lonMax": 77.187948},
//     2: {"xMin": 17, "xMax": 241, "yMin": 24,  "yMax": 228,
//       "latMin": 28.543036, "latMax": 28.543689,
//       "lonMin": 77.187149, "lonMax": 77.187945},
//     3: {"xMin": 8,  "xMax": 203, "yMin": 17,  "yMax": 243,
//       "latMin": 28.542979, "latMax": 28.543876,
//       "lonMin": 77.187217, "lonMax": 77.187930},
//   };
//
//   List<double> _linearLocalToGlobal(double x, double y) {
//     final b = _floorBounds[selectedFloor]!;
//     final tX = ((x - b["xMin"]!) / (b["xMax"]! - b["xMin"]!)).clamp(0.0, 1.0);
//     final tY = ((y - b["yMin"]!) / (b["yMax"]! - b["yMin"]!)).clamp(0.0, 1.0);
//     final lat = b["latMin"]! + tY * (b["latMax"]! - b["latMin"]!);
//     final lon = b["lonMin"]! + tX * (b["lonMax"]! - b["lonMin"]!);
//     return [lat, lon];
//   }
//
//   List<double> _localToGlobal(double x, double y) {
//     if (patchData != null) {
//       try {
//         final coords = patchData!["patchData"]["coordinates"] as List;
//         final ref = [
//           {"lat": double.parse(coords[2]["globalRef"]["lat"]), "lon": double.parse(coords[2]["globalRef"]["lng"]), "localx": double.parse(coords[2]["localRef"]["lng"]), "localy": double.parse(coords[2]["localRef"]["lat"])},
//           {"lat": double.parse(coords[1]["globalRef"]["lat"]), "lon": double.parse(coords[1]["globalRef"]["lng"]), "localx": double.parse(coords[1]["localRef"]["lng"]), "localy": double.parse(coords[1]["localRef"]["lat"])},
//           {"lat": double.parse(coords[0]["globalRef"]["lat"]), "lon": double.parse(coords[0]["globalRef"]["lng"]), "localx": double.parse(coords[0]["localRef"]["lng"]), "localy": double.parse(coords[0]["localRef"]["lat"])},
//           {"lat": double.parse(coords[3]["globalRef"]["lat"]), "lon": double.parse(coords[3]["globalRef"]["lng"]), "localx": double.parse(coords[3]["localRef"]["lng"]), "localy": double.parse(coords[3]["localRef"]["lat"])},
//         ];
//
//         int leastLat = 0;
//         for (int i = 0; i < ref.length; i++) {
//           if (ref[i]["lat"] == ref[leastLat]["lat"]) {
//             if (ref[i]["lon"]! > ref[leastLat]["lon"]!) leastLat = i;
//           } else if (ref[i]["lat"]! < ref[leastLat]["lat"]!) leastLat = i;
//         }
//         final c1     = leastLat == 3 ? 0 : leastLat + 1;
//         final c2     = leastLat == 0 ? 3 : leastLat - 1;
//         final highLon = ref[c1]["lon"]! > ref[c2]["lon"]! ? c1 : c2;
//
//         final b      = _haversine(ref[leastLat], ref[highLon]);
//         final horiz  = _obtainCoords(ref[leastLat], 0, b);
//         final c      = _haversine(ref[leastLat], horiz);
//         final a      = _haversine(ref[highLon], horiz);
//
//         final cosVal = ((b * b + c * c - a * a) / (2 * b * c)).clamp(-1.0, 1.0);
//         final out    = acos(cosVal) * 180 / pi;
//
//         final localRef = {"localx": x, "localy": y};
//         final l = _dist(ref[leastLat], ref[highLon]);
//         final m = _dist(localRef, ref[highLon]);
//         final n = _dist(ref[leastLat], localRef);
//
//         double theta = 0;
//         if (l > 0 && n > 0 && m > 0) {
//           final ct = ((l * l + n * n - m * m) / (2 * l * n)).clamp(-1.0, 1.0);
//           theta = acos(ct) * 180 / pi;
//         }
//
//         final ang  = theta + out;
//         final dist = _dist(ref[leastLat], localRef) * 0.3048;
//         final ver  = dist * sin(ang * pi / 180.0);
//         final hor  = dist * cos(ang * pi / 180.0);
//         final fc   = _obtainCoords(ref[leastLat], ver, hor);
//
//         final latOk = fc["lat"]! > 28.540 && fc["lat"]! < 28.547;
//         final lonOk = fc["lon"]! > 77.185 && fc["lon"]! < 77.191;
//         if (latOk && lonOk) return [fc["lat"]!, fc["lon"]!];
//         debugPrint("localToGlobal: out of bounds, using linear fallback");
//       } catch (e) {
//         debugPrint("localToGlobal patch error: $e — using linear fallback");
//       }
//     }
//     return _linearLocalToGlobal(x, y);
//   }
//
//   // ─── Inference ────────────────────────────────────────────────────────────
//   (double, double)? _runInference(List<double> features) {
//     if (session == null) return null;
//     final inputName = session!.inputNames.first;
//     final tensor = OrtValueTensor.createTensorWithDataList(
//       Float32List.fromList(features),
//       [1, features.length],
//     );
//     List<OrtValue?>? outputs;
//     try {
//       outputs = session!.run(OrtRunOptions(), {inputName: tensor});
//       final raw = outputs.first?.value;
//       if (raw == null) return null;
//
//       double x, y;
//       if (raw is List && raw.isNotEmpty && raw[0] is List) {
//         final inner = raw[0] as List;
//         if (inner.length < 2) return null;
//         x = (inner[0] as num).toDouble();
//         y = (inner[1] as num).toDouble();
//       } else if (raw is List && raw.length >= 2) {
//         x = (raw[0] as num).toDouble();
//         y = (raw[1] as num).toDouble();
//       } else {
//         debugPrint("Unexpected model output: ${raw.runtimeType}");
//         return null;
//       }
//       debugPrint("Inference raw → x=$x, y=$y");
//       return (x, y);
//     } catch (e) {
//       debugPrint("Inference error: $e");
//       return null;
//     } finally {
//       tensor.release();
//       if (outputs != null) { for (final o in outputs) { try { o?.release(); } catch (_) {} } }
//     }
//   }
//
//   // ─── Position update with GPS fusion ──────────────────────────────────────
//   // NEW: blends BLE-predicted (bleX, bleY) with GPS-derived local (gpsX, gpsY)
//   // weighted by GPS accuracy trust score.
//   void _updatePosition(double bleX, double bleY) {
//     double x = bleX;
//     double y = bleY;
//
//     // GPS fusion: blend toward GPS-derived position proportionally to trust
//     final gpsW = _sensors.gpsTrustWeight;
//     if (gpsW > 0 && _sensors.gpsLocalX != null && _sensors.gpsLocalY != null) {
//       x = (1.0 - gpsW) * bleX + gpsW * _sensors.gpsLocalX!;
//       y = (1.0 - gpsW) * bleY + gpsW * _sensors.gpsLocalY!;
//       debugPrint("GPS fusion w=$gpsW  BLE=($bleX,$bleY)  GPS=(${_sensors.gpsLocalX},${_sensors.gpsLocalY})  fused=($x,$y)");
//     }
//
//     // Jump filter
//     if (lastX != null && lastY != null) {
//       final d = sqrt(pow(x - lastX!, 2) + pow(y - lastY!, 2));
//       if (d > _jumpThreshold) {
//         debugPrint("Jump $d > $_jumpThreshold — skipped");
//         return;
//       }
//     }
//     lastX = x;
//     lastY = y;
//
//     final g = _localToGlobal(x, y);
//     final newPoint = LatLng(g[0], g[1]);
//
//     setState(() {
//       userMarker = Marker(
//         point: newPoint,
//         width: 32,
//         height: 32,
//         child: _PulsingDot(),
//       );
//       coordText = "X: ${x.toStringAsFixed(1)}  Y: ${y.toStringAsFixed(1)}";
//     });
//
//     try { _mapController.move(newPoint, _mapController.camera.zoom); } catch (_) {}
//   }
//
//   // ─── Continuous BLE scan (sliding window) ─────────────────────────────────
//   // CHANGED: Instead of stop/start cycles we keep one scan running permanently
//   // and snapshot the rolling buffer every _updateIntervalMs.
//   void _startScanning() {
//     if (isScanning || !modelReady) return;
//     setState(() {
//       isScanning = true;
//       statusText = "Scanning…";
//       lastX = null;
//       lastY = null;
//       kalmanX.reset();
//       kalmanY.reset();
//       _rssiBuffer.clear();
//     });
//     _startBleStream();
//     // Emit a new position every second
//     _updateTimer = Timer.periodic(
//         Duration(milliseconds: _updateIntervalMs), (_) => _emitPosition());
//   }
//
//   void _stopScanning() {
//     _updateTimer?.cancel();
//     _updateTimer = null;
//     _bleSub?.cancel();
//     _bleSub = null;
//     _scanRunning = false;
//     LocalizationEngine.stopScanning().catchError((_) {});
//     if (mounted) setState(() { isScanning = false; statusText = "Stopped"; });
//   }
//
//   // Starts the BLE engine and a persistent listener that feeds _rssiBuffer
//   Future<void> _startBleStream() async {
//     if (_scanRunning) return;
//     try {
//       await LocalizationEngine.startScanning(
//         venueName: "IITDelhi",
//         immediateEmit: true,
//       );
//       _scanRunning = true;
//
//       await _bleSub?.cancel();
//       _bleSub = LocalizationEngine.scanResultsForAllBeacons.listen((event) {
//         if (event == null) return;
//         final now = DateTime.now();
//         final Map<String, dynamic> data = Map<String, dynamic>.from(event);
//         data.forEach((key, value) {
//           final name = key.trim().toUpperCase();
//           if (!name.startsWith("IW")) return;
//           final readings = List<MapEntry<DateTime, int>>.from(value);
//           final buf = _rssiBuffer.putIfAbsent(name, () => []);
//           for (final r in readings) { buf.add((ts: r.key, rssi: r.value)); }
//         });
//         // Prune old entries (keep last _windowSeconds)
//         final cutoff = now.subtract(Duration(seconds: _windowSeconds));
//         _rssiBuffer.forEach((k, v) => v.removeWhere((e) => e.ts.isBefore(cutoff)));
//       });
//     } catch (e) {
//       debugPrint("BLE stream start error: $e");
//       _scanRunning = false;
//     }
//   }
//
//   // Called every second — builds feature vector from current window and runs inference
//   void _emitPosition() {
//     if (!isScanning || !mounted) return;
//     final beaconOrder = floorBeaconOrders[selectedFloor];
//     if (beaconOrder == null || session == null) return;
//
//     // Prune stale readings from buffer before building features
//     final cutoff = DateTime.now().subtract(Duration(seconds: _windowSeconds));
//     _rssiBuffer.forEach((k, v) => v.removeWhere((e) => e.ts.isBefore(cutoff)));
//
//     int seen = 0;
//     final features = beaconOrder.map((b) {
//       final buf = _rssiBuffer[b];
//       if (buf != null && buf.isNotEmpty) {
//         final vals = buf.map((e) => e.rssi).toList()..sort();
//         final trimmed = vals.length > 4 ? vals.sublist(1, vals.length - 1) : vals;
//         seen++;
//         return trimmed.reduce((a, b) => a + b) / trimmed.length;
//       }
//       return _missingRssi;
//     }).toList();
//
//     // Append 2 sensor features: altitude (m) + GPS accuracy (m)
//     // Must match training feature layout: [beacon_0..beacon_N, altitude_m, gps_accuracy_m]
//     // Fallback altitudes = median from training data per floor (barometer unavailable)
//     const _floorAltFallback = {0: 194.2, 1: 197.4, 2: 201.1, 3: 204.7};
//     const _floorAccFallback = {0: 5.5,   1: 16.3,  2: 13.8,  3: 14.9};
//     final altVal = _sensors.baroAltitude
//         ?? _floorAltFallback[selectedFloor]
//         ?? 200.0;
//     // Cap GPS accuracy to training max (124m) so model never sees out-of-range values
//     final accVal = _sensors.gpsAvailable
//         ? _sensors.gpsAccuracy.clamp(0.0, 124.0)
//         : (_floorAccFallback[selectedFloor] ?? 15.0);
//     features.add(altVal);
//     features.add(accVal);
//
//     debugPrint("Emit: $seen/${beaconOrder.length} beacons  floor=$selectedFloor");
//
//     if (seen == 0) {
//       if (mounted) setState(() => statusText = "No beacons — moving?");
//       return;
//     }
//
//     final result = _runInference(features);
//     if (result == null) return;
//
//     double x, y;
//     if (seen >= _sparseThresh) {
//       x = kalmanX.update(result.$1);
//       y = kalmanY.update(result.$2);
//     } else {
//       kalmanX.update(result.$1);
//       kalmanY.update(result.$2);
//       x = result.$1;
//       y = result.$2;
//     }
//
//     if (mounted) {
//       _updatePosition(x, y);
//       setState(() { beaconsSeen = seen; });
//
//       // Status line: show GPS fusion status
//       final gpsW = _sensors.gpsTrustWeight;
//       final gpsStr = gpsW > 0
//           ? " · GPS ${(gpsW * 100).toInt()}% weight"
//           : (_sensors.gpsAvailable ? " · GPS weak" : "");
//       final altStr = _sensors.baroAltitude != null
//           ? " · ${_sensors.baroAltitude!.toStringAsFixed(0)} m"
//           : "";
//       _setStatus("Live · $seen beacon${seen == 1 ? '' : 's'}$gpsStr$altStr");
//     }
//   }
//
//   Future<void> _changeFloor(int floor) async {
//     if (isScanning) _stopScanning();
//     setState(() {
//       selectedFloor = floor;
//       statusText    = "Loading floor $floor…";
//       modelReady    = false;
//       lastX = null;
//       lastY = null;
//       kalmanX.reset();
//       kalmanY.reset();
//       userMarker = null;
//       coordText  = "";
//       _rssiBuffer.clear();  // clear old floor's RSSI data
//     });
//     await _loadModel();
//     _drawFloor(floor);
//     setState(() {
//       modelReady = true;
//       statusText = "Floor $floor ready — tap ▶ to start";
//     });
//   }
//
//   // ─── Build ────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final mapH = MediaQuery.of(context).size.height * 0.58;
//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F6FA),
//       appBar: AppBar(
//         title: const Text("Indoor Localization",
//             style: TextStyle(fontWeight: FontWeight.w600)),
//         centerTitle: true,
//         elevation: 0,
//         actions: [
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: DropdownButtonHideUnderline(
//               child: DropdownButton<int>(
//                 value: selectedFloor,
//                 style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
//                 items: [0, 1, 2, 3].map((f) => DropdownMenuItem(
//                   value: f, child: Text("Floor $f"),
//                 )).toList(),
//                 onChanged: (v) { if (v != null) _changeFloor(v); },
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           SizedBox(
//             height: mapH,
//             child: ClipRRect(
//               child: FlutterMap(
//                 mapController: _mapController,
//                 options: MapOptions(
//                   initialCenter: LatLng(buildingLat, buildingLon),
//                   initialZoom: 20,
//                 ),
//                 children: [
//                   PolygonLayer(polygons: polygons),
//                   if (userMarker != null) MarkerLayer(markers: [userMarker!]),
//                 ],
//               ),
//             ),
//           ),
//           Expanded(
//             child: Container(
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//                 boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
//               ),
//               padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.stretch,
//                 children: [
//                   Center(
//                     child: Container(
//                       width: 36, height: 4,
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade300,
//                         borderRadius: BorderRadius.circular(2),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       _StatusDot(active: isScanning),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(statusText,
//                             style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
//                       ),
//                       if (beaconsSeen > 0) _BeaconBadge(count: beaconsSeen),
//                     ],
//                   ),
//                   if (coordText.isNotEmpty) ...[
//                     const SizedBox(height: 4),
//                     Text(coordText, style: TextStyle(
//                         fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace')),
//                   ],
//                   // NEW: GPS / sensor info line
//                   if (signalText.isNotEmpty) ...[
//                     const SizedBox(height: 2),
//                     Row(children: [
//                       Icon(Icons.sensors, size: 12, color: Colors.teal.shade400),
//                       const SizedBox(width: 4),
//                       Text(signalText, style: TextStyle(
//                           fontSize: 11, color: Colors.teal.shade600, fontFamily: 'monospace')),
//                     ]),
//                   ],
//                   const Spacer(),
//                   SizedBox(
//                     height: 52,
//                     child: ElevatedButton.icon(
//                       onPressed: modelReady
//                           ? (isScanning ? _stopScanning : _startScanning)
//                           : null,
//                       icon: Icon(isScanning ? Icons.stop_rounded : Icons.my_location_rounded),
//                       label: Text(
//                         isScanning ? "Stop Scanning" : "Start Scanning",
//                         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: isScanning ? Colors.red.shade400 : Colors.indigo,
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//                         elevation: 2,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Helper widgets
// // ─────────────────────────────────────────────────────────────────────────────
//
// class _PulsingDot extends StatefulWidget {
//   @override
//   State<_PulsingDot> createState() => _PulsingDotState();
// }
//
// class _PulsingDotState extends State<_PulsingDot>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _ctrl;
//   late final Animation<double> _anim;
//
//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
//       ..repeat(reverse: true);
//     _anim = Tween(begin: 0.5, end: 1.0).animate(_ctrl);
//   }
//
//   @override
//   void dispose() { _ctrl.dispose(); super.dispose(); }
//
//   @override
//   Widget build(BuildContext context) => AnimatedBuilder(
//     animation: _anim,
//     builder: (_, __) => Container(
//       width: 32, height: 32,
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         color: Colors.indigo.withOpacity(0.2 * _anim.value),
//       ),
//       child: Center(
//         child: Container(
//           width: 16, height: 16,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: Colors.indigo,
//             border: Border.all(color: Colors.white, width: 2.5),
//             boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.4), blurRadius: 6)],
//           ),
//         ),
//       ),
//     ),
//   );
// }
//
// class _StatusDot extends StatelessWidget {
//   final bool active;
//   const _StatusDot({required this.active});
//   @override
//   Widget build(BuildContext context) => Container(
//     width: 10, height: 10,
//     decoration: BoxDecoration(
//       shape: BoxShape.circle,
//       color: active ? Colors.green : Colors.grey.shade400,
//     ),
//   );
// }
//
// class _BeaconBadge extends StatelessWidget {
//   final int count;
//   const _BeaconBadge({required this.count});
//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//     decoration: BoxDecoration(
//       color: Colors.indigo.withOpacity(0.1),
//       borderRadius: BorderRadius.circular(10),
//     ),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         const Icon(Icons.bluetooth, size: 12, color: Colors.indigo),
//         const SizedBox(width: 3),
//         Text("$count", style: const TextStyle(
//             fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w600)),
//       ],
//     ),
//   );
// }
//
//

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:localization_engine/localization_engine.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';

// ─────────────────────────────────────────────────────────────────────────────
// Kalman Filter
// q=0.02: low process noise → smooth path
// r=8.0 : high measurement noise → don't chase every RSSI twitch
// ─────────────────────────────────────────────────────────────────────────────
class KalmanFilter {
  final double q;
  final double r;
  double? x;
  double p = 1;
  double k = 0;

  KalmanFilter({this.q = 0.02, this.r = 8.0});

  double update(double measurement) {
    if (x == null) { x = measurement; return x!; }
    p += q;
    k = p / (p + r);
    x = x! + k * (measurement - x!);
    p = (1 - k) * p;
    return x!;
  }

  void reset() { x = null; p = 1; k = 0; }
}

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const double _missingRssi      = -100.0;
const int    _windowSeconds    = 2;
const int    _updateIntervalMs = 1000;

// Require at least 3 beacons before committing the first fix.
// Prevents the all-missing centroid from anchoring the Kalman filter wrongly.
const int    _sparseThresh       = 3;
const int    _minBeaconsFirstFix = 3;
const double _jumpThreshold      = 80.0;

// Fallback altitude per floor (used when barometer is unavailable)
const Map<int, double> _floorAltFallback = {
  0: 194.2, 1: 197.4, 2: 201.1, 3: 204.7,
};

// Fallback GPS-accuracy value per floor (fed to the model as a constant;
// the model was trained with this feature but we no longer use live GPS).
const Map<int, double> _floorAccFallback = {
  0: 5.5, 1: 16.3, 2: 13.8, 3: 14.9,
};

Future<void> requestPermissions() async {
  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OrtEnv.instance.init();
  await requestPermissions();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const HomePage(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int    selectedFloor = 3;
  bool   isScanning    = false;
  bool   modelReady    = false;
  String statusText    = "Initialising…";
  int    beaconsSeen   = 0;
  String coordText     = "";

  double? lastX, lastY;
  KalmanFilter kalmanX = KalmanFilter();
  KalmanFilter kalmanY = KalmanFilter();

  OrtSession?            session;
  bool                   _modelLoading = false;
  Map<int, List<String>> floorBeaconOrders = {};
  Map<String, dynamic>?  patchData;
  Map<String, dynamic>?  geoJsonData;

  final MapController    _mapController = MapController();
  final double buildingLat = 28.5436;
  final double buildingLon = 77.1874;
  List<Polygon> polygons  = [];
  Marker?       userMarker;

  bool _scanRunning = false;
  StreamSubscription? _bleSub;
  final Map<String, List<({DateTime ts, int rssi})>> _rssiBuffer = {};
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _stopScanning();
    session?.release();
    OrtEnv.instance.release();
    LocalizationEngine.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    _setStatus("Loading beacon map…");
    await _loadBeaconOrders();
    _setStatus("Loading model…");
    await _loadModel();
    _setStatus("Loading floor map…");
    await _fetchPatchData();
    await _loadGeoJson();
    _setStatus("Ready — tap ▶ to start");
    setState(() => modelReady = true);
  }

  void _setStatus(String s) => setState(() => statusText = s);

  // ─── Asset loading ────────────────────────────────────────────────────────
  Future<void> _loadBeaconOrders() async {
    try {
      final raw = await rootBundle.loadString('assets/data/floor_beacon_order.json');
      final Map<String, dynamic> j = json.decode(raw);
      floorBeaconOrders = j.map((k, v) => MapEntry(
        int.parse(k),
        List<String>.from(v).map((e) => e.trim().toUpperCase()).toList(),
      ));
      debugPrint("Beacon orders: ${floorBeaconOrders.map((k, v) => MapEntry(k, v.length))}");
    } catch (e) { debugPrint("loadBeaconOrders error: $e"); }
  }

  Future<void> _loadModel() async {
    if (_modelLoading) return;
    _modelLoading = true;
    try {
      session?.release();
      session = null;
      final raw = await rootBundle.load("assets/model/floor${selectedFloor}_model.onnx");
      session = OrtSession.fromBuffer(raw.buffer.asUint8List(), OrtSessionOptions());
      debugPrint("Model loaded — floor $selectedFloor  "
          "in:${session!.inputNames}  out:${session!.outputNames}");
    } catch (e) {
      debugPrint("loadModel error: $e");
      _setStatus("Model load failed: $e");
    } finally { _modelLoading = false; }
  }

  Future<void> _fetchPatchData() async {
    try {
      final res = await http.post(
        Uri.parse("https://dev.iwayplus.in/secured/patch/get"
            "?api_key=7cc62870-d67e-11f0-91ed-2f0eb903e7db"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id": "65d887a5db333f89457145f6",
          "manufacturer": "android",
          "devicemodel": "moto g64",
        }),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        patchData = json.decode(res.body);
        debugPrint("Patch loaded: ${patchData!.keys}");
      }
    } catch (e) {
      debugPrint("fetchPatchData error: $e");
    }
  }

  Future<void> _loadGeoJson() async {
    try {
      final raw = await rootBundle.loadString('assets/maps/converted_geojson.geojson');
      geoJsonData = json.decode(raw);
      _drawFloor(selectedFloor);
    } catch (e) { debugPrint("loadGeoJson error: $e"); }
  }

  void _drawFloor(int floor) {
    if (geoJsonData == null) return;
    final List<Polygon> built = [];
    for (final f in geoJsonData!["features"]) {
      if (f["properties"]["floor"] != floor) continue;
      final geom = f["geometry"];
      if (geom == null) continue;
      if (geom["type"] == "LineString" || geom["type"] == "Point") continue;
      if (geom["coordinnatesLocal"] == null) continue;
      final List<LatLng> pts = [];
      for (final c in geom["coordinnatesLocal"][0]) {
        if (c == null || (c is List && c.isEmpty)) continue;
        try {
          final g = _localToGlobal((c[0] as num).toDouble(), (c[1] as num).toDouble());
          pts.add(LatLng(g[0], g[1]));
        } catch (_) {}
      }
      if (pts.length >= 3) {
        built.add(Polygon(
          points: pts,
          color: Colors.indigo.withOpacity(0.15),
          borderColor: Colors.indigo.withOpacity(0.6),
          borderStrokeWidth: 1.2,
        ));
      }
    }
    setState(() => polygons = built);
  }

  // ─── Coordinate helpers ───────────────────────────────────────────────────
  double _dist(Map<String, double> a, Map<String, double> b) {
    final dx = a["localx"]! - b["localx"]!;
    final dy = a["localy"]! - b["localy"]!;
    return sqrt(dx * dx + dy * dy);
  }

  Map<String, double> _obtainCoords(Map<String, double> base, double ver, double hor) => {
    "lat": base["lat"]! + (ver / 111320),
    "lon": base["lon"]! + (hor / (111320 * cos(base["lat"]! * pi / 180))),
  };

  double _haversine(Map<String, double> a, Map<String, double> b) {
    const R = 6371.0;
    final dLat = (b["lat"]! - a["lat"]!) * pi / 180;
    final dLon = (b["lon"]! - a["lon"]!) * pi / 180;
    final arc = sin(dLat / 2) * sin(dLat / 2) +
        cos(a["lat"]! * pi / 180) * cos(b["lat"]! * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(arc), sqrt(1 - arc)) * 1000;
  }

  static const Map<int, Map<String, double>> _floorBounds = {
    0: {"xMin": 9,  "xMax": 264, "yMin": 48,  "yMax": 220,
      "latMin": 28.542762, "latMax": 28.544040,
      "lonMin": 77.186632, "lonMax": 77.188651},
    1: {"xMin": 9,  "xMax": 243, "yMin": 24,  "yMax": 244,
      "latMin": 28.542977, "latMax": 28.543612,
      "lonMin": 77.186956, "lonMax": 77.187948},
    2: {"xMin": 17, "xMax": 241, "yMin": 24,  "yMax": 228,
      "latMin": 28.543036, "latMax": 28.543689,
      "lonMin": 77.187149, "lonMax": 77.187945},
    3: {"xMin": 8,  "xMax": 203, "yMin": 17,  "yMax": 243,
      "latMin": 28.542979, "latMax": 28.543876,
      "lonMin": 77.187217, "lonMax": 77.187930},
  };

  List<double> _linearLocalToGlobal(double x, double y) {
    final b = _floorBounds[selectedFloor]!;
    final tX = ((x - b["xMin"]!) / (b["xMax"]! - b["xMin"]!)).clamp(0.0, 1.0);
    final tY = ((y - b["yMin"]!) / (b["yMax"]! - b["yMin"]!)).clamp(0.0, 1.0);
    final lat = b["latMin"]! + tY * (b["latMax"]! - b["latMin"]!);
    final lon = b["lonMin"]! + tX * (b["lonMax"]! - b["lonMin"]!);
    return [lat, lon];
  }

  List<double> _localToGlobal(double x, double y) {
    if (patchData != null) {
      try {
        final coords = patchData!["patchData"]["coordinates"] as List;
        final ref = [
          {"lat": double.parse(coords[2]["globalRef"]["lat"]), "lon": double.parse(coords[2]["globalRef"]["lng"]), "localx": double.parse(coords[2]["localRef"]["lng"]), "localy": double.parse(coords[2]["localRef"]["lat"])},
          {"lat": double.parse(coords[1]["globalRef"]["lat"]), "lon": double.parse(coords[1]["globalRef"]["lng"]), "localx": double.parse(coords[1]["localRef"]["lng"]), "localy": double.parse(coords[1]["localRef"]["lat"])},
          {"lat": double.parse(coords[0]["globalRef"]["lat"]), "lon": double.parse(coords[0]["globalRef"]["lng"]), "localx": double.parse(coords[0]["localRef"]["lng"]), "localy": double.parse(coords[0]["localRef"]["lat"])},
          {"lat": double.parse(coords[3]["globalRef"]["lat"]), "lon": double.parse(coords[3]["globalRef"]["lng"]), "localx": double.parse(coords[3]["localRef"]["lng"]), "localy": double.parse(coords[3]["localRef"]["lat"])},
        ];

        int leastLat = 0;
        for (int i = 0; i < ref.length; i++) {
          if (ref[i]["lat"] == ref[leastLat]["lat"]) {
            if (ref[i]["lon"]! > ref[leastLat]["lon"]!) leastLat = i;
          } else if (ref[i]["lat"]! < ref[leastLat]["lat"]!) leastLat = i;
        }
        final c1 = leastLat == 3 ? 0 : leastLat + 1;
        final c2 = leastLat == 0 ? 3 : leastLat - 1;
        final highLon = ref[c1]["lon"]! > ref[c2]["lon"]! ? c1 : c2;

        final b      = _haversine(ref[leastLat], ref[highLon]);
        final horiz  = _obtainCoords(ref[leastLat], 0, b);
        final c      = _haversine(ref[leastLat], horiz);
        final a      = _haversine(ref[highLon], horiz);

        final cosVal = ((b * b + c * c - a * a) / (2 * b * c)).clamp(-1.0, 1.0);
        final out    = acos(cosVal) * 180 / pi;

        final localRef = {"localx": x, "localy": y};
        final l = _dist(ref[leastLat], ref[highLon]);
        final m = _dist(localRef, ref[highLon]);
        final n = _dist(ref[leastLat], localRef);

        double theta = 0;
        if (l > 0 && n > 0 && m > 0) {
          final ct = ((l * l + n * n - m * m) / (2 * l * n)).clamp(-1.0, 1.0);
          theta = acos(ct) * 180 / pi;
        }

        final ang  = theta + out;
        final dist = _dist(ref[leastLat], localRef) * 0.3048;
        final ver  = dist * sin(ang * pi / 180.0);
        final hor  = dist * cos(ang * pi / 180.0);
        final fc   = _obtainCoords(ref[leastLat], ver, hor);

        final latOk = fc["lat"]! > 28.540 && fc["lat"]! < 28.547;
        final lonOk = fc["lon"]! > 77.185 && fc["lon"]! < 77.191;
        if (latOk && lonOk) return [fc["lat"]!, fc["lon"]!];
        debugPrint("localToGlobal: out of bounds, using linear fallback");
      } catch (e) {
        debugPrint("localToGlobal patch error: $e — using linear fallback");
      }
    }
    return _linearLocalToGlobal(x, y);
  }

  // ─── Inference ────────────────────────────────────────────────────────────
  // Model output shape is [1, 2] → [[pred_x, pred_y]] at runtime
  // (metadata says [None, 1] but actual output is always [batch, 2]).
  (double, double)? _runInference(List<double> features) {
    if (session == null) return null;
    final inputName = session!.inputNames.first;
    final tensor = OrtValueTensor.createTensorWithDataList(
      Float32List.fromList(features),
      [1, features.length],
    );
    List<OrtValue?>? outputs;
    try {
      outputs = session!.run(OrtRunOptions(), {inputName: tensor});
      final raw = outputs.first?.value;
      if (raw == null) return null;

      if (raw is List && raw.isNotEmpty) {
        final row = raw[0];
        if (row is List && row.length >= 2) {
          final x = (row[0] as num).toDouble();
          final y = (row[1] as num).toDouble();
          debugPrint("Inference → x=$x, y=$y");
          return (x, y);
        }
        // Flat fallback: shape [2] on some SDK versions
        if (raw.length >= 2 && raw[0] is num) {
          final x = (raw[0] as num).toDouble();
          final y = (raw[1] as num).toDouble();
          debugPrint("Inference (flat) → x=$x, y=$y");
          return (x, y);
        }
      }
      debugPrint("Unexpected model output: ${raw.runtimeType}  value=$raw");
      return null;
    } catch (e) {
      debugPrint("Inference error: $e");
      return null;
    } finally {
      tensor.release();
      if (outputs != null) {
        for (final o in outputs) { try { o?.release(); } catch (_) {} }
      }
    }
  }

  // ─── Position update (BLE-only, no GPS) ──────────────────────────────────
  void _updatePosition(double bleX, double bleY) {
    // Jump filter — ignore teleports > _jumpThreshold units
    if (lastX != null && lastY != null) {
      final d = sqrt(pow(bleX - lastX!, 2) + pow(bleY - lastY!, 2));
      if (d > _jumpThreshold) {
        debugPrint("Jump $d > $_jumpThreshold — skipped");
        return;
      }
    }
    lastX = bleX;
    lastY = bleY;

    final g = _localToGlobal(bleX, bleY);
    final newPoint = LatLng(g[0], g[1]);

    setState(() {
      userMarker = Marker(
        point: newPoint,
        width: 32,
        height: 32,
        child: _PulsingDot(),
      );
      coordText = "X: ${bleX.toStringAsFixed(1)}  Y: ${bleY.toStringAsFixed(1)}";
    });

    try { _mapController.move(newPoint, _mapController.camera.zoom); } catch (_) {}
  }

  // ─── Continuous BLE scan (sliding window) ─────────────────────────────────
  void _startScanning() {
    if (isScanning || !modelReady) return;
    setState(() {
      isScanning = true;
      statusText = "Scanning…";
      lastX = null;
      lastY = null;
      kalmanX.reset();
      kalmanY.reset();
      _rssiBuffer.clear();
    });
    _startBleStream();
    _updateTimer = Timer.periodic(
        Duration(milliseconds: _updateIntervalMs), (_) => _emitPosition());
  }

  void _stopScanning() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _bleSub?.cancel();
    _bleSub = null;
    _scanRunning = false;
    LocalizationEngine.stopScanning().catchError((_) {});
    if (mounted) setState(() { isScanning = false; statusText = "Stopped"; });
  }

  Future<void> _startBleStream() async {
    if (_scanRunning) return;
    try {
      await LocalizationEngine.startScanning(
        venueName: "IITDelhi",
        immediateEmit: true,
      );
      _scanRunning = true;

      await _bleSub?.cancel();
      _bleSub = LocalizationEngine.scanResultsForAllBeacons.listen((event) {
        if (event == null) return;
        final now = DateTime.now();
        final Map<String, dynamic> data = Map<String, dynamic>.from(event);
        data.forEach((key, value) {
          final name = key.trim().toUpperCase();
          if (!name.startsWith("IW")) return;
          final readings = List<MapEntry<DateTime, int>>.from(value);
          final buf = _rssiBuffer.putIfAbsent(name, () => []);
          for (final r in readings) { buf.add((ts: r.key, rssi: r.value)); }
        });
        final cutoff = now.subtract(Duration(seconds: _windowSeconds));
        _rssiBuffer.forEach((k, v) => v.removeWhere((e) => e.ts.isBefore(cutoff)));
      });
    } catch (e) {
      debugPrint("BLE stream start error: $e");
      _scanRunning = false;
    }
  }

  void _emitPosition() {
    if (!isScanning || !mounted) return;
    final beaconOrder = floorBeaconOrders[selectedFloor];
    if (beaconOrder == null || session == null) return;

    final cutoff = DateTime.now().subtract(Duration(seconds: _windowSeconds));
    _rssiBuffer.forEach((k, v) => v.removeWhere((e) => e.ts.isBefore(cutoff)));

    int seen = 0;
    final features = beaconOrder.map((b) {
      final buf = _rssiBuffer[b];
      if (buf != null && buf.isNotEmpty) {
        final vals = buf.map((e) => e.rssi).toList()..sort();
        final trimmed = vals.length > 4 ? vals.sublist(1, vals.length - 1) : vals;
        seen++;
        return trimmed.reduce((a, b) => a + b) / trimmed.length;
      }
      return _missingRssi;
    }).toList();

    // Append the two sensor features the model was trained with.
    // Altitude: use barometer if available, otherwise floor-specific fallback.
    // GPS accuracy: always use the per-floor fallback constant (GPS removed).
    features.add(_floorAltFallback[selectedFloor] ?? 200.0);
    features.add(_floorAccFallback[selectedFloor] ?? 15.0);

    debugPrint("Emit: $seen/${beaconOrder.length} beacons  floor=$selectedFloor");

    if (seen == 0) {
      if (mounted) setState(() => statusText = "No beacons — moving?");
      return;
    }

    // Don't commit first fix until enough beacons are seen.
    // Prevents the all-missing centroid from anchoring Kalman wrongly.
    if (lastX == null && seen < _minBeaconsFirstFix) {
      if (mounted) setState(() => statusText = "Acquiring… ($seen beacon${seen == 1 ? '' : 's'} seen)");
      return;
    }

    final result = _runInference(features);
    if (result == null) return;

    double x, y;
    if (seen >= _sparseThresh) {
      x = kalmanX.update(result.$1);
      y = kalmanY.update(result.$2);
    } else {
      kalmanX.update(result.$1);
      kalmanY.update(result.$2);
      x = result.$1;
      y = result.$2;
    }

    if (mounted) {
      _updatePosition(x, y);
      setState(() { beaconsSeen = seen; });
      _setStatus("Live · $seen beacon${seen == 1 ? '' : 's'}");
    }
  }

  Future<void> _changeFloor(int floor) async {
    if (isScanning) _stopScanning();
    setState(() {
      selectedFloor = floor;
      statusText    = "Loading floor $floor…";
      modelReady    = false;
      lastX = null;
      lastY = null;
      kalmanX.reset();
      kalmanY.reset();
      userMarker = null;
      coordText  = "";
      _rssiBuffer.clear();
    });
    await _loadModel();
    _drawFloor(floor);
    setState(() {
      modelReady = true;
      statusText = "Floor $floor ready — tap ▶ to start";
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mapH = MediaQuery.of(context).size.height * 0.58;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Indoor Localization",
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedFloor,
                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                items: [0, 1, 2, 3].map((f) => DropdownMenuItem(
                  value: f, child: Text("Floor $f"),
                )).toList(),
                onChanged: (v) { if (v != null) _changeFloor(v); },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: mapH,
            child: ClipRRect(
              child: FlutterMap(
                mapController: _mapController,
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
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatusDot(active: isScanning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(statusText,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      if (beaconsSeen > 0) _BeaconBadge(count: beaconsSeen),
                    ],
                  ),
                  if (coordText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(coordText, style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace')),
                  ],
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: modelReady
                          ? (isScanning ? _stopScanning : _startScanning)
                          : null,
                      icon: Icon(isScanning ? Icons.stop_rounded : Icons.my_location_rounded),
                      label: Text(
                        isScanning ? "Stop Scanning" : "Start Scanning",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isScanning ? Colors.red.shade400 : Colors.indigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.indigo.withOpacity(0.2 * _anim.value),
      ),
      child: Center(
        child: Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.indigo,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.4), blurRadius: 6)],
          ),
        ),
      ),
    ),
  );
}

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});
  @override
  Widget build(BuildContext context) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? Colors.green : Colors.grey.shade400,
    ),
  );
}

class _BeaconBadge extends StatelessWidget {
  final int count;
  const _BeaconBadge({required this.count});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.indigo.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bluetooth, size: 12, color: Colors.indigo),
        const SizedBox(width: 3),
        Text("$count", style: const TextStyle(
            fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}