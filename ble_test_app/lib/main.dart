// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
//
// import 'dart:async';
// import 'dart:convert';
//
// import 'ble_localizer.dart';
// import 'map_screen.dart';
//
// void main() => runApp(const MyApp());
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
// class HomePage extends StatefulWidget {
//   const HomePage({super.key});
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   // ── State ──────────────────────────────────────────────────────────────────
//   bool   _ready       = false;
//   bool   _running     = false;
//   String _status      = 'Loading model…';
//
//   double _predX       = 113.0;
//   double _predY       = 314.0;
//   double _confidence  = 0.0;
//   String _zone        = '';
//   int    _beaconsSeen = 0;
//
//   // Playback
//   int    _currentWindow  = 0;   // 0 = idle, 1–10 = active window
//   int    _totalWindows   = 10;
//   Timer? _playbackTimer;
//
//   // Loaded from CSV asset
//   List<Map<String, List<double>>> _windows = [];
//
//   BLELocalizer? _localizer;
//
//   @override
//   void initState() {
//     super.initState();
//     _boot();
//   }
//
//   @override
//   void dispose() {
//     _playbackTimer?.cancel();
//     super.dispose();
//   }
//
//   // ── Boot: load model + CSV ─────────────────────────────────────────────────
//   Future<void> _boot() async {
//     try {
//       _localizer = await BLELocalizer.fromAsset('assets/ble_model.json');
//       await _loadWindows();
//       if (mounted) {
//         setState(() {
//           _ready  = true;
//           _status = 'Ready — tap Play to simulate 60 s scan';
//         });
//       }
//     } catch (e) {
//       if (mounted) setState(() => _status = 'Boot failed: $e');
//     }
//   }
//
//   // ── Parse live_scan.csv and slice into 10 × 6 s windows ──────────────────
//   // Each beacon's readings are divided proportionally into 10 equal chunks.
//   // A beacon absent in a chunk simply isn't included that window.
//   Future<void> _loadWindows() async {
//     final raw = await rootBundle.loadString('assets/data/live_scan.csv');
//     final lines = const LineSplitter().convert(raw);
//
//     // Find header indices
//     final headers = lines.first.split(',').map((h) => h.trim()).toList();
//     final iName  = headers.indexOf('Beacon Name');
//     final iRssis = headers.indexOf('RSSIs');
//
//     // Build per-beacon full RSSI list
//     final beaconData = <String, List<double>>{};
//     for (final line in lines.skip(1)) {
//       if (line.trim().isEmpty) continue;
//
//       // The RSSI column contains commas, so we can't just split on ','
//       // CSV structure: X,Y,Floor,Beacon Name,RSSIs...,Duration,...
//       // We know iName=3 and RSSIs is everything between the 5th comma
//       // and the last few columns. Safest: split on first iRssis commas,
//       // then take the rest up to Duration.
//       final parts = line.split(',');
//       final name  = parts[iName].trim();
//       // RSSIs spans from index iRssis up to (but not including) the
//       // column after RSSIs — "Duration" is always "60s" so find it.
//       final durationIdx = parts.indexWhere(
//               (p) => p.trim() == '60s', iRssis);
//       final rssiParts = durationIdx > iRssis
//           ? parts.sublist(iRssis, durationIdx)
//           : parts.sublist(iRssis);
//
//       final rssis = rssiParts
//           .map((v) => double.tryParse(v.trim()))
//           .whereType<double>()
//           .toList();
//
//       if (rssis.isNotEmpty) beaconData[name] = rssis;
//     }
//
//     // Slice each beacon into 10 proportional windows
//     const numWindows = 10;
//     final windows = List.generate(numWindows, (_) => <String, List<double>>{});
//
//     beaconData.forEach((beacon, rssis) {
//       final n = rssis.length;
//       for (int w = 0; w < numWindows; w++) {
//         final start = (w * n / numWindows).round();
//         final end   = ((w + 1) * n / numWindows).round();
//         final chunk = rssis.sublist(start, end);
//         if (chunk.isNotEmpty) windows[w][beacon] = chunk;
//       }
//     });
//
//     _windows      = windows;
//     _totalWindows = windows.length;
//   }
//
//   // ── Playback: run one window every 6 s ────────────────────────────────────
//   void _startPlayback() {
//     if (!_ready || _running || _windows.isEmpty) return;
//     setState(() {
//       _running        = true;
//       _currentWindow  = 0;
//       _status         = 'Simulating scan…';
//     });
//     _runWindow(0);   // fire immediately for window 0
//     _playbackTimer = Timer.periodic(const Duration(seconds: 6), (t) {
//       final next = _currentWindow + 1;
//       if (next >= _totalWindows) {
//         t.cancel();
//         if (mounted) setState(() { _running = false; _status = 'Done — all 10 windows'; });
//         return;
//       }
//       _runWindow(next);
//     });
//   }
//
//   void _stopPlayback() {
//     _playbackTimer?.cancel();
//     _playbackTimer = null;
//     if (mounted) setState(() { _running = false; _status = 'Stopped'; });
//   }
//
//   void _runWindow(int w) {
//     if (_localizer == null || !mounted) return;
//     final scan = _windows[w];
//
//     final result = _localizer!.predict(scan);
//
//     setState(() {
//       _currentWindow = w;
//       _predX         = result.x;
//       _predY         = result.y;
//       _confidence    = result.confidence;
//       _zone          = result.nearestZone;
//       _beaconsSeen   = scan.length;
//       _status        = 'Window ${w + 1}/$_totalWindows  '
//           '(${w * 6}s – ${(w + 1) * 6}s)';
//     });
//   }
//
//   // ── Build ──────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // Full-screen floor plan
//           MapFloorView(
//             predictedX: _predX,
//             predictedY: _predY,
//             followMarker: true,
//           ),
//
//           // Top bar: zone + confidence
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 14, vertical: 8),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.55),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Text(
//                         _zone.isNotEmpty ? _zone : 'Lecture Hall Complex',
//                         style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600),
//                       ),
//                     ),
//                   ),
//                   if (_confidence > 0) ...[
//                     const SizedBox(width: 8),
//                     _ConfidencePill(confidence: _confidence),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//
//           // Bottom control sheet
//           Positioned(
//             left: 0, right: 0, bottom: 0,
//             child: Container(
//               padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF16213E).withOpacity(0.93),
//                 borderRadius:
//                 const BorderRadius.vertical(top: Radius.circular(20)),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Drag handle
//                   Container(
//                     width: 36, height: 4,
//                     margin: const EdgeInsets.only(bottom: 12),
//                     decoration: BoxDecoration(
//                       color: Colors.white24,
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//
//                   // Progress bar
//                   if (_running || _currentWindow > 0) ...[
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(4),
//                       child: LinearProgressIndicator(
//                         value: (_currentWindow + 1) / _totalWindows,
//                         minHeight: 6,
//                         backgroundColor: Colors.white12,
//                         valueColor: const AlwaysStoppedAnimation(
//                             Color(0xFF4FC3F7)),
//                       ),
//                     ),
//                     const SizedBox(height: 10),
//                   ],
//
//                   // Status + beacon badge
//                   Row(
//                     children: [
//                       _StatusDot(active: _running),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(_status,
//                             style: const TextStyle(
//                                 color: Colors.white70, fontSize: 13)),
//                       ),
//                       if (_beaconsSeen > 0) _BeaconBadge(count: _beaconsSeen),
//                     ],
//                   ),
//
//                   // X / Y readout
//                   if (_confidence > 0)
//                     Padding(
//                       padding: const EdgeInsets.only(top: 6),
//                       child: Row(
//                         children: [
//                           const Icon(Icons.straighten,
//                               size: 12, color: Colors.white38),
//                           const SizedBox(width: 4),
//                           Text(
//                             'X ${_predX.toStringAsFixed(1)}  ·  '
//                                 'Y ${_predY.toStringAsFixed(1)}',
//                             style: const TextStyle(
//                                 color: Colors.white38,
//                                 fontSize: 11,
//                                 fontFamily: 'monospace'),
//                           ),
//                         ],
//                       ),
//                     ),
//
//                   const SizedBox(height: 14),
//
//                   // Play / Stop button
//                   SizedBox(
//                     width: double.infinity,
//                     height: 50,
//                     child: ElevatedButton.icon(
//                       onPressed: _ready
//                           ? (_running ? _stopPlayback : _startPlayback)
//                           : null,
//                       icon: _running
//                           ? const Icon(Icons.stop_rounded)
//                           : const Icon(Icons.play_arrow_rounded),
//                       label: Text(
//                         _running
//                             ? 'Stop'
//                             : (_currentWindow > 0
//                             ? 'Replay 60 s Scan'
//                             : 'Play 60 s Scan'),
//                         style: const TextStyle(
//                             fontSize: 16, fontWeight: FontWeight.w600),
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: _running
//                             ? Colors.red.shade400
//                             : const Color(0xFF0288D1),
//                         foregroundColor: Colors.white,
//                         disabledBackgroundColor: Colors.grey.shade700,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(14)),
//                         elevation: 0,
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
// // ── Helper widgets ─────────────────────────────────────────────────────────────
//
// class _ConfidencePill extends StatelessWidget {
//   final double confidence;
//   const _ConfidencePill({required this.confidence});
//   @override
//   Widget build(BuildContext context) {
//     final pct   = (confidence * 100).round();
//     final color = confidence > 0.7
//         ? Colors.greenAccent
//         : confidence > 0.4 ? Colors.amber : Colors.redAccent;
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.55),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color.withOpacity(0.6)),
//       ),
//       child: Text('$pct%',
//           style: TextStyle(
//               color: color, fontSize: 12, fontWeight: FontWeight.w700)),
//     );
//   }
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
//       color: active ? Colors.greenAccent : Colors.grey.shade600,
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
//       color: const Color(0xFF0288D1).withOpacity(0.2),
//       borderRadius: BorderRadius.circular(10),
//       border: Border.all(
//           color: const Color(0xFF4FC3F7).withOpacity(0.5), width: 1),
//     ),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         const Icon(Icons.bluetooth, size: 12, color: Color(0xFF4FC3F7)),
//         const SizedBox(width: 3),
//         Text('$count',
//             style: const TextStyle(
//                 fontSize: 12,
//                 color: Color(0xFF4FC3F7),
//                 fontWeight: FontWeight.w600)),
//       ],
//     ),
//   );
// }


// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:localization_engine/localization_engine.dart';
//
// import 'dart:async';
//
// import 'ble_localizer.dart';
// import 'map_screen.dart';
//
// Future<void> _requestPermissions() async {
//   await Permission.bluetoothScan.request();
//   await Permission.bluetoothConnect.request();
//   await Permission.location.request();
// }
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await _requestPermissions();
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
// class HomePage extends StatefulWidget {
//   const HomePage({super.key});
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   static const int _scanDuration = 6; // seconds
//
//   bool   _ready        = false;
//   bool   _scanning     = false;
//   bool   _hasPrediction = false;
//   String _status       = 'Loading model…';
//   int    _secondsLeft  = _scanDuration;
//   int    _beaconsSeen  = 0;
//
//   // WKNN
//   double _wknnX    = 113.0;
//   double _wknnY    = 314.0;
//   String _wknnZone = '';
//
//   // Gaussian
//   double _gaussX    = 113.0;
//   double _gaussY    = 314.0;
//   double _gaussConf = 0.0;
//
//   BLELocalizer?       _localizer;
//   StreamSubscription? _bleSub;
//
//   // Accumulates ALL readings during the 6s scan
//   final Map<String, List<double>> _scanBuffer = {};
//
//   Timer? _countdownTimer;
//
//   @override
//   void initState() {
//     super.initState();
//     _boot();
//   }
//
//   @override
//   void dispose() {
//     _countdownTimer?.cancel();
//     _bleSub?.cancel();
//     LocalizationEngine.stopScanning().catchError((_) {});
//     LocalizationEngine.dispose();
//     super.dispose();
//   }
//
//   Future<void> _boot() async {
//     try {
//       _localizer = await BLELocalizer.fromAsset('assets/ble_model.json');
//       if (mounted) setState(() {
//         _ready  = true;
//         _status = 'Ready — tap Scan';
//       });
//     } catch (e) {
//       if (mounted) setState(() => _status = 'Model load failed: $e');
//     }
//   }
//
//   // ── One scan cycle: collect 6s → predict ──────────────────────────────────
//   Future<void> _startScan() async {
//     if (!_ready || _scanning) return;
//
//     // Reset everything
//     _scanBuffer.clear();
//     setState(() {
//       _scanning    = true;
//       _secondsLeft = _scanDuration;
//       _beaconsSeen = 0;
//       _status      = 'Scanning… $_scanDuration s';
//     });
//
//     // Start BLE stream
//     try {
//       await LocalizationEngine.startScanning(
//         venueName: 'IITDelhi',
//         immediateEmit: true,
//       );
//     } catch (e) {
//       debugPrint('BLE start error: $e');
//       setState(() { _scanning = false; _status = 'BLE error: $e'; });
//       return;
//     }
//
//     await _bleSub?.cancel();
//     _bleSub = LocalizationEngine.scanResultsForAllBeacons.listen((event) {
//       if (event == null) return;
//       final data = Map<String, dynamic>.from(event);
//       data.forEach((key, value) {
//         final name = key.trim().toUpperCase();
//         if (!name.startsWith('IW')) return;
//         final readings = List<MapEntry<DateTime, int>>.from(value);
//         final buf = _scanBuffer.putIfAbsent(name, () => []);
//         for (final r in readings) {
//           buf.add(r.value.toDouble());
//         }
//       });
//       if (mounted) setState(() => _beaconsSeen = _scanBuffer.length);
//     });
//
//     // Countdown 6 → 0
//     _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
//       if (!mounted) { t.cancel(); return; }
//       final left = _secondsLeft - 1;
//       if (left <= 0) {
//         t.cancel();
//         _finishScan();
//       } else {
//         setState(() {
//           _secondsLeft = left;
//           _status      = 'Scanning… $left s';
//         });
//       }
//     });
//   }
//
//   // ── Called when 6s is up ───────────────────────────────────────────────────
//   void _finishScan() async {
//     // Stop BLE
//     await _bleSub?.cancel();
//     _bleSub = null;
//     await LocalizationEngine.stopScanning().catchError((_) {});
//
//     if (_scanBuffer.isEmpty) {
//       setState(() {
//         _scanning = false;
//         _status   = 'No beacons found — try again';
//       });
//       return;
//     }
//
//     // Predict
//     try {
//       final result = _localizer!.predict(_scanBuffer);
//
//       setState(() {
//         _wknnX    = result.wknn.x;
//         _wknnY    = result.wknn.y;
//         _wknnZone = result.wknn.zone;
//
//         _gaussX    = result.gaussian.x;
//         _gaussY    = result.gaussian.y;
//         _gaussConf = result.gaussian.confidence;
//
//         _hasPrediction = true;
//         _scanning      = false;
//         _secondsLeft   = _scanDuration;
//         _status        = 'Done — $_beaconsSeen beacons scanned';
//       });
//     } catch (e) {
//       setState(() {
//         _scanning = false;
//         _status   = 'Predict error: $e';
//       });
//     }
//   }
//
//   // ── Build ──────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final progress = 1.0 - (_secondsLeft / _scanDuration);
//
//     return Scaffold(
//       body: Stack(
//         children: [
//           // Map — Gaussian is exact position, WKNN is zone snap
//           MapFloorView(
//             predictedX: _gaussX,
//             predictedY: _gaussY,
//             wknnX: _hasPrediction ? _wknnX : null,
//             wknnY: _hasPrediction ? _wknnY : null,
//             followMarker: _hasPrediction && !_scanning,
//           ),
//
//           // Top bar
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 14, vertical: 8),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.55),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Text(
//                         _wknnZone.isNotEmpty
//                             ? 'Zone: $_wknnZone'
//                             : 'Lecture Hall Complex',
//                         style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600),
//                       ),
//                     ),
//                   ),
//                   if (_beaconsSeen > 0) ...[
//                     const SizedBox(width: 8),
//                     _BeaconBadge(count: _beaconsSeen),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//
//           // Bottom sheet
//           Positioned(
//             left: 0, right: 0, bottom: 0,
//             child: Container(
//               padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF16213E).withOpacity(0.95),
//                 borderRadius:
//                 const BorderRadius.vertical(top: Radius.circular(20)),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Handle
//                   Container(
//                     width: 36, height: 4,
//                     margin: const EdgeInsets.only(bottom: 14),
//                     decoration: BoxDecoration(
//                       color: Colors.white24,
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//
//                   // 6-second countdown bar
//                   if (_scanning) ...[
//                     Row(
//                       children: [
//                         Expanded(
//                           child: ClipRRect(
//                             borderRadius: BorderRadius.circular(4),
//                             child: LinearProgressIndicator(
//                               value: progress,
//                               minHeight: 8,
//                               backgroundColor: Colors.white12,
//                               valueColor: const AlwaysStoppedAnimation(
//                                   Color(0xFF4FC3F7)),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Text('${_secondsLeft}s',
//                             style: const TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w700,
//                                 fontFamily: 'monospace')),
//                       ],
//                     ),
//                     const SizedBox(height: 14),
//                   ],
//
//                   // Result cards
//                   if (_hasPrediction) ...[
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _ResultCard(
//                             label: 'WKNN Prediction',
//                             labelColor: const Color(0xFF4FC3F7),
//                             subtitle: 'Nearest zone · discrete',
//                             rows: [
//                               _CardRow('X', _wknnX.toStringAsFixed(1)),
//                               _CardRow('Y', _wknnY.toStringAsFixed(1)),
//                               _CardRow('Zone', _wknnZone),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: _ResultCard(
//                             label: 'Gaussian Prediction',
//                             labelColor: const Color(0xFF81C784),
//                             subtitle: 'Exact position · continuous',
//                             rows: [
//                               _CardRow('X', _gaussX.toStringAsFixed(1)),
//                               _CardRow('Y', _gaussY.toStringAsFixed(1)),
//                               _CardRow('Conf',
//                                   '${(_gaussConf * 100).toStringAsFixed(1)}%'),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 14),
//                   ],
//
//                   // Status
//                   Row(
//                     children: [
//                       _StatusDot(active: _scanning),
//                       const SizedBox(width: 8),
//                       Expanded(
//                         child: Text(_status,
//                             style: const TextStyle(
//                                 color: Colors.white54, fontSize: 12)),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//
//                   // Scan button
//                   SizedBox(
//                     width: double.infinity,
//                     height: 52,
//                     child: ElevatedButton.icon(
//                       onPressed: (_ready && !_scanning) ? _startScan : null,
//                       icon: _scanning
//                           ? const SizedBox(
//                           width: 20, height: 20,
//                           child: CircularProgressIndicator(
//                               strokeWidth: 2.5, color: Colors.white))
//                           : const Icon(Icons.my_location_rounded),
//                       label: Text(
//                         _scanning
//                             ? 'Scanning…'
//                             : (_hasPrediction ? 'Scan Again' : 'Scan (6 s)'),
//                         style: const TextStyle(
//                             fontSize: 16, fontWeight: FontWeight.w600),
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF0288D1),
//                         foregroundColor: Colors.white,
//                         disabledBackgroundColor: Colors.grey.shade700,
//                         shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(14)),
//                         elevation: 0,
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
// // ── Result card ────────────────────────────────────────────────────────────────
// class _CardRow {
//   final String label, value;
//   const _CardRow(this.label, this.value);
// }
//
// class _ResultCard extends StatelessWidget {
//   final String         label;
//   final Color          labelColor;
//   final String         subtitle;
//   final List<_CardRow> rows;
//   const _ResultCard({
//     required this.label,
//     required this.labelColor,
//     required this.subtitle,
//     required this.rows,
//   });
//
//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.all(12),
//     decoration: BoxDecoration(
//       color: Colors.white.withOpacity(0.06),
//       borderRadius: BorderRadius.circular(14),
//       border: Border.all(color: labelColor.withOpacity(0.35)),
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(label,
//             style: TextStyle(
//                 color: labelColor,
//                 fontSize: 12,
//                 fontWeight: FontWeight.w700)),
//         Text(subtitle,
//             style: const TextStyle(color: Colors.white38, fontSize: 10)),
//         const SizedBox(height: 8),
//         ...rows.map((r) => Padding(
//           padding: const EdgeInsets.only(bottom: 4),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(r.label,
//                   style: const TextStyle(color: Colors.white54, fontSize: 12)),
//               Text(r.value,
//                   style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600,
//                       fontFamily: 'monospace')),
//             ],
//           ),
//         )),
//       ],
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
//       color: active ? Colors.greenAccent : Colors.grey.shade600,
//     ),
//   );
// }
//
// class _BeaconBadge extends StatelessWidget {
//   final int count;
//   const _BeaconBadge({required this.count});
//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//     decoration: BoxDecoration(
//       color: const Color(0xFF0288D1).withOpacity(0.2),
//       borderRadius: BorderRadius.circular(10),
//       border: Border.all(
//           color: const Color(0xFF4FC3F7).withOpacity(0.5), width: 1),
//     ),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         const Icon(Icons.bluetooth, size: 12, color: Color(0xFF4FC3F7)),
//         const SizedBox(width: 3),
//         Text('$count',
//             style: const TextStyle(
//                 fontSize: 12,
//                 color: Color(0xFF4FC3F7),
//                 fontWeight: FontWeight.w600)),
//       ],
//     ),
//   );
// }

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:localization_engine/localization_engine.dart';

import 'dart:async';

import 'ble_localizer.dart';
import 'map_screen.dart';

Future<void> _requestPermissions() async {
  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();
  await Permission.location.request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const List<int> _scanOptions = [4, 6, 8]; // seconds
  int _scanDuration = 6;

  bool   _ready        = false;
  bool   _scanning     = false;
  bool   _hasPrediction = false;
  String _status       = 'Loading model…';
  int    _secondsLeft  = 6;
  int    _beaconsSeen  = 0;

  // WKNN
  double _wknnX    = 113.0;
  double _wknnY    = 314.0;
  String _wknnZone = '';
  bool   _wknnInterpolated = false;
  List<WKNNCandidate> _wknnCandidates = [];

  // Gaussian
  double _gaussX    = 113.0;
  double _gaussY    = 314.0;
  double _gaussConf = 0.0;

  BLELocalizer?       _localizer;
  StreamSubscription? _bleSub;

  // Accumulates ALL readings during the 6s scan
  final Map<String, List<double>> _scanBuffer = {};

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _bleSub?.cancel();
    LocalizationEngine.stopScanning().catchError((_) {});
    LocalizationEngine.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      _localizer = await BLELocalizer.fromAsset('assets/ble_model.json');
      if (mounted) setState(() {
        _ready  = true;
        _status = 'Ready — tap Scan';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Model load failed: $e');
    }
  }

  // ── One scan cycle: collect 6s → predict ──────────────────────────────────
  Future<void> _startScan() async {
    if (!_ready || _scanning) return;

    // Reset everything
    _scanBuffer.clear();
    setState(() {
      _scanning    = true;
      _secondsLeft = _scanDuration;
      _beaconsSeen = 0;
      _status      = 'Scanning… $_scanDuration s';
    });

    // Start BLE stream
    try {
      await LocalizationEngine.startScanning(
        venueName: 'IITDelhi',
        immediateEmit: true,
      );
    } catch (e) {
      debugPrint('BLE start error: $e');
      setState(() { _scanning = false; _status = 'BLE error: $e'; });
      return;
    }

    await _bleSub?.cancel();
    _bleSub = LocalizationEngine.scanResultsForAllBeacons.listen((event) {
      if (event == null) return;
      final data = Map<String, dynamic>.from(event);
      data.forEach((key, value) {
        final name = key.trim().toUpperCase();
        if (!name.startsWith('IW')) return;
        final readings = List<MapEntry<DateTime, int>>.from(value);
        final buf = _scanBuffer.putIfAbsent(name, () => []);
        for (final r in readings) {
          buf.add(r.value.toDouble());
        }
      });
      if (mounted) setState(() => _beaconsSeen = _scanBuffer.length);
    });

    // Countdown 6 → 0
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final left = _secondsLeft - 1;
      if (left <= 0) {
        t.cancel();
        _finishScan();
      } else {
        setState(() {
          _secondsLeft = left;
          _status      = 'Scanning… $left s';
        });
      }
    });
  }

  // ── Called when 6s is up ───────────────────────────────────────────────────
  void _finishScan() async {
    // Stop BLE
    await _bleSub?.cancel();
    _bleSub = null;
    await LocalizationEngine.stopScanning().catchError((_) {});

    if (_scanBuffer.isEmpty) {
      setState(() {
        _scanning = false;
        _status   = 'No beacons found — try again';
      });
      return;
    }

    // Predict
    try {
      final result = _localizer!.predict(_scanBuffer);

      setState(() {
        _wknnX             = result.wknn.x;
        _wknnY             = result.wknn.y;
        _wknnZone          = result.wknn.zone;
        _wknnInterpolated  = result.wknn.isInterpolated;
        _wknnCandidates    = result.wknn.candidates.take(3).toList();

        _gaussX    = result.gaussian.x;
        _gaussY    = result.gaussian.y;
        _gaussConf = result.gaussian.confidence;

        _hasPrediction = true;
        _scanning      = false;
        _secondsLeft   = _scanDuration;
        _status        = 'Done — $_beaconsSeen beacons scanned';
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _status   = 'Predict error: $e';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final progress = 1.0 - (_secondsLeft / _scanDuration);

    return Scaffold(
      body: Stack(
        children: [
          // Map — Gaussian is exact position, WKNN is zone snap
          MapFloorView(
            predictedX: _gaussX,
            predictedY: _gaussY,
            wknnX: _hasPrediction ? _wknnX : null,
            wknnY: _hasPrediction ? _wknnY : null,
            followMarker: _hasPrediction && !_scanning,
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _wknnZone.isNotEmpty
                            ? 'Zone: $_wknnZone'
                            : 'Lecture Hall Complex',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (_beaconsSeen > 0) ...[
                    const SizedBox(width: 8),
                    _BeaconBadge(count: _beaconsSeen),
                  ],
                ],
              ),
            ),
          ),

          // Bottom sheet
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E).withOpacity(0.95),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // 6-second countdown bar
                  if (_scanning) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF4FC3F7)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${_secondsLeft}s',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Result cards
                  if (_hasPrediction) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _ResultCard(
                            label: 'WKNN Prediction',
                            labelColor: const Color(0xFF4FC3F7),
                            subtitle: _wknnInterpolated
                                ? 'Interpolated · blended'
                                : 'Nearest zone · snapped',
                            rows: [
                              _CardRow('X', _wknnX.toStringAsFixed(1)),
                              _CardRow('Y', _wknnY.toStringAsFixed(1)),
                              if (_wknnCandidates.isNotEmpty)
                                _CardRow(
                                  _wknnCandidates[0].zone,
                                  '${_wknnCandidates[0].similarity.toStringAsFixed(1)}%',
                                ),
                              if (_wknnCandidates.length > 1)
                                _CardRow(
                                  _wknnCandidates[1].zone,
                                  '${_wknnCandidates[1].similarity.toStringAsFixed(1)}%',
                                ),
                              if (_wknnCandidates.length > 2)
                                _CardRow(
                                  _wknnCandidates[2].zone,
                                  '${_wknnCandidates[2].similarity.toStringAsFixed(1)}%',
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ResultCard(
                            label: 'Gaussian Prediction',
                            labelColor: const Color(0xFF81C784),
                            subtitle: 'Exact position · continuous',
                            rows: [
                              _CardRow('X', _gaussX.toStringAsFixed(1)),
                              _CardRow('Y', _gaussY.toStringAsFixed(1)),
                              _CardRow('Conf',
                                  '${(_gaussConf * 100).toStringAsFixed(1)}%'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Duration selector
                  if (!_scanning) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Scan duration:',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 10),
                        ..._scanOptions.map((sec) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _scanDuration = sec),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _scanDuration == sec
                                    ? const Color(0xFF0288D1)
                                    : Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _scanDuration == sec
                                      ? const Color(0xFF4FC3F7)
                                      : Colors.white24,
                                ),
                              ),
                              child: Text('${sec}s',
                                  style: TextStyle(
                                    color: _scanDuration == sec
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 13,
                                    fontWeight: _scanDuration == sec
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  )),
                            ),
                          ),
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Status
                  Row(
                    children: [
                      _StatusDot(active: _scanning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_status,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Scan button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: (_ready && !_scanning) ? _startScan : null,
                      icon: _scanning
                          ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                          : const Icon(Icons.my_location_rounded),
                      label: Text(
                        _scanning
                            ? 'Scanning…'
                            : (_hasPrediction ? 'Scan Again' : 'Scan (6 s)'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0288D1),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
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

// ── Result card ────────────────────────────────────────────────────────────────
class _CardRow {
  final String label, value;
  const _CardRow(this.label, this.value);
}

class _ResultCard extends StatelessWidget {
  final String         label;
  final Color          labelColor;
  final String         subtitle;
  final List<_CardRow> rows;
  const _ResultCard({
    required this.label,
    required this.labelColor,
    required this.subtitle,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: labelColor.withOpacity(0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        Text(subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 8),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(r.label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(r.value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace')),
            ],
          ),
        )),
      ],
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
      color: active ? Colors.greenAccent : Colors.grey.shade600,
    ),
  );
}

class _BeaconBadge extends StatelessWidget {
  final int count;
  const _BeaconBadge({required this.count});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF0288D1).withOpacity(0.2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: const Color(0xFF4FC3F7).withOpacity(0.5), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bluetooth, size: 12, color: Color(0xFF4FC3F7)),
        const SizedBox(width: 3),
        Text('$count',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4FC3F7),
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}