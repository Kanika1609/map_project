import 'dart:math';
import 'dart:collection';

// ── Beacon database entry ─────────────────────────────────────────────────────
class BeaconMeta {
  final int     lx, ly, floor;
  final double? lat, lon;
  final String? buildingId;
  const BeaconMeta({
    required this.lx,
    required this.ly,
    required this.floor,
    this.lat,
    this.lon,
    this.buildingId,
  });
}

// ── One raw BLE reading ───────────────────────────────────────────────────────
class BleReading {
  final String   name;
  final int      rssi;
  final DateTime timestamp;
  BleReading({
    required this.name,
    required this.rssi,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ── Position result ───────────────────────────────────────────────────────────
class PositionResult {
  final double smoothX, smoothY;
  final double rawX, rawY;
  final double? smoothLat, smoothLon;
  final String confidence;
  final String motionState;
  final String rank1Beacon;
  final int    rank1Rssi;
  final double rank1Weight;
  final double jumpPx;
  final int    nBeacons;

  const PositionResult({
    required this.smoothX,     required this.smoothY,
    required this.rawX,        required this.rawY,
    this.smoothLat,            this.smoothLon,
    required this.confidence,  required this.motionState,
    required this.rank1Beacon, required this.rank1Rssi,
    required this.rank1Weight, required this.jumpPx,
    required this.nBeacons,
  });
}

// ── Internal helpers ──────────────────────────────────────────────────────────
class _Agg {
  final int lx, ly, floor;
  int peak, n;
  double penPeak = 0, score = 0;
  _Agg({
    required this.lx, required this.ly, required this.floor,
    required this.peak, required this.n,
  });
}

class _BufEntry {
  final String   name;
  final int      rssi;
  final DateTime ts;
  _BufEntry(this.name, this.rssi, this.ts);
}

// ── Main estimator ────────────────────────────────────────────────────────────
class BLEPositionEstimator {
  final Map<String, BeaconMeta> beaconDb;
  final double windowS;
  final double temp;
  final int topN;
  final int? floor;

  static const double _continuityBonus = 0.5;
  static const double _rssiGapThresh   = 8.0;
  static const double _posDeltaThresh  = 12.0;
  static const double _alphaStationary = 0.25;
  static const double _alphaWalking    = 0.55;
  static const double _maxJumpStat     = 3.0;
  static const double _maxJumpWalk     = 30.0;
  static const int    _rssiMin         = -110;
  static const int    _rssiMax         = -55;

  final Queue<_BufEntry> _buf = Queue();
  List<double>?   _emaPos;
  Set<String>     _prevTop2 = {};
  String?         _prevR1;
  List<double>?   _prevRawPos;
  PositionResult? _lastResult;

  PositionResult? get lastResult => _lastResult;

  BLEPositionEstimator({
    required this.beaconDb,
    this.windowS = 6.0,
    this.temp    = 5.0,
    this.topN    = 5,
    this.floor,
  });

  PositionResult? update(List<BleReading> readings, {bool? walking}) {
    final now = DateTime.now();

    for (final r in readings) {
      if (r.rssi <= _rssiMin || r.rssi >= _rssiMax) continue;
      if (!beaconDb.containsKey(r.name))            continue;
      _buf.add(_BufEntry(r.name, r.rssi, r.timestamp));
    }

    final cutoff = now.subtract(
      Duration(milliseconds: (windowS * 1000).round()),
    );
    while (_buf.isNotEmpty && _buf.first.ts.isBefore(cutoff)) {
      _buf.removeFirst();
    }
    if (_buf.isEmpty) return null;

    final Map<String, _Agg> agg = {};
    for (final e in _buf) {
      final meta = beaconDb[e.name]!;
      if (agg.containsKey(e.name)) {
        agg[e.name]!.peak = max(agg[e.name]!.peak, e.rssi);
        agg[e.name]!.n++;
      } else {
        agg[e.name] = _Agg(
          lx: meta.lx, ly: meta.ly, floor: meta.floor,
          peak: e.rssi, n: 1,
        );
      }
    }

    for (final b in agg.values) {
      b.penPeak = b.peak.toDouble() +
          (b.n == 1 ? -4.0 : b.n == 2 ? -2.0 : 0.0);
    }

    final targetFloor  = floor ?? _majorityFloor(agg);
    final floorEntries = agg.entries
        .where((e) => e.value.floor == targetFloor)
        .toList();
    if (floorEntries.isEmpty) return null;

    for (final e in floorEntries) {
      e.value.score = e.value.penPeak +
          (_prevTop2.contains(e.key) ? _continuityBonus : 0.0);
    }
    floorEntries.sort((a, b) => b.value.score.compareTo(a.value.score));

    final top   = floorEntries.take(topN).toList();
    final rssis = top.map((e) => e.value.penPeak).toList();
    final maxR  = rssis.reduce(max);
    final expW  = rssis.map((r) => exp((r - maxR) / temp)).toList();
    final sumW  = expW.fold(0.0, (a, b) => a + b);
    final wNorm = expW.map((w) => w / sumW).toList();

    double rawX = 0, rawY = 0;
    for (int i = 0; i < top.length; i++) {
      rawX += wNorm[i] * top[i].value.lx;
      rawY += wNorm[i] * top[i].value.ly;
    }

    final currTop2 = top.take(2).map((e) => e.key).toSet();
    final currR1   = floorEntries.first.key;
    final rssiGap  = floorEntries.length > 1
        ? (floorEntries[0].value.penPeak - floorEntries[1].value.penPeak).abs()
        : 0.0;

    final bool isWalking;
    if (walking != null) {
      isWalking = walking;
    } else if (_prevR1 == null) {
      isWalking = false;
    } else {
      int signals = 0;
      if (currR1 != _prevR1) signals++;
      if (_prevRawPos != null) {
        final dx = rawX - _prevRawPos![0];
        final dy = rawY - _prevRawPos![1];
        if (sqrt(dx * dx + dy * dy) >= _posDeltaThresh) signals++;
      }
      if (rssiGap >= _rssiGapThresh) signals++;
      isWalking = signals >= 2;
    }

    final alpha   = isWalking ? _alphaWalking  : _alphaStationary;
    final maxJump = isWalking ? _maxJumpWalk    : _maxJumpStat;

    double jumpPx = 0.0;
    if (_emaPos == null) {
      _emaPos = [rawX, rawY];
    } else {
      final dx = rawX - _emaPos![0];
      final dy = rawY - _emaPos![1];
      jumpPx = sqrt(dx * dx + dy * dy);
      double cx = rawX, cy = rawY;
      if (jumpPx > maxJump) {
        final scale = maxJump / jumpPx;
        cx = _emaPos![0] + dx * scale;
        cy = _emaPos![1] + dy * scale;
      }
      _emaPos = [
        alpha * cx + (1 - alpha) * _emaPos![0],
        alpha * cy + (1 - alpha) * _emaPos![1],
      ];
    }

    final sx  = _emaPos![0], sy = _emaPos![1];
    final gps = _localToGps(sx, sy);

    _prevTop2   = currTop2;
    _prevR1     = currR1;
    _prevRawPos = [rawX, rawY];

    final topW = wNorm.isNotEmpty ? wNorm[0] : 0.0;

    final result = PositionResult(
      smoothX:     sx,
      smoothY:     sy,
      rawX:        rawX,
      rawY:        rawY,
      smoothLat:   gps?[0],
      smoothLon:   gps?[1],
      confidence:  _confidence(top.length, floorEntries.first.value.penPeak, topW),
      motionState: isWalking ? 'walking' : 'stationary',
      rank1Beacon: floorEntries.first.key,
      rank1Rssi:   floorEntries.first.value.peak,
      rank1Weight: topW,
      jumpPx:      jumpPx,
      nBeacons:    floorEntries.length,
    );

    _lastResult = result;
    return result;
  }

  void reset() {
    _buf.clear();
    _emaPos     = null;
    _prevTop2   = {};
    _prevR1     = null;
    _prevRawPos = null;
    _lastResult = null;
  }

  int _majorityFloor(Map<String, _Agg> agg) {
    final counts = <int, int>{};
    for (final v in agg.values) {
      counts[v.floor] = (counts[v.floor] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  List<double>? _localToGps(double lx, double ly) {
    final refs = beaconDb.values
        .where((m) => m.lat != null && m.lon != null)
        .toList();
    if (refs.isEmpty) return null;
    double tw = 0, la = 0, lo = 0;
    for (final m in refs) {
      final dx = lx - m.lx, dy = ly - m.ly;
      final d  = max(sqrt(dx * dx + dy * dy), 0.5);
      final w  = 1.0 / (d * d);
      la += w * m.lat!;
      lo += w * m.lon!;
      tw += w;
    }
    return [la / tw, lo / tw];
  }

  String _confidence(int n, double bestRssi, double topW) {
    int s = 0;
    if (topW > 0.55)          s += 3;
    else if (topW > 0.35)     s += 2;
    else                      s += 1;
    if (n >= 5)               s += 2;
    else if (n >= 3)          s += 1;
    if (bestRssi >= -75)      s += 2;
    else if (bestRssi >= -85) s += 1;
    return s >= 6 ? 'high' : s >= 4 ? 'medium' : 'low';
  }
}