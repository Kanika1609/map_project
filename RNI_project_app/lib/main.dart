import 'package:flutter/material.dart';
import 'package:rni_project_app/screens/building_select_screen.dart';

void main() {
  runApp(const BLEApp());
}

class BLEApp extends StatelessWidget {
  const BLEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const BuildingSelectScreen(),
    );
  }
}


// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:localization_engine/localization_engine.dart';
//
// import 'package:rni_project_app/BLEPositionEstimator.dart';
// import 'package:rni_project_app/beacon_db2.dart';
//
// void main() {
//   runApp(const BLEApp());
// }
//
// class BLEApp extends StatelessWidget {
//   const BLEApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: const BLEHome(),
//     );
//   }
// }
//
// class BLEHome extends StatefulWidget {
//   const BLEHome({super.key});
//
//   @override
//   State<BLEHome> createState() => _BLEHomeState();
// }
//
// class _BLEHomeState extends State<BLEHome> {
//   late BLEPositionEstimator estimator;
//   late LocalizationEngine engine;
//
//   StreamSubscription? _scanSubscription;
//   Timer? timer;
//
//   // All floors present in the beacon DB, sorted (e.g. [0, 1]).
//   late final List<int> availableFloors;
//   int currentFloor = 0;
//   bool isScanning = false;
//
//   List<Offset> smoothPath = [];
//   // Default start position sits inside the floor plan's coordinate range
//   // (x: 16-429, y: 39-221).
//   Offset currentPos = const Offset(200, 100);
//
//   String confidence = "--";
//   String motion = "--";
//   String topBeacon = "--";
//   String topRssi = "--";
//   String statusMsg = "Press Start to begin scanning";
//
//   @override
//   void initState() {
//     super.initState();
//     availableFloors = rniBeaconDb2.values.map((b) => b.floor).toSet().toList()
//       ..sort();
//     if (availableFloors.isNotEmpty && !availableFloors.contains(currentFloor)) {
//       currentFloor = availableFloors.first;
//     }
//     estimator = BLEPositionEstimator(
//       beaconDb: rniBeaconDb2,
//       windowS: 6.0,
//       floor: currentFloor,
//     );
//     engine = LocalizationEngine("Iwayplus");
//   }
//
//   Future<void> _requestPermissions() async {
//     await Permission.bluetoothScan.request();
//     await Permission.bluetoothConnect.request();
//     await Permission.locationWhenInUse.request();
//   }
//
//   void _resetDisplayState({String? status}) {
//     smoothPath.clear();
//     currentPos = const Offset(200, 100);
//     confidence = "--";
//     motion = "--";
//     topBeacon = "--";
//     topRssi = "--";
//     if (status != null) statusMsg = status;
//   }
//
//   void switchFloor(int floor) {
//     if (floor == currentFloor) return;
//
//     final wasScanning = isScanning;
//
//     // Stop any active scan/timer before swapping the estimator out.
//     _scanSubscription?.cancel();
//     timer?.cancel();
//
//     setState(() {
//       currentFloor = floor;
//       // Rebuild the estimator scoped to the newly selected floor.
//       estimator = BLEPositionEstimator(
//         beaconDb: rniBeaconDb2,
//         windowS: 6.0,
//         floor: currentFloor,
//       );
//       _resetDisplayState(
//         status: wasScanning
//             ? "Switched to floor $currentFloor — restarting scan..."
//             : "Switched to floor $currentFloor. Press Start to begin scanning",
//       );
//       isScanning = false;
//     });
//
//     // If a scan was in progress, seamlessly resume it on the new floor.
//     if (wasScanning) {
//       startScanning();
//     }
//   }
//
//   void startScanning() async {
//     await _requestPermissions();
//
//     final scan    = await Permission.bluetoothScan.status;
//     final connect = await Permission.bluetoothConnect.status;
//     final loc     = await Permission.locationWhenInUse.status;
//
//     if (!scan.isGranted || !connect.isGranted || !loc.isGranted) {
//       setState(() => statusMsg = 'Permissions not granted! Allow in settings.');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Permissions not granted!')),
//       );
//       return;
//     }
//
//     estimator.reset();
//     setState(() {
//       _resetDisplayState(status: "Scanning... waiting for first 6 seconds");
//       isScanning = true;
//     });
//
//     // Feed live readings into rolling buffer
//     _scanSubscription = engine.bluetoothScanResults.listen(
//           (data) {
//         if (data == null) return;
//         estimator.update(
//           [BleReading(
//             name: data['name'] as String,
//             rssi: data['rssi'] as int,
//             timestamp: DateTime.parse(data['timestamp'] as String),
//           )],
//           walking: true,
//         );
//       },
//       onError: (e) {
//         debugPrint('Scan error: $e');
//         setState(() => statusMsg = 'Scan error: $e');
//       },
//     );
//
//     // Update UI every 500ms
//     timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
//       final result = estimator.lastResult;
//       if (result != null) {
//         final newPos = Offset(result.smoothX, result.smoothY);
//         setState(() {
//           currentPos = newPos;
//           confidence = result.confidence;
//           motion = 'stationary';
//           topBeacon = result.rank1Beacon;
//           topRssi = result.rank1Rssi.toString();
//           statusMsg = "Live — position updating (Floor $currentFloor)";
//         });
//       } else {
//         setState(() {
//           statusMsg = "⚠️ No beacons detected — move closer to a beacon";
//         });
//       }
//     });
//   }
//
//   void stopScanning() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     estimator.reset();
//     setState(() {
//       _resetDisplayState(status: "Stopped. Press Start to begin again.");
//       isScanning = false;
//     });
//   }
//
//   @override
//   void dispose() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("BLE Real-Time Position Estimator"),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             // Info Card
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text(
//                         "Position",
//                         style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                       ),
//                       Text(
//                         "Floor $currentFloor",
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.grey.shade700,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 15),
//                   Text(
//                     "(${currentPos.dx.toStringAsFixed(1)}, ${currentPos.dy.toStringAsFixed(1)})",
//                     style: const TextStyle(fontSize: 22, color: Colors.blue),
//                   ),
//                   const SizedBox(height: 15),
//                   Text("Top Beacon: $topBeacon"),
//                   Text("Confidence: $confidence"),
//                   Text("Motion: $motion"),
//                   Text("RSSI: $topRssi"),
//                   const SizedBox(height: 6),
//                   Text(statusMsg,
//                       style: const TextStyle(fontSize: 11, color: Colors.grey)),
//                 ],
//               ),
//             ),
//
//             const SizedBox(height: 16),
//
//             // Floor switcher
//             Row(
//               children: [
//                 const Text(
//                   "Floor:",
//                   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: Row(
//                       children: availableFloors.map((floor) {
//                         final selected = floor == currentFloor;
//                         return Padding(
//                           padding: const EdgeInsets.only(right: 8),
//                           child: ChoiceChip(
//                             label: Text("Floor $floor"),
//                             selected: selected,
//                             onSelected: (_) => switchFloor(floor),
//                           ),
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 16),
//
//             // Buttons
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: startScanning,
//                     child: const Text("Start"),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: stopScanning,
//                     child: const Text("Stop"),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 20),
//
//             // Canvas
//             Expanded(
//               child: Container(
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border.all(color: Colors.black26),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: InteractiveViewer(
//                     constrained: false,
//                     minScale: 0.3,
//                     maxScale: 15.0,
//                     boundaryMargin: const EdgeInsets.all(200),
//                     child: SizedBox(
//                       width: 480,
//                       height: 280,
//                       child: CustomPaint(
//                         painter: BLEPainter(
//                           smoothPath: smoothPath,
//                           currentPos: currentPos,
//                           floor: currentFloor,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class BLEPainter extends CustomPainter {
//   final List<Offset> smoothPath;
//   final Offset currentPos;
//   final int floor;
//
//   // Scale raw local coords (16-429 x, 39-221 y) to canvas pixels.
//   static const double _scale = 1.0;
//   static const double _pad   = 30.0;
//
//   BLEPainter({
//     required this.smoothPath,
//     required this.currentPos,
//     required this.floor,
//   });
//
//   // convert raw local coord to canvas coord
//   Offset _s(double x, double y) =>
//       Offset(_pad + x * _scale, _pad + y * _scale);
//
//   double get _heading {
//     if (smoothPath.length < 2) return -pi / 2;
//     final prev = _s(smoothPath[smoothPath.length - 2].dx, smoothPath[smoothPath.length - 2].dy);
//     final curr = _s(smoothPath[smoothPath.length - 1].dx, smoothPath[smoothPath.length - 1].dy);
//     return atan2(curr.dy - prev.dy, curr.dx - prev.dx);
//   }
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final beaconPaint = Paint()
//       ..color = Colors.grey
//       ..style = PaintingStyle.fill;
//
//     final pathPaint = Paint()
//       ..color = Colors.blue
//       ..strokeWidth = 2
//       ..strokeCap = StrokeCap.round
//       ..style = PaintingStyle.stroke;
//
//     // Draw beacons for the currently selected floor only
//     for (final entry in rniBeaconDb2.entries) {
//       final beacon = entry.value;
//       if (beacon.floor != floor) continue;
//
//       final p = _s(beacon.lx.toDouble(), beacon.ly.toDouble());
//
//       canvas.drawCircle(p, 8, beaconPaint);
//
//       final textPainter = TextPainter(
//         text: TextSpan(
//           text: entry.key.substring(entry.key.length - 4),
//           style: const TextStyle(color: Colors.grey, fontSize: 12),
//         ),
//         textDirection: TextDirection.ltr,
//       );
//       textPainter.layout();
//       textPainter.paint(canvas, Offset(p.dx + 10, p.dy - 8));
//     }
//
//     // Draw smooth path
//     if (smoothPath.length > 1) {
//       final path = Path();
//       final first = _s(smoothPath[0].dx, smoothPath[0].dy);
//       path.moveTo(first.dx, first.dy);
//       for (int i = 1; i < smoothPath.length; i++) {
//         final p = _s(smoothPath[i].dx, smoothPath[i].dy);
//         path.lineTo(p.dx, p.dy);
//       }
//       canvas.drawPath(path, pathPaint);
//     }
//
//     // Direction marker — scaled position
//     final sp = _s(currentPos.dx, currentPos.dy);
//     final heading = _heading;
//     final cx = sp.dx;
//     final cy = sp.dy;
//
//     canvas.drawCircle(sp, 18,
//         Paint()..color = const Color(0xFF4285F4).withOpacity(0.15));
//     canvas.drawCircle(sp, 12,
//         Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
//     canvas.drawCircle(sp, 9,
//         Paint()..color = const Color(0xFF4285F4));
//
//     final tip   = Offset(cx + 18 * cos(heading), cy + 18 * sin(heading));
//     final left  = Offset(cx + 8 * cos(heading + pi * 0.65), cy + 8 * sin(heading + pi * 0.65));
//     final right = Offset(cx + 8 * cos(heading - pi * 0.65), cy + 8 * sin(heading - pi * 0.65));
//
//     final arrowPath = Path()
//       ..moveTo(tip.dx, tip.dy)
//       ..lineTo(left.dx, left.dy)
//       ..lineTo(right.dx, right.dy)
//       ..close();
//
//     canvas.drawPath(arrowPath, Paint()..color = const Color(0xFF4285F4));
//     canvas.drawPath(arrowPath,
//         Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
//   }
//
//   @override
//   bool shouldRepaint(covariant BLEPainter oldDelegate) {
//     return oldDelegate.smoothPath != smoothPath ||
//         oldDelegate.currentPos != currentPos ||
//         oldDelegate.floor != floor;
//   }
// }
// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:localization_engine/localization_engine.dart';
//
// import 'package:rni_project_app/BLEPositionEstimator.dart';
// import 'package:rni_project_app/beacon_db2.dart';
//
// void main() {
//   runApp(const BLEApp());
// }
//
// class BLEApp extends StatelessWidget {
//   const BLEApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: const BLEHome(),
//     );
//   }
// }
//
// class BLEHome extends StatefulWidget {
//   const BLEHome({super.key});
//
//   @override
//   State<BLEHome> createState() => _BLEHomeState();
// }
//
// class _BLEHomeState extends State<BLEHome> {
//   late BLEPositionEstimator estimator;
//   late LocalizationEngine engine;
//
//   StreamSubscription? _scanSubscription;
//   Timer? timer;
//
//   // All floors present in the beacon DB, sorted (e.g. [0, 1]).
//   late final List<int> availableFloors;
//   int currentFloor = 0;
//   bool isScanning = false;
//
//   // GeoJSON floor map features — pre-aligned to the beacon lx/ly coordinate
//   // system via the "coordinatesLocal" field (see rgci_floor_map.geojson).
//   List<dynamic> _allFeatures = [];
//   bool _mapLoaded = false;
//
//   List<Offset> smoothPath = [];
//   // Default start position sits inside the floor plan's coordinate range
//   // (x: 16-429, y: 39-221) — same as before, untouched.
//   Offset currentPos = const Offset(200, 100);
//
//   String confidence = "--";
//   String motion = "--";
//   String topBeacon = "--";
//   String topRssi = "--";
//   String statusMsg = "Press Start to begin scanning";
//
//   @override
//   void initState() {
//     super.initState();
//     availableFloors = rniBeaconDb2.values.map((b) => b.floor).toSet().toList()
//       ..sort();
//     if (availableFloors.isNotEmpty && !availableFloors.contains(currentFloor)) {
//       currentFloor = availableFloors.first;
//     }
//     estimator = BLEPositionEstimator(
//       beaconDb: rniBeaconDb2,
//       windowS: 6.0,
//       floor: currentFloor,
//     );
//     engine = LocalizationEngine("Iwayplus");
//     _loadGeoJSON();
//   }
//
//   Future<void> _loadGeoJSON() async {
//     try {
//       // Place rgci_floor_map.geojson under this path in your project and
//       // register it in pubspec.yaml under flutter -> assets.
//       final raw = await rootBundle.loadString(
//           'assets/maps/rgci_floor_map.geojson');
//       final data = json.decode(raw);
//       setState(() {
//         _allFeatures = data['features'] as List<dynamic>;
//         _mapLoaded = true;
//       });
//     } catch (e) {
//       debugPrint('GeoJSON load error: $e');
//     }
//   }
//
//   List<dynamic> get _currentFloorFeatures => _allFeatures.where((f) {
//     final props = f['properties'] ?? {};
//     final floor = props['floor'] ?? props['level'];
//     return floor == currentFloor;
//   }).toList();
//
//   Future<void> _requestPermissions() async {
//     await Permission.bluetoothScan.request();
//     await Permission.bluetoothConnect.request();
//     await Permission.locationWhenInUse.request();
//   }
//
//   void _resetDisplayState({String? status}) {
//     smoothPath.clear();
//     currentPos = const Offset(200, 100);
//     confidence = "--";
//     motion = "--";
//     topBeacon = "--";
//     topRssi = "--";
//     if (status != null) statusMsg = status;
//   }
//
//   void switchFloor(int floor) {
//     if (floor == currentFloor) return;
//
//     final wasScanning = isScanning;
//
//     // Stop any active scan/timer before swapping the estimator out.
//     _scanSubscription?.cancel();
//     timer?.cancel();
//
//     setState(() {
//       currentFloor = floor;
//       // Rebuild the estimator scoped to the newly selected floor — unchanged
//       // from before, still uses rniBeaconDb2's lx/ly data only.
//       estimator = BLEPositionEstimator(
//         beaconDb: rniBeaconDb2,
//         windowS: 6.0,
//         floor: currentFloor,
//       );
//       _resetDisplayState(
//         status: wasScanning
//             ? "Switched to floor $currentFloor — restarting scan..."
//             : "Switched to floor $currentFloor. Press Start to begin scanning",
//       );
//       isScanning = false;
//     });
//
//     // If a scan was in progress, seamlessly resume it on the new floor.
//     if (wasScanning) {
//       startScanning();
//     }
//   }
//
//   void startScanning() async {
//     await _requestPermissions();
//
//     final scan    = await Permission.bluetoothScan.status;
//     final connect = await Permission.bluetoothConnect.status;
//     final loc     = await Permission.locationWhenInUse.status;
//
//     if (!scan.isGranted || !connect.isGranted || !loc.isGranted) {
//       setState(() => statusMsg = 'Permissions not granted! Allow in settings.');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Permissions not granted!')),
//       );
//       return;
//     }
//
//     estimator.reset();
//     setState(() {
//       _resetDisplayState(status: "Scanning... waiting for first 6 seconds");
//       isScanning = true;
//     });
//
//     // Feed live readings into rolling buffer — unchanged
//     _scanSubscription = engine.bluetoothScanResults.listen(
//           (data) {
//         if (data == null) return;
//         estimator.update(
//           [BleReading(
//             name: data['name'] as String,
//             rssi: data['rssi'] as int,
//             timestamp: DateTime.parse(data['timestamp'] as String),
//           )],
//           walking: true,
//         );
//       },
//       onError: (e) {
//         debugPrint('Scan error: $e');
//         setState(() => statusMsg = 'Scan error: $e');
//       },
//     );
//
//     // Update UI every 500ms — unchanged
//     timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
//       final result = estimator.lastResult;
//       if (result != null) {
//         final newPos = Offset(result.smoothX, result.smoothY);
//         setState(() {
//           currentPos = newPos;
//           confidence = result.confidence;
//           motion = 'stationary';
//           topBeacon = result.rank1Beacon;
//           topRssi = result.rank1Rssi.toString();
//           statusMsg = "Live — position updating (Floor $currentFloor)";
//         });
//       } else {
//         setState(() {
//           statusMsg = "⚠️ No beacons detected — move closer to a beacon";
//         });
//       }
//     });
//   }
//
//   void stopScanning() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     estimator.reset();
//     setState(() {
//       _resetDisplayState(status: "Stopped. Press Start to begin again.");
//       isScanning = false;
//     });
//   }
//
//   @override
//   void dispose() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("BLE Real-Time Position Estimator"),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             // Info Card — unchanged
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text(
//                         "Position",
//                         style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                       ),
//                       Text(
//                         "Floor $currentFloor",
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.grey.shade700,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 15),
//                   Text(
//                     "(${currentPos.dx.toStringAsFixed(1)}, ${currentPos.dy.toStringAsFixed(1)})",
//                     style: const TextStyle(fontSize: 22, color: Colors.blue),
//                   ),
//                   const SizedBox(height: 15),
//                   Text("Top Beacon: $topBeacon"),
//                   Text("Confidence: $confidence"),
//                   Text("Motion: $motion"),
//                   Text("RSSI: $topRssi"),
//                   const SizedBox(height: 6),
//                   Text(statusMsg,
//                       style: const TextStyle(fontSize: 11, color: Colors.grey)),
//                 ],
//               ),
//             ),
//
//             const SizedBox(height: 16),
//
//             // Floor switcher — unchanged
//             Row(
//               children: [
//                 const Text(
//                   "Floor:",
//                   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: Row(
//                       children: availableFloors.map((floor) {
//                         final selected = floor == currentFloor;
//                         return Padding(
//                           padding: const EdgeInsets.only(right: 8),
//                           child: ChoiceChip(
//                             label: Text("Floor $floor"),
//                             selected: selected,
//                             onSelected: (_) => switchFloor(floor),
//                           ),
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 16),
//
//             // Buttons — unchanged
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: startScanning,
//                     child: const Text("Start"),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: stopScanning,
//                     child: const Text("Stop"),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 20),
//
//             // Canvas
//             Expanded(
//               child: Container(
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border.all(color: Colors.black26),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: InteractiveViewer(
//                     constrained: false,
//                     minScale: 0.3,
//                     maxScale: 15.0,
//                     boundaryMargin: const EdgeInsets.all(200),
//                     child: SizedBox(
//                       // Sized to fit both the beacon range (16-429 x, 39-221 y)
//                       // and the map geometry range (up to ~458 x, ~242 y),
//                       // since both now share the same coordinate system.
//                       width: 520,
//                       height: 300,
//                       child: CustomPaint(
//                         painter: BLEPainter(
//                           smoothPath: smoothPath,
//                           currentPos: currentPos,
//                           floor: currentFloor,
//                           features: _mapLoaded ? _currentFloorFeatures : [],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class BLEPainter extends CustomPainter {
//   final List<Offset> smoothPath;
//   final Offset currentPos;
//   final int floor;
//   final List<dynamic> features;
//
//   // Scale raw local coords (0-458 x, 4-242 y) to canvas pixels.
//   // Beacons, marker, and the map all now share this same coordinate system.
//   static const double _scale = 1.0;
//   static const double _pad   = 30.0;
//
//   BLEPainter({
//     required this.smoothPath,
//     required this.currentPos,
//     required this.floor,
//     required this.features,
//   });
//
//   // convert raw local coord to canvas coord
//   Offset _s(double x, double y) =>
//       Offset(_pad + x * _scale, _pad + y * _scale);
//
//   double get _heading {
//     if (smoothPath.length < 2) return -pi / 2;
//     final prev = _s(smoothPath[smoothPath.length - 2].dx, smoothPath[smoothPath.length - 2].dy);
//     final curr = _s(smoothPath[smoothPath.length - 1].dx, smoothPath[smoothPath.length - 1].dy);
//     return atan2(curr.dy - prev.dy, curr.dx - prev.dx);
//   }
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     // ── 1. Draw GeoJSON floor map using coordinatesLocal ──────────────────
//     // (already aligned to the beacon lx/ly system — no runtime projection needed)
//     for (final feature in features) {
//       final geom = feature['geometry'];
//       final props = feature['properties'] ?? {};
//       final type = (props['type'] ?? '').toString();
//       final geomType = geom['type'];
//       final localCoords = geom['coordinatesLocal'];
//       if (localCoords == null) continue;
//
//       if (geomType == 'Polygon') {
//         final rings = localCoords as List;
//         if (rings.isEmpty) continue;
//         final outerRing = rings[0] as List;
//         if (outerRing.isEmpty || outerRing[0] is! List) continue;
//
//         final pts = outerRing
//             .map<Offset>((p) => _s((p[0] as num).toDouble(), (p[1] as num).toDouble()))
//             .toList();
//         if (pts.length < 3) continue;
//
//         final path = Path()..moveTo(pts[0].dx, pts[0].dy);
//         for (int i = 1; i < pts.length; i++) {
//           path.lineTo(pts[i].dx, pts[i].dy);
//         }
//         path.close();
//
//         Color fillColor;
//         Color strokeColor;
//         double strokeWidth;
//
//         if (type.startsWith('Wall')) {
//           fillColor = Colors.grey.shade600.withOpacity(0.7);
//           strokeColor = Colors.grey.shade800;
//           strokeWidth = 0.5;
//         } else if (type == 'Room' || type == 'Rooms') {
//           fillColor = Colors.blue.withOpacity(0.08);
//           strokeColor = Colors.blue.withOpacity(0.5);
//           strokeWidth = 0.8;
//         } else if (type == 'Boundary') {
//           fillColor = Colors.transparent;
//           strokeColor = Colors.black54;
//           strokeWidth = 1.0;
//         } else if ([
//           'Male Washroom',
//           'Female Washroom',
//           'Accessible Washroom',
//           'Washroom',
//           'Powder Room',
//         ].contains(type)) {
//           fillColor = Colors.cyan.withOpacity(0.15);
//           strokeColor = Colors.cyan.shade400;
//           strokeWidth = 0.8;
//         } else if (type.startsWith('Lift') || type == 'Stairs') {
//           fillColor = Colors.orange.withOpacity(0.15);
//           strokeColor = Colors.orange.shade400;
//           strokeWidth = 0.8;
//         } else if (type == 'Cafeteria' || type.contains('Sitting Area')) {
//           fillColor = Colors.green.withOpacity(0.15);
//           strokeColor = Colors.green.shade400;
//           strokeWidth = 0.8;
//         } else if (type == 'Restricted Area') {
//           fillColor = Colors.red.withOpacity(0.08);
//           strokeColor = Colors.red.withOpacity(0.4);
//           strokeWidth = 0.6;
//         } else {
//           fillColor = Colors.blueGrey.withOpacity(0.04);
//           strokeColor = Colors.blueGrey.withOpacity(0.25);
//           strokeWidth = 0.5;
//         }
//
//         canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
//         canvas.drawPath(path,
//             Paint()
//               ..color = strokeColor
//               ..style = PaintingStyle.stroke
//               ..strokeWidth = strokeWidth);
//       } else if (geomType == 'LineString') {
//         if (localCoords is! List || localCoords.isEmpty) continue;
//         if (localCoords[0] is! List) continue;
//         final pts = localCoords
//             .map<Offset>((p) => _s((p[0] as num).toDouble(), (p[1] as num).toDouble()))
//             .toList();
//         if (pts.length < 2) continue;
//         final path = Path()..moveTo(pts[0].dx, pts[0].dy);
//         for (int i = 1; i < pts.length; i++) {
//           path.lineTo(pts[i].dx, pts[i].dy);
//         }
//         canvas.drawPath(
//             path,
//             Paint()
//               ..color = Colors.grey.withOpacity(0.3)
//               ..style = PaintingStyle.stroke
//               ..strokeWidth = 0.5);
//       }
//       // Point features (Centroid, FloorConnection, etc.) intentionally
//       // not drawn — they're label/graph anchors, not visuals.
//     }
//
//     // ── 2. Draw beacon dots — untouched from before ────────────────────────
//     final beaconPaint = Paint()
//       ..color = Colors.grey
//       ..style = PaintingStyle.fill;
//
//     for (final entry in rniBeaconDb2.entries) {
//       final beacon = entry.value;
//       if (beacon.floor != floor) continue;
//
//       final p = _s(beacon.lx.toDouble(), beacon.ly.toDouble());
//
//       canvas.drawCircle(p, 4, beaconPaint);
//
//       final textPainter = TextPainter(
//         text: TextSpan(
//           text: entry.key.substring(entry.key.length - 4),
//           style: const TextStyle(color: Colors.grey, fontSize: 9),
//         ),
//         textDirection: TextDirection.ltr,
//       );
//       textPainter.layout();
//       textPainter.paint(canvas, Offset(p.dx + 6, p.dy - 6));
//     }
//
//     // ── 3. Draw smooth path — untouched from before ────────────────────────
//     if (smoothPath.length > 1) {
//       final pathPaint = Paint()
//         ..color = Colors.blue
//         ..strokeWidth = 2
//         ..strokeCap = StrokeCap.round
//         ..style = PaintingStyle.stroke;
//
//       final path = Path();
//       final first = _s(smoothPath[0].dx, smoothPath[0].dy);
//       path.moveTo(first.dx, first.dy);
//       for (int i = 1; i < smoothPath.length; i++) {
//         final p = _s(smoothPath[i].dx, smoothPath[i].dy);
//         path.lineTo(p.dx, p.dy);
//       }
//       canvas.drawPath(path, pathPaint);
//     }
//
//     // ── 4. Draw direction marker — untouched from before ───────────────────
//     final sp = _s(currentPos.dx, currentPos.dy);
//     final heading = _heading;
//     final cx = sp.dx;
//     final cy = sp.dy;
//
//     canvas.drawCircle(sp, 8,
//         Paint()..color = const Color(0xFF4285F4).withOpacity(0.15));
//     canvas.drawCircle(sp, 5,
//         Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
//     canvas.drawCircle(sp, 3.5,
//         Paint()..color = const Color(0xFF4285F4));
//
//     final tip   = Offset(cx + 8 * cos(heading), cy + 8 * sin(heading));
//     final left  = Offset(cx + 3.5 * cos(heading + pi * 0.65), cy + 3.5 * sin(heading + pi * 0.65));
//     final right = Offset(cx + 3.5 * cos(heading - pi * 0.65), cy + 3.5 * sin(heading - pi * 0.65));
//
//     final arrowPath = Path()
//       ..moveTo(tip.dx, tip.dy)
//       ..lineTo(left.dx, left.dy)
//       ..lineTo(right.dx, right.dy)
//       ..close();
//
//     canvas.drawPath(arrowPath, Paint()..color = const Color(0xFF4285F4));
//     canvas.drawPath(arrowPath,
//         Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
//   }
//
//   @override
//   bool shouldRepaint(covariant BLEPainter oldDelegate) {
//     return oldDelegate.smoothPath != smoothPath ||
//         oldDelegate.currentPos != currentPos ||
//         oldDelegate.floor != floor ||
//         oldDelegate.features != features;
//   }
// }



// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:localization_engine/localization_engine.dart';
//
// import 'package:rni_project_app/BLEPositionEstimator.dart';
// import 'package:rni_project_app/beacon_db.dart';
//
// void main() {
//   runApp(const BLEApp());
// }
//
// class BLEApp extends StatelessWidget {
//   const BLEApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: const BLEHome(),
//     );
//   }
// }
//
// class BLEHome extends StatefulWidget {
//   const BLEHome({super.key});
//
//   @override
//   State<BLEHome> createState() => _BLEHomeState();
// }
//
// class _BLEHomeState extends State<BLEHome> {
//   late BLEPositionEstimator estimator;
//   late LocalizationEngine engine;
//
//   StreamSubscription? _scanSubscription;
//   Timer? timer;
//
//   List<Offset> smoothPath = [];
//   Offset currentPos = const Offset(100, 100);
//
//   String confidence = "--";
//   String motion = "--";
//   String topBeacon = "--";
//   String topRssi = "--";
//   String statusMsg = "Press Start to begin scanning";
//
//   @override
//   void initState() {
//     super.initState();
//     estimator = BLEPositionEstimator(
//       beaconDb: rniBeaconDb,
//       windowS: 6.0,
//       floor: 0,
//     );
//     engine = LocalizationEngine("RNI");
//   }
//
//   Future<void> _requestPermissions() async {
//     await Permission.bluetoothScan.request();
//     await Permission.bluetoothConnect.request();
//     await Permission.locationWhenInUse.request();
//   }
//
//   void startScanning() async {
//     await _requestPermissions();
//
//     // Check permissions
//     final scan    = await Permission.bluetoothScan.status;
//     final connect = await Permission.bluetoothConnect.status;
//     final loc     = await Permission.locationWhenInUse.status;
//
//     debugPrint('SCAN: $scan, CONNECT: $connect, LOCATION: $loc');
//
//     if (!scan.isGranted || !connect.isGranted || !loc.isGranted) {
//       setState(() => statusMsg = 'Permissions not granted! Allow in settings.');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Permissions not granted! Please allow in settings.')),
//       );
//       return;
//     }
//
//     estimator.reset();
//     setState(() {
//       smoothPath.clear();
//       currentPos = const Offset(100, 100);
//       confidence = "--";
//       motion = "--";
//       topBeacon = "--";
//       topRssi = "--";
//       statusMsg = "Scanning... waiting for first 6 seconds";
//     });
//
//     // Feed every live beacon reading into the rolling buffer
//     _scanSubscription = engine.bluetoothScanResults.listen(
//           (data) {
//         if (data == null) return;
//         debugPrint('BLE data received: $data');
//         estimator.update(
//           [
//             BleReading(
//               name: data['name'] as String,
//               rssi: data['rssi'] as int,
//               timestamp: DateTime.parse(data['timestamp'] as String),
//             )
//           ],
//           walking: true,
//         );
//       },
//       onError: (e) {
//         debugPrint('Scan error: $e');
//         setState(() => statusMsg = 'Scan error: $e');
//       },
//     );
//
//     // Update UI every 1 second
//     timer = Timer.periodic(const Duration(seconds: 1), (_) {
//       final result = estimator.lastResult;
//       if (result != null) {
//         setState(() {
//           currentPos = Offset(result.smoothX, result.smoothY);
//           smoothPath.add(currentPos);
//           confidence = result.confidence;
//           motion = result.motionState;
//           topBeacon = result.rank1Beacon;
//           topRssi = result.rank1Rssi.toString();
//           statusMsg = "Live — updating every second";
//         });
//       }
//     });
//   }
//
//   void stopScanning() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     estimator.reset();
//     setState(() {
//       smoothPath.clear();
//       currentPos = const Offset(100, 100);
//       confidence = "--";
//       motion = "--";
//       topBeacon = "--";
//       topRssi = "--";
//       statusMsg = "Stopped. Press Start to begin again.";
//     });
//   }
//
//   @override
//   void dispose() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("BLE Real-Time Position Estimator"),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             // Info Card
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     "Position",
//                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 10),
//                   Text(
//                     "(${currentPos.dx.toStringAsFixed(1)}, ${currentPos.dy.toStringAsFixed(1)})",
//                     style: const TextStyle(fontSize: 22, color: Colors.blue),
//                   ),
//                   const SizedBox(height: 10),
//                   Text("Top Beacon: $topBeacon"),
//                   Text("Confidence: $confidence"),
//                   Text("Motion: $motion"),
//                   Text("RSSI: $topRssi"),
//                   const SizedBox(height: 8),
//                   Text(
//                     statusMsg,
//                     style: const TextStyle(fontSize: 12, color: Colors.grey),
//                   ),
//                 ],
//               ),
//             ),
//
//             const SizedBox(height: 20),
//
//             // Buttons
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: startScanning,
//                     child: const Text("Start"),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: stopScanning,
//                     child: const Text("Stop"),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 20),
//
//             // Canvas
//             Expanded(
//               child: Container(
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border.all(color: Colors.black26),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: InteractiveViewer(
//                   minScale: 0.5,
//                   maxScale: 5.0,
//                   boundaryMargin: const EdgeInsets.all(100),
//                   child: SizedBox(
//                     width: 600,
//                     height: 600,
//                     child: CustomPaint(
//                       painter: BLEPainter(
//                         smoothPath: smoothPath,
//                         currentPos: currentPos,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class BLEPainter extends CustomPainter {
//   final List<Offset> smoothPath;
//   final Offset currentPos;
//
//   BLEPainter({required this.smoothPath, required this.currentPos});
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final beaconPaint = Paint()
//       ..color = Colors.grey
//       ..style = PaintingStyle.fill;
//
//     final pathPaint = Paint()
//       ..color = Colors.blue
//       ..strokeWidth = 4
//       ..strokeCap = StrokeCap.round;
//
//     final markerPaint = Paint()..color = Colors.orange;
//
//     // Draw floor 0 beacons
//     for (final entry in rniBeaconDb.entries) {
//       final beacon = entry.value;
//       if (beacon.floor != 0) continue;
//
//       canvas.drawCircle(
//         Offset(beacon.lx.toDouble(), beacon.ly.toDouble()),
//         5,
//         beaconPaint,
//       );
//
//       final textPainter = TextPainter(
//         text: TextSpan(
//           text: entry.key.substring(entry.key.length - 4),
//           style: const TextStyle(color: Colors.grey, fontSize: 10),
//         ),
//         textDirection: TextDirection.ltr,
//       );
//       textPainter.layout();
//       textPainter.paint(
//         canvas,
//         Offset(beacon.lx.toDouble() + 6, beacon.ly.toDouble() - 6),
//       );
//     }
//
//     // Draw smooth path
//     for (int i = 0; i < smoothPath.length - 1; i++) {
//       canvas.drawLine(smoothPath[i], smoothPath[i + 1], pathPaint);
//     }
//
//     // Draw moving marker
//     canvas.drawCircle(currentPos, 14, markerPaint);
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }

// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:localization_engine/localization_engine.dart';
//
// import 'package:rni_project_app/BLEPositionEstimator.dart';
// import 'package:rni_project_app/beacon_db.dart';
//
// void main() {
//   runApp(const BLEApp());
// }
//
// class BLEApp extends StatelessWidget {
//   const BLEApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: const BLEHome(),
//     );
//   }
// }
//
// class BLEHome extends StatefulWidget {
//   const BLEHome({super.key});
//   @override
//   State<BLEHome> createState() => _BLEHomeState();
// }
//
// class _BLEHomeState extends State<BLEHome> {
//   late BLEPositionEstimator estimator;
//   late LocalizationEngine engine;
//
//   StreamSubscription? _scanSubscription;
//   Timer? timer;
//
//   int currentFloor = 0;
//
//   // GeoJSON features
//   List<dynamic> _allFeatures = [];
//   bool _mapLoaded = false;
//
//   // canvas state
//   Offset currentPos = const Offset(100, 100);
//   List<Offset> smoothPath = [];
//
//   String confidence = "--";
//   String motion = "--";
//   String topBeacon = "--";
//   String topRssi = "--";
//   String statusMsg = "Press Start to begin scanning";
//
//   @override
//   void initState() {
//     super.initState();
//     estimator = BLEPositionEstimator(
//       beaconDb: rniBeaconDb,
//       windowS: 6.0,
//       floor: 0,
//     );
//     engine = LocalizationEngine("RNI");
//     _loadGeoJSON();
//   }
//
//   Future<void> _loadGeoJSON() async {
//     try {
//       final raw = await rootBundle.loadString(
//           'assets/maps/converted_geojson.geojson');
//       final data = json.decode(raw);
//       setState(() {
//         _allFeatures = data['features'] as List<dynamic>;
//         _mapLoaded = true;
//       });
//     } catch (e) {
//       debugPrint('GeoJSON load error: $e');
//     }
//   }
//
//   List<dynamic> get _currentFloorFeatures => _allFeatures.where((f) {
//     final props = f['properties'] ?? {};
//     final floor = props['floor'] ?? props['level'];
//     return floor == currentFloor;
//   }).toList();
//
//   Future<void> _requestPermissions() async {
//     await Permission.bluetoothScan.request();
//     await Permission.bluetoothConnect.request();
//     await Permission.locationWhenInUse.request();
//   }
//
//   void startScanning() async {
//     await _requestPermissions();
//
//     final scan    = await Permission.bluetoothScan.status;
//     final connect = await Permission.bluetoothConnect.status;
//     final loc     = await Permission.locationWhenInUse.status;
//
//     if (!scan.isGranted || !connect.isGranted || !loc.isGranted) {
//       setState(() => statusMsg = 'Permissions not granted! Allow in settings.');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Permissions not granted!')),
//       );
//       return;
//     }
//
//     estimator.reset();
//     setState(() {
//       smoothPath.clear();
//       currentPos = const Offset(100, 100);
//       confidence = "--";
//       motion = "--";
//       topBeacon = "--";
//       topRssi = "--";
//       statusMsg = "Scanning... waiting for first 6 seconds";
//     });
//
//     _scanSubscription = engine.bluetoothScanResults.listen(
//           (data) {
//         if (data == null) return;
//         estimator.update(
//           [BleReading(
//             name: data['name'] as String,
//             rssi: data['rssi'] as int,
//             timestamp: DateTime.parse(data['timestamp'] as String),
//           )],
//           walking: true,
//         );
//       },
//       onError: (e) {
//         debugPrint('Scan error: $e');
//         setState(() => statusMsg = 'Scan error: $e');
//       },
//     );
//
//     timer = Timer.periodic(const Duration(seconds: 1), (_) {
//       final result = estimator.lastResult;
//       if (result != null) {
//         final newPos = Offset(result.smoothX, result.smoothY);
//         setState(() {
//           currentPos = newPos;
//           smoothPath.add(newPos);
//           confidence = result.confidence;
//           motion = result.motionState;
//           topBeacon = result.rank1Beacon;
//           topRssi = result.rank1Rssi.toString();
//           statusMsg = "Live — updating every second";
//         });
//       } else {
//         setState(() {
//           statusMsg = "⚠️ No beacons detected — move closer to a beacon";
//         });
//       }
//     });
//   }
//
//   void stopScanning() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     estimator.reset();
//     setState(() {
//       smoothPath.clear();
//       currentPos = const Offset(100, 100);
//       confidence = "--";
//       motion = "--";
//       topBeacon = "--";
//       topRssi = "--";
//       statusMsg = "Stopped. Press Start to begin again.";
//     });
//   }
//
//   @override
//   void dispose() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("BLE Real-Time Position Estimator"),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             // Info Card
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text("Position",
//                           style: TextStyle(
//                               fontSize: 20, fontWeight: FontWeight.bold)),
//                       Row(
//                         children: [
//                           const Text("Floor: ",
//                               style: TextStyle(fontSize: 13)),
//                           DropdownButton<int>(
//                             value: currentFloor,
//                             items: [0, 1, 2, 3, 4, 5, 6]
//                                 .map((f) => DropdownMenuItem(
//                               value: f,
//                               child: Text('$f'),
//                             ))
//                                 .toList(),
//                             onChanged: (f) {
//                               if (f != null) {
//                                 setState(() {
//                                   currentFloor = f;
//                                   smoothPath.clear();
//                                 });
//                               }
//                             },
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Text("Top Beacon: $topBeacon"),
//                   Text(
//                       "Confidence: $confidence  ·  Motion: $motion  ·  RSSI: $topRssi"),
//                   const SizedBox(height: 4),
//                   Text(statusMsg,
//                       style:
//                       const TextStyle(fontSize: 11, color: Colors.grey)),
//                 ],
//               ),
//             ),
//
//             const SizedBox(height: 12),
//
//             // Buttons
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: startScanning,
//                     child: const Text("Start"),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: stopScanning,
//                     child: const Text("Stop"),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 12),
//
//             // Canvas with GeoJSON map + beacons + marker
//             Expanded(
//               child: Container(
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border.all(color: Colors.black26),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: InteractiveViewer(
//                     minScale: 0.5,
//                     maxScale: 8.0,
//                     boundaryMargin: const EdgeInsets.all(100),
//                     child: SizedBox(
//                       width: 600,
//                       height: 600,
//                       child: CustomPaint(
//                         painter: BLEPainter(
//                           smoothPath: smoothPath,
//                           currentPos: currentPos,
//                           features: _mapLoaded
//                               ? _currentFloorFeatures
//                               : [],
//                           currentFloor: currentFloor,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class BLEPainter extends CustomPainter {
//   final List<Offset> smoothPath;
//   final Offset currentPos;
//   final List<dynamic> features;
//   final int currentFloor;
//
//   BLEPainter({
//     required this.smoothPath,
//     required this.currentPos,
//     required this.features,
//     required this.currentFloor,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     // ── 1. Draw GeoJSON floor map using coordinnatesLocal ─────────────────
//     for (final feature in features) {
//       final geom = feature['geometry'];
//       final props = feature['properties'] ?? {};
//       final type = props['type'] ?? '';
//       final geomType = geom['type'];
//       final localCoords = geom['coordinnatesLocal'];
//       if (localCoords == null) continue;
//
//       if (geomType == 'Polygon') {
//         final rings = localCoords as List;
//         if (rings.isEmpty) continue;
//         final outerRing = rings[0] as List;
//         if (outerRing.isEmpty || outerRing[0] is! List) continue;
//
//         final pts = outerRing
//             .map<Offset>((p) =>
//             Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
//             .toList();
//         if (pts.length < 3) continue;
//
//         final path = Path()..moveTo(pts[0].dx, pts[0].dy);
//         for (int i = 1; i < pts.length; i++) {
//           path.lineTo(pts[i].dx, pts[i].dy);
//         }
//         path.close();
//
//         Color fillColor;
//         Color strokeColor;
//         double strokeWidth;
//
//         if (type.toString().startsWith('Wall')) {
//           fillColor = Colors.grey.shade600.withOpacity(0.7);
//           strokeColor = Colors.grey.shade800;
//           strokeWidth = 0.5;
//         } else if (type == 'Room') {
//           fillColor = Colors.blue.withOpacity(0.08);
//           strokeColor = Colors.blue.withOpacity(0.5);
//           strokeWidth = 0.8;
//         } else if (type == 'Boundary') {
//           fillColor = Colors.transparent;
//           strokeColor = Colors.black54;
//           strokeWidth = 1.0;
//         } else if (['Male Washroom', 'Female Washroom', 'Accessible Washroom']
//             .contains(type)) {
//           fillColor = Colors.cyan.withOpacity(0.15);
//           strokeColor = Colors.cyan.shade400;
//           strokeWidth = 0.8;
//         } else if (['Stairs', 'Lift'].contains(type)) {
//           fillColor = Colors.orange.withOpacity(0.15);
//           strokeColor = Colors.orange.shade400;
//           strokeWidth = 0.8;
//         } else if (type == 'Cafeteria') {
//           fillColor = Colors.green.withOpacity(0.15);
//           strokeColor = Colors.green.shade400;
//           strokeWidth = 0.8;
//         } else {
//           fillColor = Colors.blueGrey.withOpacity(0.04);
//           strokeColor = Colors.blueGrey.withOpacity(0.25);
//           strokeWidth = 0.5;
//         }
//
//         canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
//         canvas.drawPath(path,
//             Paint()
//               ..color = strokeColor
//               ..style = PaintingStyle.stroke
//               ..strokeWidth = strokeWidth);
//
//         // Room label
//         final name = props['name'] ?? '';
//         if (name.isNotEmpty && name != 'undefined' && type == 'Room') {
//           final centroid = props['centroid'];
//           if (centroid != null && centroid is List && centroid.length >= 2) {
//             // centroid is in GPS — skip label (no local centroid available)
//           }
//         }
//       } else if (geomType == 'LineString') {
//         if (localCoords is! List || localCoords.isEmpty) continue;
//         if (localCoords[0] is! List) continue;
//         final pts = localCoords
//             .map<Offset>((p) =>
//             Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
//             .toList();
//         if (pts.length < 2) continue;
//         final path = Path()..moveTo(pts[0].dx, pts[0].dy);
//         for (int i = 1; i < pts.length; i++) {
//           path.lineTo(pts[i].dx, pts[i].dy);
//         }
//         canvas.drawPath(
//             path,
//             Paint()
//               ..color = Colors.grey.withOpacity(0.2)
//               ..style = PaintingStyle.stroke
//               ..strokeWidth = 0.3);
//       }
//     }
//
//     // ── 2. Draw beacon dots ───────────────────────────────────────────────
//     final beaconPaint = Paint()
//       ..color = Colors.grey
//       ..style = PaintingStyle.fill;
//
//     for (final entry in rniBeaconDb.entries) {
//       final beacon = entry.value;
//       if (beacon.floor != currentFloor) continue;
//
//       canvas.drawCircle(
//         Offset(beacon.lx.toDouble(), beacon.ly.toDouble()),
//         5,
//         beaconPaint,
//       );
//
//       final textPainter = TextPainter(
//         text: TextSpan(
//           text: entry.key.substring(entry.key.length - 4),
//           style: const TextStyle(color: Colors.grey, fontSize: 8),
//         ),
//         textDirection: TextDirection.ltr,
//       );
//       textPainter.layout();
//       textPainter.paint(
//         canvas,
//         Offset(beacon.lx.toDouble() + 6, beacon.ly.toDouble() - 6),
//       );
//     }
//
//     // ── 3. Draw smooth path ───────────────────────────────────────────────
//     if (smoothPath.length > 1) {
//       final pathPaint = Paint()
//         ..color = Colors.blue
//         ..strokeWidth = 3
//         ..strokeCap = StrokeCap.round
//         ..style = PaintingStyle.stroke;
//
//       final path = Path()
//         ..moveTo(smoothPath[0].dx, smoothPath[0].dy);
//       for (int i = 1; i < smoothPath.length; i++) {
//         path.lineTo(smoothPath[i].dx, smoothPath[i].dy);
//       }
//       canvas.drawPath(path, pathPaint);
//     }
//
//     // ── 4. Draw orange user marker ────────────────────────────────────────
//     canvas.drawCircle(
//       currentPos,
//       14,
//       Paint()..color = Colors.orange.withOpacity(0.3),
//     );
//     canvas.drawCircle(
//       currentPos,
//       9,
//       Paint()..color = Colors.orange,
//     );
//     canvas.drawCircle(
//       currentPos,
//       9,
//       Paint()
//         ..color = Colors.white
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 2,
//     );
//   }
//
//   @override
//   bool shouldRepaint(covariant BLEPainter old) =>
//       old.currentPos != currentPos ||
//           old.smoothPath.length != smoothPath.length ||
//           old.features != features ||
//           old.currentFloor != currentFloor;
// }


// import 'dart:async';
// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:localization_engine/localization_engine.dart';
//
// import 'package:rni_project_app/BLEPositionEstimator.dart';
// import 'package:rni_project_app/beacon_db.dart';
//
// void main() {
//   runApp(const BLEApp());
// }
//
// class BLEApp extends StatelessWidget {
//   const BLEApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: const BLEHome(),
//     );
//   }
// }
//
// class BLEHome extends StatefulWidget {
//   const BLEHome({super.key});
//   @override
//   State<BLEHome> createState() => _BLEHomeState();
// }
//
// class _BLEHomeState extends State<BLEHome> {
//   late BLEPositionEstimator estimator;
//   late LocalizationEngine engine;
//
//   StreamSubscription? _scanSubscription;
//   Timer? timer;
//
//   int currentFloor = 0;
//   List<dynamic> _allFeatures = [];
//   bool _mapLoaded = false;
//
//   Offset currentPos = const Offset(100, 100);
//   List<Offset> smoothPath = [];
//
//   String confidence = "--";
//   String motion = "--";
//   String topBeacon = "--";
//   String topRssi = "--";
//   String statusMsg = "Press Start to begin scanning";
//
//   @override
//   void initState() {
//     super.initState();
//     estimator = BLEPositionEstimator(
//       beaconDb: rniBeaconDb,
//       windowS: 6.0,
//       floor: 0,
//     );
//     engine = LocalizationEngine("RNI");
//     _loadGeoJSON();
//   }
//
//   Future<void> _loadGeoJSON() async {
//     try {
//       final raw = await rootBundle
//           .loadString('assets/maps/converted_geojson.geojson');
//       final data = json.decode(raw);
//       setState(() {
//         _allFeatures = data['features'] as List<dynamic>;
//         _mapLoaded = true;
//       });
//     } catch (e) {
//       debugPrint('GeoJSON load error: $e');
//     }
//   }
//
//   List<dynamic> get _currentFloorFeatures => _allFeatures.where((f) {
//     final props = f['properties'] ?? {};
//     final floor = props['floor'] ?? props['level'];
//     return floor == currentFloor;
//   }).toList();
//
//   Future<void> _requestPermissions() async {
//     await Permission.bluetoothScan.request();
//     await Permission.bluetoothConnect.request();
//     await Permission.locationWhenInUse.request();
//   }
//
//   void startScanning() async {
//     await _requestPermissions();
//
//     final scan    = await Permission.bluetoothScan.status;
//     final connect = await Permission.bluetoothConnect.status;
//     final loc     = await Permission.locationWhenInUse.status;
//
//     if (!scan.isGranted || !connect.isGranted || !loc.isGranted) {
//       setState(() => statusMsg = 'Permissions not granted! Allow in settings.');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Permissions not granted!')),
//       );
//       return;
//     }
//
//     estimator.reset();
//     setState(() {
//       smoothPath.clear();
//       currentPos = const Offset(100, 100);
//       confidence = "--";
//       motion = "--";
//       topBeacon = "--";
//       topRssi = "--";
//       statusMsg = "Scanning... waiting for first 6 seconds";
//     });
//
//     _scanSubscription = engine.bluetoothScanResults.listen(
//           (data) {
//         if (data == null) return;
//         estimator.update(
//           [BleReading(
//             name: data['name'] as String,
//             rssi: data['rssi'] as int,
//             timestamp: DateTime.parse(data['timestamp'] as String),
//           )],
//           walking: true,
//         );
//       },
//       onError: (e) {
//         debugPrint('Scan error: $e');
//         setState(() => statusMsg = 'Scan error: $e');
//       },
//     );
//
//     timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
//       final result = estimator.lastResult;
//       if (result != null) {
//         final newPos = Offset(result.smoothX, result.smoothY);
//
//         // detect walking from position delta — more responsive than estimator heuristic
//         final dx = newPos.dx - currentPos.dx;
//         final dy = newPos.dy - currentPos.dy;
//         final moved = sqrt(dx * dx + dy * dy);
//         final isWalking = moved > 2.0; // moved more than 2px = walking
//
//         setState(() {
//           currentPos = newPos;
//           if (isWalking) smoothPath.add(newPos);
//           confidence = result.confidence;
//           motion = isWalking ? 'walking' : 'stationary';
//           topBeacon = result.rank1Beacon;
//           topRssi = result.rank1Rssi.toString();
//           statusMsg = isWalking ? "Live — walking" : "Live — stationary";
//         });
//       } else {
//         setState(() {
//           statusMsg = "⚠️ No beacons detected — move closer to a beacon";
//         });
//       }
//     });
//   }
//
//   void stopScanning() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     estimator.reset();
//     setState(() {
//       smoothPath.clear();
//       currentPos = const Offset(100, 100);
//       confidence = "--";
//       motion = "--";
//       topBeacon = "--";
//       topRssi = "--";
//       statusMsg = "Stopped. Press Start to begin again.";
//     });
//   }
//
//   @override
//   void dispose() {
//     _scanSubscription?.cancel();
//     timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("BLE Real-Time Position Estimator"),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             // Info Card
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text("Position",
//                           style: TextStyle(
//                               fontSize: 20, fontWeight: FontWeight.bold)),
//                       Row(
//                         children: [
//                           const Text("Floor: ",
//                               style: TextStyle(fontSize: 13)),
//                           DropdownButton<int>(
//                             value: currentFloor,
//                             items: [0, 1, 2, 3, 4, 5, 6]
//                                 .map((f) => DropdownMenuItem(
//                               value: f,
//                               child: Text('$f'),
//                             ))
//                                 .toList(),
//                             onChanged: (f) {
//                               if (f != null) {
//                                 setState(() {
//                                   currentFloor = f;
//                                   smoothPath.clear();
//                                 });
//                               }
//                             },
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Text("Top Beacon: $topBeacon"),
//                   Text(
//                       "Confidence: $confidence  ·  Motion: $motion  ·  RSSI: $topRssi"),
//                   const SizedBox(height: 4),
//                   Text(statusMsg,
//                       style:
//                       const TextStyle(fontSize: 11, color: Colors.grey)),
//                 ],
//               ),
//             ),
//
//             const SizedBox(height: 12),
//
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: startScanning,
//                     child: const Text("Start"),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: stopScanning,
//                     child: const Text("Stop"),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 12),
//
//             // Canvas — pannable/zoomable, map + beacons + marker all together
//             Expanded(
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border.all(color: Colors.black12),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(12),
//                   child: InteractiveViewer(
//                     constrained: false,       // ← allows panning beyond widget bounds
//                     minScale: 0.3,
//                     maxScale: 10.0,
//                     boundaryMargin: const EdgeInsets.all(200),
//                     child: SizedBox(
//                       width: 1200,            // ← big canvas so you can pan around
//                       height: 1200,
//                       child: CustomPaint(
//                         painter: BLEPainter(
//                           smoothPath: smoothPath,
//                           currentPos: currentPos,
//                           features:
//                           _mapLoaded ? _currentFloorFeatures : [],
//                           currentFloor: currentFloor,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ── Painter ───────────────────────────────────────────────────────────────────
// class BLEPainter extends CustomPainter {
//   final List<Offset> smoothPath;
//   final Offset currentPos;
//   final List<dynamic> features;
//   final int currentFloor;
//
//   BLEPainter({
//     required this.smoothPath,
//     required this.currentPos,
//     required this.features,
//     required this.currentFloor,
//   });
//
//   double get _heading {
//     if (smoothPath.length < 2) return -pi / 2;
//     final prev = smoothPath[smoothPath.length - 2];
//     final curr = smoothPath[smoothPath.length - 1];
//     return atan2(curr.dy - prev.dy, curr.dx - prev.dx);
//   }
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     // ── 1. GeoJSON floor map ──────────────────────────────────────────────
//     for (final feature in features) {
//       final geom = feature['geometry'];
//       final props = feature['properties'] ?? {};
//       final type = props['type'] ?? '';
//       final geomType = geom['type'];
//       final localCoords = geom['coordinnatesLocal'];
//       if (localCoords == null) continue;
//
//       if (geomType == 'Polygon') {
//         final rings = localCoords as List;
//         if (rings.isEmpty) continue;
//         final outerRing = rings[0] as List;
//         if (outerRing.isEmpty || outerRing[0] is! List) continue;
//         final pts = outerRing
//             .map<Offset>((p) =>
//             Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
//             .toList();
//         if (pts.length < 3) continue;
//
//         final path = Path()..moveTo(pts[0].dx, pts[0].dy);
//         for (int i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
//         path.close();
//
//         Color fill; Color stroke; double sw;
//         if (type.toString().startsWith('Wall')) {
//           fill = Colors.grey.shade600.withOpacity(0.7); stroke = Colors.grey.shade800; sw = 0.5;
//         } else if (type == 'Room') {
//           fill = Colors.blue.withOpacity(0.08); stroke = Colors.blue.withOpacity(0.5); sw = 0.8;
//         } else if (type == 'Boundary') {
//           fill = Colors.transparent; stroke = Colors.black54; sw = 1.0;
//         } else if (['Male Washroom','Female Washroom','Accessible Washroom'].contains(type)) {
//           fill = Colors.cyan.withOpacity(0.15); stroke = Colors.cyan.shade400; sw = 0.8;
//         } else if (['Stairs','Lift'].contains(type)) {
//           fill = Colors.orange.withOpacity(0.15); stroke = Colors.orange.shade400; sw = 0.8;
//         } else if (type == 'Cafeteria') {
//           fill = Colors.green.withOpacity(0.15); stroke = Colors.green.shade400; sw = 0.8;
//         } else {
//           fill = Colors.blueGrey.withOpacity(0.04); stroke = Colors.blueGrey.withOpacity(0.25); sw = 0.5;
//         }
//
//         canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
//         canvas.drawPath(path, Paint()..color = stroke..style = PaintingStyle.stroke..strokeWidth = sw);
//
//       } else if (geomType == 'LineString') {
//         if (localCoords is! List || localCoords.isEmpty || localCoords[0] is! List) continue;
//         final pts = localCoords
//             .map<Offset>((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
//             .toList();
//         if (pts.length < 2) continue;
//         final path = Path()..moveTo(pts[0].dx, pts[0].dy);
//         for (int i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
//         canvas.drawPath(path, Paint()..color = Colors.grey.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 0.3);
//       }
//     }
//
//     // ── 2. Beacon dots ────────────────────────────────────────────────────
//     for (final entry in rniBeaconDb.entries) {
//       final beacon = entry.value;
//       if (beacon.floor != currentFloor) continue;
//       canvas.drawCircle(
//         Offset(beacon.lx.toDouble(), beacon.ly.toDouble()),
//         3,
//         Paint()..color = Colors.grey.shade400,
//       );
//       final tp = TextPainter(
//         text: TextSpan(
//           text: entry.key.substring(entry.key.length - 4),
//           style: const TextStyle(color: Colors.grey, fontSize: 7),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout();
//       tp.paint(canvas,
//           Offset(beacon.lx.toDouble() + 4, beacon.ly.toDouble() - 5));
//     }
//
//     // ── 3. Path trail ─────────────────────────────────────────────────────
//     if (smoothPath.length > 1) {
//       final path = Path()..moveTo(smoothPath[0].dx, smoothPath[0].dy);
//       for (int i = 1; i < smoothPath.length; i++) {
//         path.lineTo(smoothPath[i].dx, smoothPath[i].dy);
//       }
//       canvas.drawPath(
//           path,
//           Paint()
//             ..color = Colors.blue.withOpacity(0.4)
//             ..strokeWidth = 2
//             ..strokeCap = StrokeCap.round
//             ..style = PaintingStyle.stroke);
//     }
//
//     // ── 4. Google Maps style direction marker ─────────────────────────────
//     final heading = _heading;
//     final cx = currentPos.dx;
//     final cy = currentPos.dy;
//
//     // accuracy glow
//     canvas.drawCircle(currentPos, 12,
//         Paint()..color = const Color(0xFF4285F4).withOpacity(0.12));
//
//     // white border
//     canvas.drawCircle(currentPos, 7,
//         Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
//
//     // blue dot
//     canvas.drawCircle(currentPos, 5,
//         Paint()..color = const Color(0xFF4285F4));
//
//     // direction arrow
//     const arrowLen = 11.0;
//     const arrowWidth = 4.5;
//
//     final tip   = Offset(cx + arrowLen * cos(heading),   cy + arrowLen * sin(heading));
//     final left  = Offset(cx + arrowWidth * cos(heading + pi * 0.65), cy + arrowWidth * sin(heading + pi * 0.65));
//     final right = Offset(cx + arrowWidth * cos(heading - pi * 0.65), cy + arrowWidth * sin(heading - pi * 0.65));
//
//     final arrowPath = Path()
//       ..moveTo(tip.dx, tip.dy)
//       ..lineTo(left.dx, left.dy)
//       ..lineTo(right.dx, right.dy)
//       ..close();
//
//     canvas.drawPath(arrowPath, Paint()..color = const Color(0xFF4285F4));
//     canvas.drawPath(arrowPath,
//         Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1);
//   }
//
//   @override
//   bool shouldRepaint(covariant BLEPainter old) =>
//       old.currentPos != currentPos ||
//           old.smoothPath.length != smoothPath.length ||
//           old.features != features ||
//           old.currentFloor != currentFloor;
// }

