import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  runApp(const TriangulationApp());
}

// ═══════════════════════════════════════════════════════════════════════════
// TRIANGULATION LOGIC  (self-contained copy — no import needed)
// ═══════════════════════════════════════════════════════════════════════════

class Point2D {
  final double x, y;
  const Point2D(this.x, this.y);
  double distanceTo(Point2D o) => sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));
}

class Beacon {
  String id;
  Point2D location;
  double rssi;
  Beacon({required this.id, required this.location, required this.rssi});
}

class TriResult {
  final Point2D pos;
  final List<double> radii;
  final String method;
  final double accuracy;
  const TriResult(this.pos, this.radii, this.method, this.accuracy);
}

double rssiToDistance(double rssi,
    {double txPower = -59, double n = 2.0, double scale = 1.0}) {
  if (rssi >= txPower) return 0.01 * scale;
  return max(pow(10.0, (txPower - rssi) / (10.0 * n)).toDouble(), 0.01) * scale;
}

List<Point2D>? _circleIntersections(Point2D c1, double r1, Point2D c2, double r2) {
  final dx = c2.x - c1.x, dy = c2.y - c1.y;
  final d = sqrt(dx * dx + dy * dy);
  if (d > r1 + r2 + 1e-9 || d < (r1 - r2).abs() - 1e-9 || d < 1e-9) return null;
  final a = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
  final h2 = r1 * r1 - a * a;
  if (h2 < 0) return null;
  final h = sqrt(h2);
  final mx = c1.x + a * dx / d, my = c1.y + a * dy / d;
  if (h < 1e-9) return [Point2D(mx, my)];
  return [
    Point2D(mx + h * dy / d, my - h * dx / d),
    Point2D(mx - h * dy / d, my + h * dx / d),
  ];
}

bool _allPairsIntersect(List<Point2D> c, List<double> r) {
  for (int i = 0; i < c.length; i++)
    for (int j = i + 1; j < c.length; j++) {
      final d = c[i].distanceTo(c[j]);
      if (d > r[i] + r[j] + 1e-9 || d < (r[i] - r[j]).abs() - 1e-9) return false;
    }
  return true;
}

double? _inflationScale(List<Point2D> c, List<double> r) {
  if (_allPairsIntersect(c, r)) return 1.0;
  const max_ = 1000.0;
  if (!_allPairsIntersect(c, r.map((x) => x * max_).toList())) return null;
  double lo = 1.0, hi = max_;
  for (int i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    _allPairsIntersect(c, r.map((x) => x * mid).toList()) ? hi = mid : lo = mid;
  }
  return hi;
}

Point2D _leastSquares(List<Point2D> centres, List<double> radii) {
  final w = radii.map((r) => 1.0 / (r + 1e-9)).toList();
  final tw = w.fold(0.0, (s, x) => s + x);
  double px = 0, py = 0;
  for (int i = 0; i < centres.length; i++) {
    px += w[i] * centres[i].x; py += w[i] * centres[i].y;
  }
  px /= tw; py /= tw;
  final baseLr = radii.reduce(min) * 0.1;
  for (int iter = 0; iter < 2000; iter++) {
    double gx = 0, gy = 0;
    for (int i = 0; i < centres.length; i++) {
      final dx = px - centres[i].x, dy = py - centres[i].y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 1e-9) continue;
      final err = dist - radii[i];
      gx += err * dx / dist; gy += err * dy / dist;
    }
    final gm = sqrt(gx * gx + gy * gy);
    if (gm < 1e-9) break;
    gx /= gm; gy /= gm;
    final lr = baseLr / (1.0 + iter * 0.001);
    px -= lr * gx; py -= lr * gy;
  }
  return Point2D(px, py);
}

Point2D? _trilaterate3(Point2D p1, double d1, Point2D p2, double d2, Point2D p3, double d3) {
  final x2 = p2.x - p1.x, y2 = p2.y - p1.y;
  final x3 = p3.x - p1.x, y3 = p3.y - p1.y;
  final A = 2 * x2, B = 2 * y2, C = d1 * d1 - d2 * d2 + x2 * x2 + y2 * y2;
  final D = 2 * x3, E = 2 * y3, F = d1 * d1 - d3 * d3 + x3 * x3 + y3 * y3;
  final det = A * E - B * D;
  if (det.abs() < 1e-9) return null;
  return Point2D((C * E - F * B) / det + p1.x, (A * F - D * C) / det + p1.y);
}

bool _inBox(Point2D p, List<Point2D> bp) {
  double minX = double.infinity, maxX = -double.infinity;
  double minY = double.infinity, maxY = -double.infinity;
  for (final b in bp) {
    if (b.x < minX) minX = b.x; if (b.x > maxX) maxX = b.x;
    if (b.y < minY) minY = b.y; if (b.y > maxY) maxY = b.y;
  }
  final span = sqrt((maxX - minX) * (maxX - minX) + (maxY - minY) * (maxY - minY));
  final ex = span * 1.5;
  return p.x >= minX - ex && p.x <= maxX + ex && p.y >= minY - ex && p.y <= maxY + ex;
}

double _avgRes(Point2D p, List<Point2D> c, List<double> r) {
  double s = 0;
  for (int i = 0; i < c.length; i++) s += (p.distanceTo(c[i]) - r[i]).abs();
  return s / c.length;
}

TriResult triangulate(List<Beacon> beacons, {double txPower = -59, double n = 2.0}) {
  if (beacons.isEmpty) throw ArgumentError('Need at least 1 beacon');
  final sorted = [...beacons]..sort((a, b) => b.rssi.compareTo(a.rssi));
  final top = sorted.take(3).toList();
  final radii = top.map((b) => rssiToDistance(b.rssi, txPower: txPower, n: n)).toList();
  final centres = top.map((b) => b.location).toList();

  if (top.length == 1) {
    return TriResult(top[0].location, radii, 'Single beacon (proximity)', radii[0]);
  }
  if (top.length == 2) {
    final ix = _circleIntersections(centres[0], radii[0], centres[1], radii[1]);
    if (ix != null && ix.isNotEmpty) {
      final pt = ix.length == 1 ? ix[0] : Point2D((ix[0].x + ix[1].x) / 2, (ix[0].y + ix[1].y) / 2);
      return TriResult(pt, radii, 'Two-beacon intersection', _avgRes(pt, centres, radii));
    }
    final ls = _leastSquares(centres, radii);
    return TriResult(ls, radii, 'Two-beacon least-squares', _avgRes(ls, centres, radii));
  }

  // 3 beacons
  final cf = _trilaterate3(centres[0], radii[0], centres[1], radii[1], centres[2], radii[2]);
  if (cf != null && _inBox(cf, centres)) {
    return TriResult(cf, radii, 'Closed-form trilateration', _avgRes(cf, centres, radii));
  }
  if (!_allPairsIntersect(centres, radii)) {
    final sc = _inflationScale(centres, radii);
    if (sc != null) {
      final ir = radii.map((r) => r * sc).toList();
      final cfi = _trilaterate3(centres[0], ir[0], centres[1], ir[1], centres[2], ir[2]);
      if (cfi != null && _inBox(cfi, centres)) {
        return TriResult(cfi, radii,
            'Circle inflation ×${sc.toStringAsFixed(2)} → trilateration',
            _avgRes(cfi, centres, radii));
      }
    }
  }
  final ls = _leastSquares(centres, radii);
  return TriResult(ls, radii,
      cf == null ? 'Collinear beacons → least-squares' : 'Intersection outside area → least-squares',
      _avgRes(ls, centres, radii));
}

// ═══════════════════════════════════════════════════════════════════════════
// THEME & CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

const _bg       = Color(0xFF0D1117);
const _surface  = Color(0xFF161B22);
const _card     = Color(0xFF1C2330);
const _border   = Color(0xFF30363D);
const _cyan     = Color(0xFF00E5FF);
const _green    = Color(0xFF39D353);
const _orange   = Color(0xFFFF6B35);
const _pink     = Color(0xFFFF4081);
const _text     = Color(0xFFE6EDF3);
const _muted    = Color(0xFF8B949E);

const _beaconColors = [_cyan, _orange, _pink];
const _beaconIds = ['A', 'B', 'C'];

// ═══════════════════════════════════════════════════════════════════════════
// APP
// ═══════════════════════════════════════════════════════════════════════════

class TriangulationApp extends StatelessWidget {
  const TriangulationApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Triangulation Visualizer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _bg,
      colorScheme: const ColorScheme.dark(primary: _cyan, surface: _surface),
    ),
    home: const VisualizerScreen(),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class VisualizerScreen extends StatefulWidget {
  const VisualizerScreen({super.key});
  @override
  State<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends State<VisualizerScreen> {
  // Canvas logical size (pixels)
  static const double _W = 320.0, _H = 320.0;

  // Beacon state — positions in canvas pixels, RSSI in dBm
  final List<Offset> _positions = [
    const Offset(60,  220),
    const Offset(160, 60),
    const Offset(260, 220),
  ];
  final List<double> _rssi = [-72.0, -65.0, -78.0];
  double _txPower = -59.0;
  double _pathN   = 2.0;

  int? _dragging; // index of beacon being dragged

  // Convert canvas px → logical coordinate (same scale, just a rename)
  Point2D _toLogical(Offset o) => Point2D(o.dx, o.dy);

  List<Beacon> get _beacons => List.generate(3, (i) => Beacon(
      id: _beaconIds[i],
      location: _toLogical(_positions[i]),
      rssi: _rssi[i]));

  TriResult? get _result {
    try { return triangulate(_beacons, txPower: _txPower, n: _pathN); }
    catch (_) { return null; }
  }

  // ── Drag handling ────────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails d, BoxConstraints box) {
    final scale = box.maxWidth / _W;
    final local = d.localPosition / scale;
    for (int i = 0; i < 3; i++) {
      if ((_positions[i] - local).distance < 22) {
        setState(() => _dragging = i);
        return;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails d, BoxConstraints box) {
    if (_dragging == null) return;
    final scale = box.maxWidth / _W;
    final local = d.localPosition / scale;
    setState(() {
      _positions[_dragging!] = Offset(
        local.dx.clamp(12.0, _W - 12.0),
        local.dy.clamp(12.0, _H - 12.0),
      );
    });
  }

  void _onPanEnd(DragEndDetails _) => setState(() => _dragging = null);

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildCanvas(result),
              const SizedBox(height: 16),
              _buildResultCard(result),
              const SizedBox(height: 16),
              _buildBeaconControls(),
              const SizedBox(height: 16),
              _buildGlobalControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(
    children: [
      Container(
        width: 6, height: 36,
        decoration: BoxDecoration(color: _cyan, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRILATERATION', style: TextStyle(
              color: _cyan, fontSize: 13, fontWeight: FontWeight.w600,
              letterSpacing: 3)),
          Text('BLE Beacon Localisation', style: TextStyle(
              color: _muted, fontSize: 11, letterSpacing: 1)),
        ],
      ),
    ],
  );

  Widget _buildCanvas(TriResult? result) => Container(
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    clipBehavior: Clip.hardEdge,
    child: LayoutBuilder(builder: (ctx, box) {
      return GestureDetector(
        onPanStart: (d) => _onPanStart(d, box),
        onPanUpdate: (d) => _onPanUpdate(d, box),
        onPanEnd: _onPanEnd,
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            painter: _CanvasPainter(
              positions: _positions,
              rssi: _rssi,
              result: result,
              dragging: _dragging,
              txPower: _txPower,
              pathN: _pathN,
              canvasSize: _W,
            ),
          ),
        ),
      );
    }),
  );

  Widget _buildResultCard(TriResult? result) {
    if (result == null) {
      return _card_('RESULT', child: const Text('Insufficient data',
          style: TextStyle(color: _muted)));
    }
    return _card_('RESULT', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Position',
            'x: ${result.pos.x.toStringAsFixed(1)} px  '
            'y: ${result.pos.y.toStringAsFixed(1)} px'),
        const SizedBox(height: 6),
        _row('Accuracy', '±${result.accuracy.toStringAsFixed(2)} px'),
        const SizedBox(height: 6),
        _row('Method', result.method, wrap: true),
        const SizedBox(height: 8),
        Row(children: List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _chip('r${_beaconIds[i]}: ${result.radii[i].toStringAsFixed(1)}px',
              _beaconColors[i]),
        ))),
      ],
    ));
  }

  Widget _buildBeaconControls() => _card_('BEACON RSSI',
    child: Column(
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _dot(_beaconColors[i]),
              const SizedBox(width: 8),
              Text('Beacon ${_beaconIds[i]}',
                  style: TextStyle(color: _beaconColors[i],
                      fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_rssi[i].toStringAsFixed(1)} dBm',
                  style: const TextStyle(color: _text, fontSize: 12,
                      fontFamily: 'monospace')),
            ]),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _beaconColors[i],
                inactiveTrackColor: _border,
                thumbColor: _beaconColors[i],
                overlayColor: _beaconColors[i].withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 3,
              ),
              child: Slider(
                min: -100, max: -40,
                value: _rssi[i],
                onChanged: (v) => setState(() => _rssi[i] = v),
              ),
            ),
          ],
        ),
      )),
    ),
  );

  Widget _buildGlobalControls() => _card_('PARAMETERS',
    child: Column(
      children: [
        _paramSlider('TX Power', _txPower, -80, -40, (v) => setState(() => _txPower = v),
            suffix: ' dBm'),
        const SizedBox(height: 8),
        _paramSlider('Path Loss (n)', _pathN, 1.5, 4.5, (v) => setState(() => _pathN = v),
            digits: 2),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('  free-space', style: TextStyle(color: _muted, fontSize: 10)),
          const Text('heavy walls  ', style: TextStyle(color: _muted, fontSize: 10)),
        ]),
      ],
    ),
  );

  Widget _paramSlider(String label, double val, double min, double max,
      ValueChanged<double> cb, {String suffix = '', int digits = 1}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const Spacer(),
        Text('${val.toStringAsFixed(digits)}$suffix',
            style: const TextStyle(color: _text, fontSize: 12, fontFamily: 'monospace')),
      ]),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: _cyan,
          inactiveTrackColor: _border,
          thumbColor: _cyan,
          overlayColor: _cyan.withOpacity(0.2),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          trackHeight: 3,
        ),
        child: Slider(min: min, max: max, value: val, onChanged: cb),
      ),
    ]);

  // ── Small helpers ─────────────────────────────────────────────────────────
  Widget _card_(String title, {required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: _muted, fontSize: 10,
            letterSpacing: 2, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );

  Widget _row(String label, String value, {bool wrap = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: wrap
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: _text, fontSize: 12)),
          ])
        : Row(children: [
            Text('$label  ', style: const TextStyle(color: _muted, fontSize: 11)),
            const Spacer(),
            Text(value, style: const TextStyle(color: _text, fontSize: 12,
                fontFamily: 'monospace')),
          ]),
  );

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(0.4)),
    ),
    child: Text(t, style: TextStyle(color: c, fontSize: 10, fontFamily: 'monospace')),
  );

  Widget _dot(Color c) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6)]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _CanvasPainter extends CustomPainter {
  final List<Offset> positions;
  final List<double> rssi;
  final TriResult? result;
  final int? dragging;
  final double txPower, pathN, canvasSize;

  const _CanvasPainter({
    required this.positions,
    required this.rssi,
    required this.result,
    required this.dragging,
    required this.txPower,
    required this.pathN,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / canvasSize;
    canvas.scale(scale, scale);

    _drawGrid(canvas);

    if (result != null) {
      _drawCircles(canvas, result!);
      _drawIntersectionArea(canvas, result!);
      _drawEstimate(canvas, result!);
    }

    _drawBeacons(canvas);
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = _border.withOpacity(0.4)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x <= canvasSize; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, canvasSize), paint);
    }
    for (double y = 0; y <= canvasSize; y += step) {
      canvas.drawLine(Offset(0, y), Offset(canvasSize, y), paint);
    }
  }

  void _drawCircles(Canvas canvas, TriResult res) {
    for (int i = 0; i < positions.length; i++) {
      final r = res.radii[i];
      final c = _beaconColors[i];

      // Filled area
      canvas.drawCircle(
        positions[i],
        r,
        Paint()..color = c.withOpacity(0.04),
      );

      // Dashed border
      _drawDashedCircle(canvas, positions[i], r,
          Paint()..color = c.withOpacity(0.6)..strokeWidth = 1.2..style = PaintingStyle.stroke);

      // Radius label
      final tp = TextPainter(
        text: TextSpan(
            text: '${r.toStringAsFixed(0)}px',
            style: TextStyle(color: c.withOpacity(0.7), fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, positions[i] + Offset(4, -r - 14));
    }
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const dashCount = 48;
    const dashLen = 0.10; // fraction of arc
    final step = 2 * pi / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      final startAngle = i * step;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        step * dashLen * dashCount / 2,
        false,
        paint,
      );
    }
    // Solid version for small radii
    if (radius < 20) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _drawIntersectionArea(Canvas canvas, TriResult res) {
    // Draw lines from each beacon to estimated position
    for (int i = 0; i < positions.length; i++) {
      final est = Offset(res.pos.x, res.pos.y);
      canvas.drawLine(
        positions[i], est,
        Paint()
          ..color = _beaconColors[i].withOpacity(0.18)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawEstimate(Canvas canvas, TriResult res) {
    final est = Offset(res.pos.x, res.pos.y);

    // Outer glow ring
    canvas.drawCircle(
        est, 18,
        Paint()..color = _green.withOpacity(0.08));
    canvas.drawCircle(
        est, 18,
        Paint()..color = _green.withOpacity(0.25)..strokeWidth = 1.0..style = PaintingStyle.stroke);

    // Accuracy circle
    if (res.accuracy > 0) {
      canvas.drawCircle(
          est, res.accuracy.clamp(0, 100),
          Paint()..color = _green.withOpacity(0.06));
      canvas.drawCircle(
          est, res.accuracy.clamp(0, 100),
          Paint()..color = _green.withOpacity(0.2)..strokeWidth = 0.8..style = PaintingStyle.stroke);
    }

    // Crosshair
    final ch = Paint()..color = _green.withOpacity(0.7)..strokeWidth = 1.2;
    canvas.drawLine(Offset(est.dx - 14, est.dy), Offset(est.dx + 14, est.dy), ch);
    canvas.drawLine(Offset(est.dx, est.dy - 14), Offset(est.dx, est.dy + 14), ch);

    // Centre dot
    canvas.drawCircle(est, 5, Paint()..color = _green);
    canvas.drawCircle(est, 5,
        Paint()..color = Colors.white.withOpacity(0.6)..strokeWidth = 1..style = PaintingStyle.stroke);

    // Label
    final tp = TextPainter(
      text: const TextSpan(
          text: 'ESTIMATED',
          style: TextStyle(color: _green, fontSize: 8, letterSpacing: 1, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, est + const Offset(8, -20));
  }

  void _drawBeacons(Canvas canvas) {
    for (int i = 0; i < positions.length; i++) {
      final c = _beaconColors[i];
      final isDragging = dragging == i;
      final pos = positions[i];

      // Glow
      canvas.drawCircle(
          pos, isDragging ? 22 : 16,
          Paint()..color = c.withOpacity(isDragging ? 0.25 : 0.15));

      // Body
      canvas.drawCircle(pos, 10, Paint()..color = _surface);
      canvas.drawCircle(pos, 10,
          Paint()..color = c..strokeWidth = isDragging ? 2.5 : 1.8..style = PaintingStyle.stroke);

      // Inner dot
      canvas.drawCircle(pos, 3.5, Paint()..color = c);

      // Label
      final tp = TextPainter(
        text: TextSpan(text: _beaconIds[i],
            style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos + const Offset(13, -6));
    }
  }

  @override
  bool shouldRepaint(_CanvasPainter old) => true;
}
