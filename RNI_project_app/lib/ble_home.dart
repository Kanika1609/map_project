// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:localization_engine/localization_engine.dart';
//
// import 'package:rni_project_app/BLEPositionEstimator.dart';
// import 'package:rni_project_app/services/api_service.dart';
// import 'package:rni_project_app/services/beacon_parser.dart';
//
// class BLEHome extends StatefulWidget {
//   final String venueName;
//   final String buildingId; // ADDED
//
//   const BLEHome({super.key, required this.venueName, required this.buildingId});
//
//   @override
//   State<BLEHome> createState() => _BLEHomeState();
// }
//
// class _BLEHomeState extends State<BLEHome> {
//   BLEPositionEstimator? estimator;
//   late LocalizationEngine engine;
//
//   StreamSubscription? _scanSubscription;
//   Timer? timer;
//
//   bool _isLoadingVenueData = true;
//   String? _venueLoadError;
//   Map<String, BeaconMeta> _beacons = {};
//   List<dynamic> _allFeatures = [];
//
//   List<int> availableFloors = [];
//   int currentFloor = 0;
//   bool isScanning = false;
//
//   List<Offset> smoothPath = [];
//   Offset currentPos = const Offset(200, 100);
//
//   String confidence = "--";
//   String motion = "--";
//   String topBeacon = "--";
//   String topRssi = "--";
//   String statusMsg = "Loading venue data...";
//
//   @override
//   void initState() {
//     super.initState();
//     engine = LocalizationEngine("Iwayplus");
//     _loadVenueData();
//   }
//
//   Future<void> _loadVenueData() async {
//     if (!mounted) return;
//     setState(() {
//       _isLoadingVenueData = true;
//       _venueLoadError = null;
//     });
//
//     try {
//       final rawBeacons = await ApiService.fetchBeaconsRaw(widget.venueName);
//       final allBeacons = parseBeaconsResponse(rawBeacons);
//
//       // ---- ADDED: keep only beacons belonging to the selected building ----
//       final beacons = Map<String, BeaconMeta>.fromEntries(
//         allBeacons.entries.where((e) => e.value.buildingId == widget.buildingId),
//       );
//       print('Beacons for building ${widget.buildingId}: ${beacons.length} / ${allBeacons.length}');
//       // -----------------------------------------------------------------------
//
//       if (beacons.isEmpty) {
//         throw Exception(
//             'No usable beacons returned for "${widget.venueName}" / building ${widget.buildingId}');
//       }
//
//       final rawGeoJson = await ApiService.fetchGeoJson(widget.venueName);
//       final rawFeatureCount = (rawGeoJson['features'] as List?)?.length ?? -1;
//       print('GEOJSON raw feature count: $rawFeatureCount');
//
//       final allRawFeatures = (rawGeoJson['features'] as List<dynamic>? ?? []);
//
//       // ---- ADDED: keep only features belonging to the selected building ----
//       final rawFeatures = allRawFeatures.where((f) {
//         final buildingId = f['building_ID']?.toString();
//         return buildingId == widget.buildingId;
//       }).toList();
//       print('Features for building ${widget.buildingId}: ${rawFeatures.length} / ${allRawFeatures.length}');
//       // -----------------------------------------------------------------------
//
//       if (rawFeatures.isNotEmpty) {
//         final firstGeom = rawFeatures.first['geometry'];
//         if (firstGeom is Map) {
//           print('First raw feature geometry keys: ${firstGeom.keys.toList()}');
//         }
//       }
//
//       final beaconsWithGps = beacons.values.where((b) => b.lat != null && b.lon != null).length;
//       print('Beacons with usable lat/lon: $beaconsWithGps / ${beacons.length}');
//
//       final perFloorCounts = <int, int>{};
//       for (final b in beacons.values) {
//         if (b.lat == null || b.lon == null) continue;
//         perFloorCounts[b.floor] = (perFloorCounts[b.floor] ?? 0) + 1;
//       }
//       print('GPS control points per floor: $perFloorCounts');
//
//       final floors = beacons.values.map((b) => b.floor).toSet().toList()..sort();
//
//       if (!mounted) return;
//       setState(() {
//         _beacons = beacons;
//         _allFeatures = rawFeatures;
//         availableFloors = floors;
//         currentFloor = floors.isNotEmpty ? floors.first : 0;
//         estimator = BLEPositionEstimator(
//           beaconDb: _beacons,
//           windowS: 6.0,
//           floor: currentFloor,
//         );
//         _isLoadingVenueData = false;
//         statusMsg = "Press Start to begin scanning";
//       });
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _venueLoadError = e.toString();
//         _isLoadingVenueData = false;
//       });
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
//     if (floor == currentFloor || estimator == null) return;
//
//     final wasScanning = isScanning;
//
//     _scanSubscription?.cancel();
//     timer?.cancel();
//
//     setState(() {
//       currentFloor = floor;
//       estimator = BLEPositionEstimator(
//         beaconDb: _beacons,
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
//     if (wasScanning) {
//       startScanning();
//     }
//   }
//
//   void startScanning() async {
//     if (estimator == null) return;
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
//     estimator!.reset();
//     setState(() {
//       _resetDisplayState(status: "Scanning... waiting for first 6 seconds");
//       isScanning = true;
//     });
//
//     _scanSubscription = engine.bluetoothScanResults.listen(
//           (data) {
//         if (data == null) return;
//         estimator!.update(
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
//       final result = estimator!.lastResult;
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
//     estimator?.reset();
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
//         title: Text("BLE Position Estimator — ${widget.venueName}"),
//         centerTitle: true,
//       ),
//       body: _buildBody(),
//     );
//   }
//
//   Widget _buildBody() {
//     if (_isLoadingVenueData) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     if (_venueLoadError != null) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Icon(Icons.error_outline, color: Colors.red, size: 40),
//               const SizedBox(height: 12),
//               Text('Could not load venue data.\n$_venueLoadError',
//                   textAlign: TextAlign.center),
//               const SizedBox(height: 16),
//               ElevatedButton(onPressed: _loadVenueData, child: const Text('Retry')),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         children: [
//           // Info Card
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.grey.shade100,
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text(
//                       "Position",
//                       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       "Floor $currentFloor",
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.grey.shade700,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 15),
//                 Text(
//                   "(${currentPos.dx.toStringAsFixed(1)}, ${currentPos.dy.toStringAsFixed(1)})",
//                   style: const TextStyle(fontSize: 22, color: Colors.blue),
//                 ),
//                 const SizedBox(height: 15),
//                 Text("Top Beacon: $topBeacon"),
//                 Text("Confidence: $confidence"),
//                 Text("Motion: $motion"),
//                 Text("RSSI: $topRssi"),
//                 const SizedBox(height: 6),
//                 Text(statusMsg,
//                     style: const TextStyle(fontSize: 11, color: Colors.grey)),
//               ],
//             ),
//           ),
//
//           const SizedBox(height: 16),
//
//           // Floor switcher
//           Row(
//             children: [
//               const Text(
//                 "Floor:",
//                 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     children: availableFloors.map((floor) {
//                       final selected = floor == currentFloor;
//                       return Padding(
//                         padding: const EdgeInsets.only(right: 8),
//                         child: ChoiceChip(
//                           label: Text("Floor $floor"),
//                           selected: selected,
//                           onSelected: (_) => switchFloor(floor),
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 16),
//
//           // Buttons
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: startScanning,
//                   child: const Text("Start"),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: ElevatedButton(
//                   onPressed: stopScanning,
//                   child: const Text("Stop"),
//                 ),
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 20),
//
//           // Canvas
//           Expanded(
//             child: Container(
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 border: Border.all(color: Colors.black26),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: InteractiveViewer(
//                   constrained: false,
//                   minScale: 0.3,
//                   maxScale: 15.0,
//                   boundaryMargin: const EdgeInsets.all(200),
//                   child: SizedBox(
//                     width: 520,
//                     height: 300,
//                     child: CustomPaint(
//                       painter: BLEPainter(
//                         smoothPath: smoothPath,
//                         currentPos: currentPos,
//                         floor: currentFloor,
//                         features: _currentFloorFeatures,
//                         beacons: _beacons,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
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
//   final Map<String, BeaconMeta> beacons;
//
//   static const double _scale = 1.0;
//   static const double _pad   = 30.0;
//
//   BLEPainter({
//     required this.smoothPath,
//     required this.currentPos,
//     required this.floor,
//     required this.features,
//     required this.beacons,
//   });
//
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
//     // ── 1. Draw GeoJSON floor map using local coordinates ─────────────────
//     // FIX: the raw API response has a typo in this field name —
//     // "coordinnatesLocal" (double n) instead of "coordinatesLocal".
//     // We check both spellings so this works whether or not the alignment
//     // step (affine_fit.dart) normalizes the key.
//     int drawnCount = 0;
//     for (final feature in features) {
//       final geom = feature['geometry'];
//       if (geom == null) continue;
//       final props = feature['properties'] ?? {};
//       final type = (props['type'] ?? '').toString();
//       final geomType = geom['type'];
//       final localCoords = geom['coordinatesLocal'] ?? geom['coordinnatesLocal'];
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
//         drawnCount++;
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
//         drawnCount++;
//       }
//     }
//
//     // ── 2. Draw beacon dots for the currently selected floor ──────────────
//     // ── 2. Draw beacon dots for the currently selected floor ──────────────
//     final beaconPaint = Paint()
//       ..color = Colors.red
//       ..style = PaintingStyle.fill;
//
//     for (final entry in beacons.entries) {
//       final beacon = entry.value;
//       if (beacon.floor != floor) continue;
//
//       final p = _s(beacon.lx.toDouble(), beacon.ly.toDouble());
//
//       canvas.drawCircle(p, 2, beaconPaint);
//     }
//
//     // ── 3. Draw smooth path ────────────────────────────────────────────────
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
//     // ── 4. Draw direction marker (small size) ──────────────────────────────
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
//         Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1);
//   }
//
//   @override
//   bool shouldRepaint(covariant BLEPainter oldDelegate) {
//     return oldDelegate.smoothPath != smoothPath ||
//         oldDelegate.currentPos != currentPos ||
//         oldDelegate.floor != floor ||
//         oldDelegate.features != features ||
//         oldDelegate.beacons != beacons;
//   }
// }

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:localization_engine/localization_engine.dart';

import 'package:rni_project_app/BLEPositionEstimator.dart';
import 'package:rni_project_app/services/api_service.dart';
import 'package:rni_project_app/services/beacon_parser.dart';

class BLEHome extends StatefulWidget {
  final String venueName;
  final String buildingId; // ADDED

  const BLEHome({super.key, required this.venueName, required this.buildingId});

  @override
  State<BLEHome> createState() => _BLEHomeState();
}

class _BLEHomeState extends State<BLEHome> {
  BLEPositionEstimator? estimator;
  late LocalizationEngine engine;

  StreamSubscription? _scanSubscription;
  Timer? timer;

  bool _isLoadingVenueData = true;
  String? _venueLoadError;
  Map<String, BeaconMeta> _beacons = {};
  List<dynamic> _allFeatures = [];

  List<int> availableFloors = [];
  int currentFloor = 0;
  bool isScanning = false;

  List<Offset> smoothPath = [];
  Offset currentPos = const Offset(200, 100);

  String confidence = "--";
  String motion = "--";
  String topBeacon = "--";
  String topRssi = "--";
  String statusMsg = "Loading venue data...";

  // ── Zoom-responsive direction marker ──────────────────────────────────
  final TransformationController _transformController = TransformationController();
  double _markerSize = 8.0; // overall marker footprint, changes with zoom tier

  @override
  void initState() {
    super.initState();
    engine = LocalizationEngine("Iwayplus");
    _transformController.addListener(_onZoomChanged);
    _loadVenueData();
  }

  void _onZoomChanged() {
    final zoom = _transformController.value.getMaxScaleOnAxis();

    double newSize;
    if (zoom <= 1.0) {
      newSize = 8.0; // zoomed out / normal — original size
    } else if (zoom <= 3.0) {
      newSize = 6.0; // medium zoom
    } else {
      newSize = 3.0; // max zoom — bumped up (was 1.5) so it stays visible
    }

    if (newSize != _markerSize) {
      setState(() => _markerSize = newSize);
    }
  }

  Future<void> _loadVenueData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingVenueData = true;
      _venueLoadError = null;
    });

    try {
      final rawBeacons = await ApiService.fetchBeaconsRaw(widget.venueName);
      final allBeacons = parseBeaconsResponse(rawBeacons);

      // ---- ADDED: keep only beacons belonging to the selected building ----
      final beacons = Map<String, BeaconMeta>.fromEntries(
        allBeacons.entries.where((e) => e.value.buildingId == widget.buildingId),
      );
      print('Beacons for building ${widget.buildingId}: ${beacons.length} / ${allBeacons.length}');
      // -----------------------------------------------------------------------

      if (beacons.isEmpty) {
        throw Exception(
            'No usable beacons returned for "${widget.venueName}" / building ${widget.buildingId}');
      }

      final rawGeoJson = await ApiService.fetchGeoJson(widget.venueName);
      final rawFeatureCount = (rawGeoJson['features'] as List?)?.length ?? -1;
      print('GEOJSON raw feature count: $rawFeatureCount');

      final allRawFeatures = (rawGeoJson['features'] as List<dynamic>? ?? []);

      // ---- ADDED: keep only features belonging to the selected building ----
      final rawFeatures = allRawFeatures.where((f) {
        final buildingId = f['building_ID']?.toString();
        return buildingId == widget.buildingId;
      }).toList();
      print('Features for building ${widget.buildingId}: ${rawFeatures.length} / ${allRawFeatures.length}');
      // -----------------------------------------------------------------------

      if (rawFeatures.isNotEmpty) {
        final firstGeom = rawFeatures.first['geometry'];
        if (firstGeom is Map) {
          print('First raw feature geometry keys: ${firstGeom.keys.toList()}');
        }
      }

      final beaconsWithGps = beacons.values.where((b) => b.lat != null && b.lon != null).length;
      print('Beacons with usable lat/lon: $beaconsWithGps / ${beacons.length}');

      final perFloorCounts = <int, int>{};
      for (final b in beacons.values) {
        if (b.lat == null || b.lon == null) continue;
        perFloorCounts[b.floor] = (perFloorCounts[b.floor] ?? 0) + 1;
      }
      print('GPS control points per floor: $perFloorCounts');

      final floors = beacons.values.map((b) => b.floor).toSet().toList()..sort();

      if (!mounted) return;
      setState(() {
        _beacons = beacons;
        _allFeatures = rawFeatures;
        availableFloors = floors;
        currentFloor = floors.isNotEmpty ? floors.first : 0;
        estimator = BLEPositionEstimator(
          beaconDb: _beacons,
          windowS: 6.0,
          floor: currentFloor,
        );
        _isLoadingVenueData = false;
        statusMsg = "Press Start to begin scanning";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _venueLoadError = e.toString();
        _isLoadingVenueData = false;
      });
    }
  }

  List<dynamic> get _currentFloorFeatures => _allFeatures.where((f) {
    final props = f['properties'] ?? {};
    final floor = props['floor'] ?? props['level'];
    return floor == currentFloor;
  }).toList();

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  void _resetDisplayState({String? status}) {
    smoothPath.clear();
    currentPos = const Offset(200, 100);
    confidence = "--";
    motion = "--";
    topBeacon = "--";
    topRssi = "--";
    if (status != null) statusMsg = status;
  }

  void switchFloor(int floor) {
    if (floor == currentFloor || estimator == null) return;

    final wasScanning = isScanning;

    _scanSubscription?.cancel();
    timer?.cancel();

    setState(() {
      currentFloor = floor;
      estimator = BLEPositionEstimator(
        beaconDb: _beacons,
        windowS: 6.0,
        floor: currentFloor,
      );
      _resetDisplayState(
        status: wasScanning
            ? "Switched to floor $currentFloor — restarting scan..."
            : "Switched to floor $currentFloor. Press Start to begin scanning",
      );
      isScanning = false;
    });

    if (wasScanning) {
      startScanning();
    }
  }

  void startScanning() async {
    if (estimator == null) return;
    await _requestPermissions();

    final scan    = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    final loc     = await Permission.locationWhenInUse.status;

    if (!scan.isGranted || !connect.isGranted || !loc.isGranted) {
      setState(() => statusMsg = 'Permissions not granted! Allow in settings.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions not granted!')),
      );
      return;
    }

    estimator!.reset();
    setState(() {
      _resetDisplayState(status: "Scanning... waiting for first 6 seconds");
      isScanning = true;
    });

    _scanSubscription = engine.bluetoothScanResults.listen(
          (data) {
        if (data == null) return;
        estimator!.update(
          [BleReading(
            name: data['name'] as String,
            rssi: data['rssi'] as int,
            timestamp: DateTime.parse(data['timestamp'] as String),
          )],
          walking: true,
        );
      },
      onError: (e) {
        debugPrint('Scan error: $e');
        setState(() => statusMsg = 'Scan error: $e');
      },
    );

    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final result = estimator!.lastResult;
      if (result != null) {
        final newPos = Offset(result.smoothX, result.smoothY);
        setState(() {
          currentPos = newPos;
          confidence = result.confidence;
          motion = 'stationary';
          topBeacon = result.rank1Beacon;
          topRssi = result.rank1Rssi.toString();
          statusMsg = "Live — position updating (Floor $currentFloor)";
        });
      } else {
        setState(() {
          statusMsg = "⚠️ No beacons detected — move closer to a beacon";
        });
      }
    });
  }

  void stopScanning() {
    _scanSubscription?.cancel();
    timer?.cancel();
    estimator?.reset();
    setState(() {
      _resetDisplayState(status: "Stopped. Press Start to begin again.");
      isScanning = false;
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    timer?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("BLE Position Estimator — ${widget.venueName}"),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingVenueData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_venueLoadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text('Could not load venue data.\n$_venueLoadError',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadVenueData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          // Info Card — condensed to a couple of lines so it (plus the
          // floor switcher and buttons below) fits in roughly the top
          // third of the screen, leaving the map the rest of the space.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "(${currentPos.dx.toStringAsFixed(1)}, ${currentPos.dy.toStringAsFixed(1)})",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      "Floor $currentFloor",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Beacon: $topBeacon  •  Conf: $confidence  •  Motion: $motion  •  RSSI: $topRssi",
                  style: const TextStyle(fontSize: 11.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(statusMsg,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Floor switcher — compact chips
          Row(
            children: [
              const Text(
                "Floor:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availableFloors.map((floor) {
                      final selected = floor == currentFloor;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: SizedBox(
                          height: 30,
                          child: ChoiceChip(
                            label: Text("Floor $floor",
                                style: const TextStyle(fontSize: 11)),
                            selected: selected,
                            onSelected: (_) => switchFloor(floor),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Buttons — reduced height
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: startScanning,
                    child: const Text("Start"),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: stopScanning,
                    child: const Text("Stop"),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Canvas
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  transformationController: _transformController,
                  constrained: false,
                  minScale: 0.3,
                  maxScale: 15.0,
                  boundaryMargin: const EdgeInsets.all(200),
                  child: SizedBox(
                    width: 520,
                    height: 300,
                    child: CustomPaint(
                      painter: BLEPainter(
                        smoothPath: smoothPath,
                        currentPos: currentPos,
                        floor: currentFloor,
                        features: _currentFloorFeatures,
                        beacons: _beacons,
                        markerSize: _markerSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BLEPainter extends CustomPainter {
  final List<Offset> smoothPath;
  final Offset currentPos;
  final int floor;
  final List<dynamic> features;
  final Map<String, BeaconMeta> beacons;
  final double markerSize; // overall direction-marker footprint (shrinks on zoom)

  static const double _scale = 1.0;
  static const double _pad   = 30.0;

  BLEPainter({
    required this.smoothPath,
    required this.currentPos,
    required this.floor,
    required this.features,
    required this.beacons,
    this.markerSize = 8.0,
  });

  Offset _s(double x, double y) =>
      Offset(_pad + x * _scale, _pad + y * _scale);

  double get _heading {
    if (smoothPath.length < 2) return -pi / 2;
    final prev = _s(smoothPath[smoothPath.length - 2].dx, smoothPath[smoothPath.length - 2].dy);
    final curr = _s(smoothPath[smoothPath.length - 1].dx, smoothPath[smoothPath.length - 1].dy);
    return atan2(curr.dy - prev.dy, curr.dx - prev.dx);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── 1. Draw GeoJSON floor map using local coordinates ─────────────────
    // FIX: the raw API response has a typo in this field name —
    // "coordinnatesLocal" (double n) instead of "coordinatesLocal".
    // We check both spellings so this works whether or not the alignment
    // step (affine_fit.dart) normalizes the key.
    int drawnCount = 0;
    for (final feature in features) {
      final geom = feature['geometry'];
      if (geom == null) continue;
      final props = feature['properties'] ?? {};
      final type = (props['type'] ?? '').toString();
      final geomType = geom['type'];
      final localCoords = geom['coordinatesLocal'] ?? geom['coordinnatesLocal'];
      if (localCoords == null) continue;

      if (geomType == 'Polygon') {
        final rings = localCoords as List;
        if (rings.isEmpty) continue;
        final outerRing = rings[0] as List;
        if (outerRing.isEmpty || outerRing[0] is! List) continue;

        final pts = outerRing
            .map<Offset>((p) => _s((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList();
        if (pts.length < 3) continue;

        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();

        Color fillColor;
        Color strokeColor;
        double strokeWidth;

        if (type.startsWith('Wall')) {
          fillColor = Colors.grey.shade600.withOpacity(0.7);
          strokeColor = Colors.grey.shade800;
          strokeWidth = 0.5;
        } else if (type == 'Room' || type == 'Rooms') {
          fillColor = Colors.blue.withOpacity(0.08);
          strokeColor = Colors.blue.withOpacity(0.5);
          strokeWidth = 0.8;
        } else if (type == 'Boundary') {
          fillColor = Colors.transparent;
          strokeColor = Colors.black54;
          strokeWidth = 1.0;
        } else if ([
          'Male Washroom',
          'Female Washroom',
          'Accessible Washroom',
          'Washroom',
          'Powder Room',
        ].contains(type)) {
          fillColor = Colors.cyan.withOpacity(0.15);
          strokeColor = Colors.cyan.shade400;
          strokeWidth = 0.8;
        } else if (type.startsWith('Lift') || type == 'Stairs') {
          fillColor = Colors.orange.withOpacity(0.15);
          strokeColor = Colors.orange.shade400;
          strokeWidth = 0.8;
        } else if (type == 'Cafeteria' || type.contains('Sitting Area')) {
          fillColor = Colors.green.withOpacity(0.15);
          strokeColor = Colors.green.shade400;
          strokeWidth = 0.8;
        } else if (type == 'Restricted Area') {
          fillColor = Colors.red.withOpacity(0.08);
          strokeColor = Colors.red.withOpacity(0.4);
          strokeWidth = 0.6;
        } else {
          fillColor = Colors.blueGrey.withOpacity(0.04);
          strokeColor = Colors.blueGrey.withOpacity(0.25);
          strokeWidth = 0.5;
        }

        canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
        canvas.drawPath(path,
            Paint()
              ..color = strokeColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth);
        drawnCount++;
      } else if (geomType == 'LineString') {
        if (localCoords is! List || localCoords.isEmpty) continue;
        if (localCoords[0] is! List) continue;
        final pts = localCoords
            .map<Offset>((p) => _s((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList();
        if (pts.length < 2) continue;
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.grey.withOpacity(0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5);
        drawnCount++;
      }
    }

    // ── 2. Draw beacon dots for the currently selected floor ──────────────
    // Red, small, no labels.
    final beaconPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (final entry in beacons.entries) {
      final beacon = entry.value;
      if (beacon.floor != floor) continue;

      final p = _s(beacon.lx.toDouble(), beacon.ly.toDouble());

      canvas.drawCircle(p, 2, beaconPaint);
    }

    // ── 3. Draw smooth path ────────────────────────────────────────────────
    if (smoothPath.length > 1) {
      final pathPaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final first = _s(smoothPath[0].dx, smoothPath[0].dy);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < smoothPath.length; i++) {
        final p = _s(smoothPath[i].dx, smoothPath[i].dy);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, pathPaint);
    }

    // ── 4. Draw direction marker (footprint shrinks as you zoom in) ────────
    final sp = _s(currentPos.dx, currentPos.dy);
    final heading = _heading;
    final cx = sp.dx;
    final cy = sp.dy;

    final double factor = markerSize / 8.0; // 8.0 = original base size

    final double haloR   = 8 * factor;
    final double ringR   = 5 * factor;
    final double dotR    = 3.5 * factor;
    final double tipLen  = 8 * factor;
    final double wingLen = 3.5 * factor;

    // Keep outline strokes thin relative to the shape so they never
    // swallow the blue fill at small marker sizes (e.g. at max zoom).
    final double ringStroke  = (1.5 * factor).clamp(0.3, 1.5);
    final double arrowStroke = (0.8 * factor).clamp(0.2, 1.0);

    canvas.drawCircle(sp, haloR,
        Paint()..color = const Color(0xFF4285F4).withOpacity(0.15));
    canvas.drawCircle(sp, dotR,
        Paint()..color = const Color(0xFF4285F4));
    canvas.drawCircle(sp, ringR,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = ringStroke);

    final tip   = Offset(cx + tipLen * cos(heading), cy + tipLen * sin(heading));
    final left  = Offset(cx + wingLen * cos(heading + pi * 0.65), cy + wingLen * sin(heading + pi * 0.65));
    final right = Offset(cx + wingLen * cos(heading - pi * 0.65), cy + wingLen * sin(heading - pi * 0.65));

    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(arrowPath, Paint()..color = const Color(0xFF4285F4));
    canvas.drawPath(arrowPath,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = arrowStroke);
  }

  @override
  bool shouldRepaint(covariant BLEPainter oldDelegate) {
    return oldDelegate.smoothPath != smoothPath ||
        oldDelegate.currentPos != currentPos ||
        oldDelegate.floor != floor ||
        oldDelegate.features != features ||
        oldDelegate.beacons != beacons ||
        oldDelegate.markerSize != markerSize;
  }
}