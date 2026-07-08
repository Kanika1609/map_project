// ble_csv_screen.dart
// Add to lib/ — imports your existing beacon_db.dart and BLEPositionEstimator.dart
//
// pubspec.yaml — add ONE dependency:
//   dependencies:
//     csv: ^6.0.0
//
// pubspec.yaml — declare the asset (already have it if you set it up):
//   flutter:
//     assets:
//       - assets/data/ble_scan_data_1_RNI.csv

import 'dart:async';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'BLEPositionEstimator.dart';
import 'beacon_db.dart'; // provides: rniBeaconDb

// ── CSV row ───────────────────────────────────────────────────────────────────
class _Row {
  final String   name;
  final int      rssi;
  final DateTime ts;
  const _Row(this.name, this.rssi, this.ts);
}

// ── Screen ────────────────────────────────────────────────────────────────────
class BleCsvScreen extends StatefulWidget {
  const BleCsvScreen({super.key});
  @override
  State<BleCsvScreen> createState() => _BleCsvScreenState();
}

class _BleCsvScreenState extends State<BleCsvScreen> {
  final BLEPositionEstimator _est = BLEPositionEstimator(
    beaconDb: rniBeaconDb,
    windowS: 6.0,
    temp: 5.0,
    topN: 5,
  );

  // data
  List<_Row>  _rows         = [];
  bool        _loaded       = false;
  bool        _loading      = false;
  String?     _error;

  // playback
  bool        _playing      = false;
  bool        _done         = false;
  int         _windowIndex  = 0;
  int         _totalWindows = 0;
  DateTime?   _sessionStart;

  // live stats
  Timer?          _timer;
  PositionResult? _pos;
  int             _updateCount = 0;
  DateTime?       _lastTick;
  double          _hz          = 0;

  @override
  void initState() {
    super.initState();
    _loadCsv();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _loadCsv() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await rootBundle.loadString('assets/data/ble_scan_data_1_RNI.csv');
      _parse(raw);
    } catch (e) {
      setState(() { _error = 'Failed to load CSV:\n$e'; _loading = false; });
    }
  }

  void _parse(String raw) {
    final table = const CsvToListConverter(eol: '\n').convert(raw);
    if (table.isEmpty) { setState(() { _error = 'Empty CSV'; _loading = false; }); return; }

    final hdr     = table.first.map((e) => e.toString().trim()).toList();
    final nameIdx = hdr.indexOf('name');
    final rssiIdx = hdr.indexOf('rssi');
    final tsIdx   = hdr.indexOf('timestamp');

    if ([nameIdx, rssiIdx, tsIdx].contains(-1)) {
      setState(() { _error = 'CSV needs columns: name, rssi, timestamp'; _loading = false; });
      return;
    }

    final rows = <_Row>[];
    for (int i = 1; i < table.length; i++) {
      try {
        final r = table[i];
        rows.add(_Row(
          r[nameIdx].toString().trim(),
          int.parse(r[rssiIdx].toString().trim()),
          DateTime.parse(r[tsIdx].toString().trim()),
        ));
      } catch (_) {}
    }

    rows.sort((a, b) => a.ts.compareTo(b.ts));
    final totalMs = rows.last.ts.difference(rows.first.ts).inMilliseconds;

    setState(() {
      _rows         = rows;
      _loaded       = true;
      _loading      = false;
      _windowIndex  = 0;
      _totalWindows = (totalMs / 1000).ceil() + 1;
      _sessionStart = rows.first.ts;
    });
  }

  // ── Playback ──────────────────────────────────────────────────────────────
  void _togglePlay() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
    } else {
      if (_done) _reset();
      setState(() { _playing = true; _done = false; });
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  void _tick(Timer _) {
    if (_windowIndex >= _totalWindows) {
      _timer?.cancel();
      setState(() { _playing = false; _done = true; });
      return;
    }

    final start  = _sessionStart!.add(Duration(seconds: _windowIndex));
    final end    = start.add(const Duration(seconds: 1));
    final bucket = _rows
        .where((r) => !r.ts.isBefore(start) && r.ts.isBefore(end))
        .map((r) => BleReading(name: r.name, rssi: r.rssi, timestamp: r.ts))
        .toList();

    final pos = _est.update(bucket);
    final now = DateTime.now();
    final hz  = _lastTick != null
        ? 1000 / now.difference(_lastTick!).inMilliseconds.clamp(1, 9999)
        : 0.0;
    _lastTick = now;

    setState(() {
      _pos = pos;
      _windowIndex++;
      _updateCount++;
      _hz = hz;
    });
  }

  void _reset() {
    _timer?.cancel();
    _est.reset();
    setState(() {
      _windowIndex = 0;
      _updateCount = 0;
      _pos         = null;
      _playing     = false;
      _done        = false;
      _hz          = 0;
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BLE Real-Time Position Estimator',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            if (_loaded)
              Text(
                'Floor ${_pos?.rank1Beacon != null ? rniBeaconDb[_pos!.rank1Beacon]?.floor ?? 0 : 0}'
                    '  ·  $_updateCount updates @ ${_hz.toStringAsFixed(1)} Hz',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (_loaded)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
              onPressed: _reset,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)));
    if (_error != null) return _buildError();
    if (!_loaded) return const SizedBox();
    return _buildDashboard();
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        _btn('Retry', Icons.refresh, const Color(0xFF21262D), _loadCsv),
      ]),
    ),
  );

  Widget _buildDashboard() {
    final p        = _pos;
    final progress = (_totalWindows > 0 ? _windowIndex / _totalWindows : 0.0).clamp(0.0, 1.0);

    return Column(children: [
      // ── Progress bar ──
      Container(
        color: const Color(0xFF161B22),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('t = ${_windowIndex}s  [$_updateCount / $_totalWindows]',
                style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'monospace')),
            Text('${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress, minHeight: 5,
              backgroundColor: const Color(0xFF21262D),
              color: const Color(0xFF58A6FF),
            ),
          ),
        ]),
      ),

      // ── Cards ──
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [

            // Position
            _card(child: Column(children: [
              _label('Position'),
              const SizedBox(height: 8),
              Text(
                p != null
                    ? '(${p.smoothX.toStringAsFixed(1)},  ${p.smoothY.toStringAsFixed(1)})'
                    : '— ,  —',
                style: const TextStyle(
                  color: Color(0xFF58A6FF), fontSize: 34,
                  fontWeight: FontWeight.w800, fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              const Text('local X · Y  (pixels)',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ])),
            const SizedBox(height: 10),

            // Confidence + Motion
            _row2(
              _badge('Confidence', p?.confidence ?? '—', _confColor(p?.confidence)),
              _badge('Motion state', p?.motionState ?? '—',
                  p?.motionState == 'walking' ? Colors.orange : Colors.green, dot: true),
            ),
            const SizedBox(height: 10),

            // Rank-1 beacon
            _card(
              label: 'Rank-1 Beacon',
              child: Column(children: [
                _kv('Name',           p?.rank1Beacon ?? '—',                     hi: true),
                _kv('RSSI',           p != null ? '${p.rank1Rssi} dBm'  : '—'),
                _kv('Softmax weight', p != null
                    ? '${(p.rank1Weight * 100).toStringAsFixed(1)}%' : '—'),
              ]),
            ),
            const SizedBox(height: 10),

            // Jump + beacons used
            _row2(
              _stat('Jump',
                  p != null ? '${p.jumpPx.toStringAsFixed(1)} px' : '—',
                  sub: p != null ? '≈ ${(p.jumpPx * 0.249).toStringAsFixed(2)} m' : ''),
              _stat('Beacons used',
                  p != null ? '${p.nBeacons}' : '—',
                  sub: 'this window'),
            ),
            const SizedBox(height: 10),

            // GPS (only when available)
            if (p?.smoothLat != null) ...[
              _card(
                label: 'GPS Estimate',
                child: Column(children: [
                  _kv('Lat', p!.smoothLat!.toStringAsFixed(6)),
                  _kv('Lon', p.smoothLon!.toStringAsFixed(6)),
                ]),
              ),
              const SizedBox(height: 10),
            ],

            // Controls
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _btn('Reset', Icons.refresh, const Color(0xFF21262D), _reset),
              const SizedBox(width: 14),
              _btn(
                _playing ? 'Pause' : (_done ? 'Replay' : 'Play'),
                _playing ? Icons.pause : (_done ? Icons.replay : Icons.play_arrow),
                _playing ? const Color(0xFF6E40C9) : const Color(0xFF238636),
                _togglePlay,
                large: true,
              ),
            ]),

            if (_done)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: Text('Playback complete',
                    style: TextStyle(color: Colors.white38, fontSize: 13))),
              ),
          ],
        ),
      ),
    ]);
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  static const _cardDeco = BoxDecoration(
    color: Color(0xFF161B22),
    border: Border.symmetric(
      horizontal: BorderSide(color: Color(0xFF30363D)),
      vertical:   BorderSide(color: Color(0xFF30363D)),
    ),
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  Widget _card({String? label, required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: _cardDeco,
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (label != null) ...[_label(label), const SizedBox(height: 10)],
      child,
    ]),
  );

  Widget _label(String t) => Text(t,
      style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.8));

  Widget _stat(String label, String val, {String sub = ''}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: _cardDeco,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
      if (sub.isNotEmpty)
        Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]),
  );

  Widget _badge(String label, String val, Color color, {bool dot = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: _cardDeco,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 6),
      Row(children: [
        if (dot) ...[
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(val, style: TextStyle(
            color: color, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
      ]),
    ]),
  );

  Widget _kv(String k, String v, {bool hi = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      Text(v, style: TextStyle(
          color: hi ? const Color(0xFFE3A118) : Colors.white,
          fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
    ]),
  );

  Widget _row2(Widget a, Widget b) => Row(children: [
    Expanded(child: a), const SizedBox(width: 10), Expanded(child: b),
  ]);

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap,
      {bool large = false}) =>
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color, foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
              horizontal: large ? 28 : 14, vertical: large ? 13 : 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: large ? 22 : 17),
        label: Text(label, style: TextStyle(fontSize: large ? 15 : 13)),
      );

  Color _confColor(String? c) =>
      c == 'high' ? Colors.green : c == 'medium' ? Colors.orange : Colors.red;
}