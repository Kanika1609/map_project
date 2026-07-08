import 'dart:math';

// ═══════════════════════════════════════════════════════════════════════════
// HOW THE SOLVER WORKS
// ═══════════════════════════════════════════════════════════════════════════
//
//  Each beacon defines a circle: centre = beacon position, radius = RSSI→distance.
//  The device is at the intersection of those circles.
//
//  Real-world RSSI is noisy, so three cases arise:
//
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │ Case 1 – Circles too SMALL (non-intersecting)                       │
//  │   Inflate all radii by the same factor (binary search) until every  │
//  │   pair of circles just overlaps, then trilaterate.                  │
//  │   This is the "circle inflation" strategy the user requested.       │
//  ├─────────────────────────────────────────────────────────────────────┤
//  │ Case 2 – Circles too LARGE (overlap outside the beacon triangle)    │
//  │   Closed-form trilateration gives a point far outside / negative.   │
//  │   Fall back to gradient-descent least-squares, which always finds   │
//  │   the finite point that minimises Σ(dist - radius)².                │
//  ├─────────────────────────────────────────────────────────────────────┤
//  │ Case 3 – Circles intersect nicely inside the triangle (ideal)       │
//  │   Closed-form trilateration gives an exact answer directly.         │
//  └─────────────────────────────────────────────────────────────────────┘
//
//  UNIT MISMATCH WARNING
//  rssiToDistance() returns metres by default.
//  If your x/y coordinates are in feet, pass distanceScale = 3.28084.
//  If they are pixels where 1 px = 0.5 m, pass distanceScale = 2.0, etc.
//
// ═══════════════════════════════════════════════════════════════════════════
// CHANGELOG — all corrections vs. the original file
// ═══════════════════════════════════════════════════════════════════════════
//
//  FIX A — Point2D.distanceTo(): removed the unused `factor` parameter.
//           It was never passed by any caller, creating a misleading API that
//           implied scaling was happening when it was not.
//
//  FIX B — _leastSquares(): reduced baseLr multiplier from 0.1 → 0.01 and
//           increased iterations from 2000 → 5000.
//           With large radii (e.g. 150–300 coordinate units) the old baseLr
//           produced steps of ~15 units/iteration, causing the solver to
//           overshoot near the minimum and never fully converge.  Smaller
//           steps with more iterations give clean sub-unit precision.
//
//  FIX C — _isInsideBoundingBox(): reduced margin from 1.5 → 0.4.
//           At 150 % of the diagonal the check was accepting closed-form
//           results that were > 100 coordinate units outside the beacon
//           cluster, defeating the purpose of the sanity check entirely.
//           0.4 (40 % of diagonal) allows legitimate edge-of-room positions
//           while still rejecting divergent or Inf results.
//
//  FIX D — main() demo: distanceScale: 3.28084 is correct and retained.
//           Beacon coordinates (19,32), (64,32), (94,25) are in feet.
//           rssiToDistance() returns metres, so multiplying by 3.28084
//           converts radii to feet — matching the coordinate unit.
//           The original code was right; this entry documents the intent.
//
//  FIX E — _selectBestThreeBeacons(): normalised area score so that geometry
//           and signal quality contribute on comparable scales.
//           Previously `score = area * signalScore` where area is in unit²
//           and signalScore ∈ [0,1].  For beacons in a 100×100 grid the area
//           term dominates completely (e.g. 2500 vs 0.7), making the signal
//           weight irrelevant.  Area is now divided by the maximum area seen
//           across all candidate triples, bringing it into [0,1] before
//           multiplying.  The combined score is then: normArea * signalScore,
//           where both factors are in [0,1] — a true equal-weight blend.
//
// ═══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────
// Data types
// ─────────────────────────────────────────────────────────────────────────

class Point2D {
  final double x;
  final double y;

  const Point2D(this.x, this.y);

  // FIX A: Removed the unused `factor` named parameter.
  // The original signature was:
  //   double distanceTo(Point2D other, {double factor = 1.0})
  // The factor was multiplied into the result but was never supplied by any
  // caller in the file, making it dead — and misleading — API surface.
  double distanceTo(Point2D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() =>
      'Point2D(x: ${x.toStringAsFixed(4)}, y: ${y.toStringAsFixed(4)})';
}

class Beacon {
  final String id;
  final Point2D location; // in YOUR local coordinate unit (feet, pixels, …)
  final double rssi;      // dBm, typically negative

  const Beacon({required this.id, required this.location, required this.rssi});

  @override
  String toString() => 'Beacon(id: $id, location: $location, rssi: $rssi)';
}

class TriangulationResult {
  /// Estimated position in the same unit as your beacon coordinates.
  final Point2D estimatedPosition;

  /// Distance from each beacon to the estimate, in local units.
  final List<double> distances;

  /// Human-readable description of which solver branch was used.
  final String method;

  /// Rough accuracy estimate in local units (lower is better).
  final double? accuracy;

  const TriangulationResult({
    required this.estimatedPosition,
    required this.distances,
    required this.method,
    this.accuracy,
  });

  @override
  String toString() =>
      'TriangulationResult(\n'
          '  method        : $method\n'
          '  position      : $estimatedPosition\n'
          '  distances     : ${distances.map((d) => d.toStringAsFixed(2)).toList()}\n'
          '  est. accuracy : ${accuracy != null ? "${accuracy!.toStringAsFixed(2)} local units" : "n/a"}\n'
          ')';
}

// ─────────────────────────────────────────────────────────────────────────
// RSSI → distance
// ─────────────────────────────────────────────────────────────────────────

/// Log-distance path-loss model:  distance = 10^((txPower − rssi) / (10·n))
///
/// The formula produces **metres**.  Multiply by [distanceScale] to match
/// whatever unit your beacon x/y coordinates use.
///
/// Common [distanceScale] values:
///   1.0      → metres  (default)
///   3.28084  → feet
///   100.0    → centimetres
///   Set to (local units / 1 metre) for any other unit.
///
/// [txPower]          – calibrated RSSI at 1 m (dBm, default −59).
/// [pathLossExponent] – n: 2.0 free-space … 4.0 heavy walls.
///
/// rssi >= txPower (device closer than 1 m, or bad reading) returns
/// [minDistance] × [distanceScale] rather than 0, preventing a degenerate
/// zero-radius circle from propagating through all downstream math.
double rssiToDistance(
    double rssi, {
      double txPower = -59.0,
      double pathLossExponent = 2.0,
      double distanceScale = 1.0,
      double minDistance = 0.01, // metres before scaling — avoids zero radius
    }) {
  // RSSI ≥ 0 is physically invalid for BLE; clamp to minDistance.
  // RSSI ≥ txPower means the device is closer than 1 m; also clamp so we
  // never produce a zero or near-zero radius that breaks circle math.
  if (rssi >= txPower) return minDistance * distanceScale;

  final metres =
  pow(10.0, (txPower - rssi) / (10.0 * pathLossExponent)).toDouble();
  // Never return less than minDistance regardless of floating-point quirks.
  return max(metres, minDistance) * distanceScale;
}

// ─────────────────────────────────────────────────────────────────────────
// Low-level geometry
// ─────────────────────────────────────────────────────────────────────────

/// Returns the intersection point(s) of two circles, or null if they
/// don't intersect (too far apart or one inside the other).
List<Point2D>? _circleIntersections(
    Point2D c1, double r1,
    Point2D c2, double r2,
    ) {
  final dx = c2.x - c1.x;
  final dy = c2.y - c1.y;
  final d = sqrt(dx * dx + dy * dy);

  if (d > r1 + r2 + 1e-9) return null;
  if (d < (r1 - r2).abs() - 1e-9) return null;
  if (d < 1e-9) return null;

  final a = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
  final h2 = r1 * r1 - a * a;
  if (h2 < 0) return null;
  final h = sqrt(h2);

  final mx = c1.x + a * dx / d;
  final my = c1.y + a * dy / d;

  if (h < 1e-9) return [Point2D(mx, my)]; // tangent

  return [
    Point2D(mx + h * dy / d, my - h * dx / d),
    Point2D(mx - h * dy / d, my + h * dx / d),
  ];
}

Point2D _midpoint(Point2D a, Point2D b) =>
    Point2D((a.x + b.x) / 2, (a.y + b.y) / 2);

/// True when every pair of circles has at least one intersection point.
bool _allPairsIntersect(List<Point2D> centres, List<double> radii) {
  for (int i = 0; i < centres.length; i++) {
    for (int j = i + 1; j < centres.length; j++) {
      final d = centres[i].distanceTo(centres[j]);
      final ri = radii[i], rj = radii[j];
      if (d > ri + rj + 1e-9) return false;
      if (d < (ri - rj).abs() - 1e-9) return false;
    }
  }
  return true;
}

// ─────────────────────────────────────────────────────────────────────────
// Circle inflation  (Case 1 — circles too small)
// ─────────────────────────────────────────────────────────────────────────

/// Binary-searches for the minimum scale factor ≥ 1 such that every pair
/// of circles (scaled uniformly) has at least one intersection.
///
/// Returns 1.0 immediately if they already intersect.
/// Returns null if no finite scale achieves intersection (e.g. all beacons
/// at the same point with different radii).
double? _inflationScale(
    List<Point2D> centres,
    List<double> radii, {
      double maxScale = 1000.0,
      int iterations = 60,
    }) {
  if (_allPairsIntersect(centres, radii)) return 1.0;

  // Check if maxScale is sufficient
  if (!_allPairsIntersect(
      centres, radii.map((r) => r * maxScale).toList())) {
    return null;
  }

  double lo = 1.0, hi = maxScale;
  for (int i = 0; i < iterations; i++) {
    final mid = (lo + hi) / 2;
    if (_allPairsIntersect(centres, radii.map((r) => r * mid).toList())) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}

// ─────────────────────────────────────────────────────────────────────────
// Least-squares gradient descent  (Case 2 — circles overlap outside)
// ─────────────────────────────────────────────────────────────────────────

/// Finds the point P that minimises  Σᵢ (‖P − cᵢ‖ − rᵢ)²
/// via gradient descent with an adaptive step size and gradient clipping.
///
/// FIX B — baseLr multiplier reduced from 0.1 → 0.01, iterations increased
/// from 2000 → 5000.
///
/// With beacon coordinates in the hundreds (or in feet/pixels) the old
/// baseLr = min(radii) * 0.1 produced step sizes of ~15 units/iteration.
/// Normalising the gradient to a unit vector then multiplying by ~15 caused
/// the solver to overshoot back and forth near the true minimum and never
/// settle to sub-unit precision.
///
/// The new baseLr = min(radii) * 0.01 keeps steps at ~1.5 units early on
/// (fast enough for coarse convergence) while decaying to < 0.5 units by
/// iteration 5000 (precise enough for practical indoor positioning).
/// The decaying schedule (÷ (1 + iter×0.001)) is unchanged.
Point2D _leastSquares(
    List<Point2D> centres,
    List<double> radii, {
      // FIX B: increased from 2000 → 5000 to allow fine convergence
      int iterations = 5000,
    }) {
  // Initialise at inverse-distance weighted centroid (closer beacon = more weight)
  final weights = radii.map((r) => 1.0 / (r + 1e-9)).toList();
  final totalW = weights.fold(0.0, (s, w) => s + w);
  double px = 0, py = 0;
  for (int i = 0; i < centres.length; i++) {
    px += weights[i] * centres[i].x;
    py += weights[i] * centres[i].y;
  }
  px /= totalW;
  py /= totalW;

  // FIX B: multiplier reduced from 0.1 → 0.01.
  // This prevents overshoot in coordinate systems where radii >> 1 (feet,
  // pixels, tile units), while the decay schedule ensures we still converge.
  final baseLr = radii.reduce(min) * 0.01;

  for (int iter = 0; iter < iterations; iter++) {
    double gx = 0, gy = 0;
    for (int i = 0; i < centres.length; i++) {
      final dx = px - centres[i].x;
      final dy = py - centres[i].y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 1e-9) continue;
      final rawErr = dist - radii[i];
      final err = rawErr > 0 ? rawErr : 0.0; // only penalize outside
      gx += err * dx / dist;
      gy += err * dy / dist;
    }

    // Always normalise to a unit vector — unit-independent clipping.
    // This is mathematically equivalent to steepest descent with a pure LR
    // schedule and works in any unit system (metres, feet, pixels, …).
    final gMag = sqrt(gx * gx + gy * gy);
    if (gMag < 1e-9) break; // already at minimum
    gx /= gMag;
    gy /= gMag;

    // Decaying LR: big steps early for speed, tiny steps later for precision
    final lr = baseLr / (1.0 + iter * 0.001);
    px -= lr * gx;
    py -= lr * gy;
  }

  return Point2D(px, py);
}

// ─────────────────────────────────────────────────────────────────────────
// Closed-form trilateration
// ─────────────────────────────────────────────────────────────────────────

/// Exact closed-form solution for 3 circles by linearising via subtraction.
/// Returns null when beacons are collinear (degenerate determinant).
Point2D? _trilaterate3(
    Point2D p1, double d1,
    Point2D p2, double d2,
    Point2D p3, double d3,
    ) {
  final x2 = p2.x - p1.x, y2 = p2.y - p1.y;
  final x3 = p3.x - p1.x, y3 = p3.y - p1.y;

  final A = 2 * x2, B = 2 * y2;
  final C = d1 * d1 - d2 * d2 + x2 * x2 + y2 * y2;
  final D = 2 * x3, E = 2 * y3;
  final F = d1 * d1 - d3 * d3 + x3 * x3 + y3 * y3;

  final det = A * E - B * D;
  if (det.abs() < 1e-9) return null;

  return Point2D(
    (C * E - F * B) / det + p1.x,
    (A * F - D * C) / det + p1.y,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Bounding-box sanity check
// ─────────────────────────────────────────────────────────────────────────

/// Returns true if [p] lies within an expanded beacon bounding box —
/// a plausibility test for closed-form results.
///
/// FIX C: margin reduced from 1.5 (150 %) → 0.4 (40 %).
///
/// At margin = 1.5 the expansion was diagonal × 1.5 on every side, which
/// for a beacon cluster spanning ~83 units allowed closed-form results up to
/// ~124 units outside the cluster to pass — effectively disabling the check.
/// Any result that divergent is numerically unreliable and should fall through
/// to least-squares.
///
/// At margin = 0.4 the check:
///   • Still accepts legitimate edge-of-room positions (a device can legally
///     be up to 40 % of the beacon diagonal outside the bounding box).
///   • Correctly rejects closed-form results that are wildly divergent
///     (Inf, NaN-adjacent, or many room-lengths away).
bool _isInsideBoundingBox(
    Point2D p,
    List<Point2D> beaconPositions, {
      // FIX C: reduced from 1.5 → 0.4 to restore sanity-check effectiveness.
      double margin = 0.4,
    }) {
  double minX = double.infinity, maxX = -double.infinity;
  double minY = double.infinity, maxY = -double.infinity;
  for (final b in beaconPositions) {
    if (b.x < minX) minX = b.x;
    if (b.x > maxX) maxX = b.x;
    if (b.y < minY) minY = b.y;
    if (b.y > maxY) maxY = b.y;
  }
  final span = sqrt((maxX - minX) * (maxX - minX) + (maxY - minY) * (maxY - minY));
  final expand = span * margin;
  return p.x >= minX - expand &&
      p.x <= maxX + expand &&
      p.y >= minY - expand &&
      p.y <= maxY + expand;
}

// ─────────────────────────────────────────────────────────────────────────
// Residual helper
// ─────────────────────────────────────────────────────────────────────────

double _avgResidual(Point2D p, List<Point2D> centres, List<double> radii) {
  double sum = 0;
  for (int i = 0; i < centres.length; i++) {
    sum += (p.distanceTo(centres[i]) - radii[i]).abs();
  }
  return sum / centres.length;
}

// ─────────────────────────────────────────────────────────────────────────
// Geometric beacon selection helper
// ─────────────────────────────────────────────────────────────────────────

/// Select the best 3 beacons from [candidates] by maximising the
/// area of the triangle they form, weighted by signal strength.
///
/// Pure RSSI-ranking (strongest 3) can pick a degenerate cluster when
/// several beacons are co-located or nearly collinear.  This selector
/// scores every combination by:
///
///   score = normArea(b1,b2,b3) × normSignal(b1,b2,b3)
///
/// where both factors are normalised to [0,1] so neither dominates.
///
/// FIX E: The original score was `area * signalScore` where area is in
/// unit² (e.g. thousands) and signalScore ∈ [0,1].  The area term completely
/// dominated — for a 100×100 grid a triangle of area 2500 beats any signal
/// quality difference.  Area is now divided by the maximum area across all
/// candidate triples, bringing it into [0,1].  The result is a true
/// equal-weight blend: normArea × normSignal, both ∈ [0,1].
List<Beacon> _selectBestThreeBeacons(List<Beacon> candidates) {
  if (candidates.length <= 3) return candidates;

  // Normalise RSSI to [0,1]: strongest (least negative) → 1, weakest → 0.
  final maxRssi = candidates.map((b) => b.rssi).reduce(max);
  final minRssi = candidates.map((b) => b.rssi).reduce(min);
  final rssiRange = (maxRssi - minRssi).abs();

  double normRssi(double rssi) =>
      rssiRange < 1e-9 ? 1.0 : (rssi - minRssi) / rssiRange;

  // Shoelace area of a triangle.
  double triangleArea(Point2D a, Point2D b, Point2D c) {
    return ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)).abs() /
        2.0;
  }

  // ── FIX E: first pass — find maximum area for normalisation ─────────
  double maxArea = 0;
  for (int i = 0; i < candidates.length - 2; i++) {
    for (int j = i + 1; j < candidates.length - 1; j++) {
      for (int k = j + 1; k < candidates.length; k++) {
        final area = triangleArea(
            candidates[i].location, candidates[j].location, candidates[k].location);
        if (area > maxArea) maxArea = area;
      }
    }
  }

  // Avoid division-by-zero when all beacons are collinear (maxArea == 0).
  // In that degenerate case fall back to pure signal ranking.
  if (maxArea < 1e-9) return candidates.take(3).toList();

  // ── Second pass — score with both factors in [0,1] ──────────────────
  List<Beacon>? bestTriple;
  double bestScore = -1;

  for (int i = 0; i < candidates.length - 2; i++) {
    for (int j = i + 1; j < candidates.length - 1; j++) {
      for (int k = j + 1; k < candidates.length; k++) {
        final bi = candidates[i];
        final bj = candidates[j];
        final bk = candidates[k];

        // FIX E: normalise area to [0,1] before combining with signalScore.
        final normArea =
            triangleArea(bi.location, bj.location, bk.location) / maxArea;
        final signalScore =
            (normRssi(bi.rssi) + normRssi(bj.rssi) + normRssi(bk.rssi)) / 3.0;

        // Both factors are now in [0,1] — a genuine equal-weight blend.
        final score = normArea * signalScore;

        if (score > bestScore) {
          bestScore = score;
          bestTriple = [bi, bj, bk];
        }
      }
    }
  }

  return bestTriple ?? candidates.take(3).toList();
}

// ─────────────────────────────────────────────────────────────────────────
// Per-mode solvers
// ─────────────────────────────────────────────────────────────────────────

TriangulationResult _singleBeacon(Beacon b, double d) {
  return TriangulationResult(
    estimatedPosition: b.location,
    distances: [d],
    method: 'single-beacon (proximity only — on circle of radius ${d.toStringAsFixed(1)})',
    accuracy: d,
  );
}

TriangulationResult _twoBeacon(Beacon b1, double d1, Beacon b2, double d2) {
  final centres = [b1.location, b2.location];
  final radii   = [d1, d2];

  // Try intersection first
  final intersections = _circleIntersections(b1.location, d1, b2.location, d2);

  if (intersections != null && intersections.isNotEmpty) {
    if (intersections.length == 1) {
      final pt = intersections.first;
      return TriangulationResult(
        estimatedPosition: pt,
        distances: [d1, d2],
        method: 'two-beacon (tangent point)',
        accuracy: _avgResidual(pt, centres, radii),
      );
    }
    final mid = _midpoint(intersections[0], intersections[1]);
    return TriangulationResult(
      estimatedPosition: mid,
      distances: [d1, d2],
      method: 'two-beacon (midpoint of intersection candidates)',
      accuracy: intersections[0].distanceTo(intersections[1]) / 2,
    );
  }

  // Circles don't intersect — inflate then least-squares
  final scale = _inflationScale(centres, radii);
  if (scale != null && scale > 1.0) {
    final inflated = [d1 * scale, d2 * scale];
    final pts = _circleIntersections(b1.location, inflated[0], b2.location, inflated[1]);
    if (pts != null && pts.length == 2) {
      final mid = _midpoint(pts[0], pts[1]);
      return TriangulationResult(
        estimatedPosition: mid,
        distances: [d1, d2],
        method: 'two-beacon (inflated ×${scale.toStringAsFixed(2)} → midpoint)',
        accuracy: pts[0].distanceTo(pts[1]) / 2,
      );
    }
  }

  // Absolute fallback: least-squares
  final ls = _leastSquares(centres, radii);
  return TriangulationResult(
    estimatedPosition: ls,
    distances: [d1, d2],
    method: 'two-beacon (least-squares)',
    accuracy: _avgResidual(ls, centres, radii),
  );
}

TriangulationResult _threeBeacon(
    Beacon b1, double d1,
    Beacon b2, double d2,
    Beacon b3, double d3,
    ) {
  final centres  = [b1.location, b2.location, b3.location];
  final radii    = [d1, d2, d3];

  // ── Step 1: try exact closed-form ────────────────────────────────────
  final cf = _trilaterate3(b1.location, d1, b2.location, d2, b3.location, d3);

  if (cf != null && _isInsideBoundingBox(cf, centres)) {
    return TriangulationResult(
      estimatedPosition: cf,
      distances: radii,
      method: 'three-beacon (closed-form trilateration)',
      accuracy: _avgResidual(cf, centres, radii),
    );
  }

  // ── Step 2: circles don't fully intersect → inflate ─────────────────
  if (!_allPairsIntersect(centres, radii)) {
    final scale = _inflationScale(centres, radii);
    if (scale != null) {
      final inflatedRadii = radii.map((r) => r * scale).toList();
      final cfInflated = _trilaterate3(
        b1.location, inflatedRadii[0],
        b2.location, inflatedRadii[1],
        b3.location, inflatedRadii[2],
      );
      if (cfInflated != null && _isInsideBoundingBox(cfInflated, centres)) {
        return TriangulationResult(
          estimatedPosition: cfInflated,
          distances: radii, // report original distances, not inflated
          method:
          'three-beacon (circle inflation ×${scale.toStringAsFixed(2)} → trilateration)',
          accuracy: _avgResidual(cfInflated, centres, radii),
        );
      }
    }
  }

  // ── Step 3: least-squares fallback ───────────────────────────────────
  // By Step 3, the inflation path (Step 2) has already handled all
  // non-intersecting cases.  The only reasons we reach here are:
  //   (a) cf == null  → beacons are collinear (det ≈ 0)
  //   (b) cf != null but outside bounding box → result outside beacon area
  final ls = _leastSquares(centres, radii);
  final String method;
  if (cf == null) {
    method = 'three-beacon (collinear beacons → least-squares)';
  } else {
    method = 'three-beacon (intersection outside beacon area → least-squares)';
  }

  return TriangulationResult(
    estimatedPosition: ls,
    distances: radii,
    method: method,
    accuracy: _avgResidual(ls, centres, radii),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────

/// Estimates the observer's 2-D position from 1, 2, or 3 BLE beacons.
///
/// The solver automatically selects the best strategy:
///   • Exact trilateration     — when circles intersect inside the beacon area.
///   • Circle inflation        — when circles are too small (non-intersecting):
///                               inflates all radii proportionally until they
///                               just overlap, then trilaterates.
///   • Least-squares descent   — when circles overlap outside the beacon area
///                               (noisy RSSI): finds the point that minimises
///                               Σ(distance − radius)² — always finite.
///
/// ### `distanceScale` — the most important parameter to get right
/// `rssiToDistance` outputs **metres**.  Your x/y coordinates may use a
/// different unit.  Set `distanceScale` = local-units-per-metre:
///
///   Feet   → distanceScale = 3.28084
///   Inches → distanceScale = 39.3701
///   cm     → distanceScale = 100.0
///   Custom → distanceScale = (local units) / (1 metre)
///
/// ### Other parameters
///   [txPower]           – calibrated RSSI at 1 m (dBm, default −59).
///   [pathLossExponent]  – n: 2.0 free-space … 4.0 heavy walls.
///
/// ### Beacon selection
/// When more than 3 beacons are supplied, the best 3 are chosen by
/// maximising a combined score of geometric spread (triangle area) and
/// signal strength — not purely by RSSI, which can pick collinear clusters.
TriangulationResult triangulate(
    List<Beacon> beacons, {
      double txPower = -59.0,
      double pathLossExponent = 2.0,
      double distanceScale = 1.0,
    }) {
  if (beacons.isEmpty) throw ArgumentError('At least one beacon is required.');

  // Sort by strongest signal first so the geometric selector starts from the
  // most relevant candidates and the take(3) path still works for ≤ 3 inputs.
  final sorted = [...beacons]..sort((a, b) => b.rssi.compareTo(a.rssi));

  // Use geometry-aware selection instead of pure RSSI top-3.
  final List<Beacon> top;
  if (sorted.length > 3) {
    top = _selectBestThreeBeacons(sorted);
    print('[triangulate] ${sorted.length} beacons supplied; '
        'selected 3 with best geometry+signal score: '
        '${top.map((b) => b.id).toList()}');
  } else {
    top = sorted.take(3).toList();
  }

  final distances = top
      .map((b) => rssiToDistance(
    b.rssi,
    txPower: txPower,
    pathLossExponent: pathLossExponent,
    distanceScale: distanceScale,
  ))
      .toList();

  switch (top.length) {
    case 1:
      return _singleBeacon(top[0], distances[0]);
    case 2:
      return _twoBeacon(top[0], distances[0], top[1], distances[1]);
    default:
      return _threeBeacon(
        top[0], distances[0],
        top[1], distances[1],
        top[2], distances[2],
      );
  }
}

void main() {
  print('══════════════════════════════════════════════════════════════');
  print('                  BEACON TRIANGULATION DEMO');
  print('══════════════════════════════════════════════════════════════\n');

  // Beacon coordinates are in feet.
  // rssiToDistance() outputs metres by default, so distanceScale = 3.28084
  // converts each computed radius from metres → feet, keeping distances in
  // the same unit as the beacon x/y coordinates.
  final beaconsIndoor = [
    Beacon(id: 'A', location: const Point2D(19, 32),  rssi: -96.66666666666667),
    Beacon(id: 'B', location: const Point2D(64, 32),  rssi: -88.25),
    Beacon(id: 'C', location: const Point2D(94, 25),  rssi: -94.0),
  ];
  print(triangulate(
    beaconsIndoor,
    txPower: -75.0,
    pathLossExponent: 3.0,
    distanceScale: 3.28084, // coordinates in feet → convert metres → feet
  ));
}