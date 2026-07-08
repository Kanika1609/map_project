// /// BLE Indoor Localization — Flutter/Dart
// /// ========================================
// /// Drop-in inference engine. No dependencies beyond dart:convert and dart:math.
// /// Load model JSON once at startup, call predict() on every scan.
// ///
// /// Usage:
// ///   final loc = await BLELocalizer.fromAsset('assets/ble_model.json');
// ///   final result = loc.predict(scanMap);
// ///   print('X=${result.x}  Y=${result.y}  error≈${result.nearestZone}');
//
// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/services.dart' show rootBundle;
//
// // ── Data classes ─────────────────────────────────────────────────────
//
// class LocalizationResult {
//   /// Predicted coordinates in pixel space
//   final double x;
//   final double y;
//   final int floor;
//
//   /// Real-world estimate (metres from origin)
//   final double xMetres;
//   final double yMetres;
//
//   /// Label of nearest reference zone e.g. "137_334"
//   final String nearestZone;
//
//   /// Distance to nearest reference zone in metres
//   final double nearestZoneDistM;
//
//   /// Gaussian confidence [0–1]. 1.0 = model is certain.
//   final double confidence;
//
//   /// Top-3 candidate zones with probabilities
//   final List<ZoneCandidate> topCandidates;
//
//   const LocalizationResult({
//     required this.x,
//     required this.y,
//     required this.floor,
//     required this.xMetres,
//     required this.yMetres,
//     required this.nearestZone,
//     required this.nearestZoneDistM,
//     required this.confidence,
//     required this.topCandidates,
//   });
//
//   @override
//   String toString() =>
//       'LocalizationResult(x=$x, y=$y, floor=$floor, '
//           'nearestZone=$nearestZone, conf=${(confidence * 100).toStringAsFixed(1)}%)';
// }
//
// class ZoneCandidate {
//   final String label;
//   final double x;
//   final double y;
//   final int floor;
//   final double probability;
//   const ZoneCandidate(
//       {required this.label,
//         required this.x,
//         required this.y,
//         required this.floor,
//         required this.probability});
// }
//
// // ── Model ─────────────────────────────────────────────────────────────
//
// class BLELocalizer {
//   final List<String> _beaconIds;
//   final double _scaleMPx;
//   final double _bleMin;
//   final double _bleMax;
//   final double _noSignal;
//
//   // WKNN
//   final int _k;
//   final List<List<double>> _xTrain; // [n_sessions, n_beacons]
//   final List<List<double>> _yTrain; // [n_sessions, 2]
//
//   // Gaussian: location → beacon → {mu, sigma}
//   final Map<String, _GaussLoc> _gaussLocs;
//
//   BLELocalizer._({
//     required List<String> beaconIds,
//     required double scaleMPx,
//     required double bleMin,
//     required double bleMax,
//     required double noSignal,
//     required int k,
//     required List<List<double>> xTrain,
//     required List<List<double>> yTrain,
//     required Map<String, _GaussLoc> gaussLocs,
//   })  : _beaconIds = beaconIds,
//         _scaleMPx = scaleMPx,
//         _bleMin = bleMin,
//         _bleMax = bleMax,
//         _noSignal = noSignal,
//         _k = k,
//         _xTrain = xTrain,
//         _yTrain = yTrain,
//         _gaussLocs = gaussLocs;
//
//   // ── Factory constructors ────────────────────────────────────────────
//
//   /// Load from Flutter assets bundle (place ble_model.json in assets/)
//   static Future<BLELocalizer> fromAsset(String assetPath) async {
//     final raw = await rootBundle.loadString(assetPath);
//     return fromJson(raw);
//   }
//
//   /// Load from a JSON string directly
//   static BLELocalizer fromJson(String jsonStr) {
//     final Map<String, dynamic> data = json.decode(jsonStr);
//     final beaconIds = List<String>.from(data['beacon_ids']);
//     final scaleMPx = (data['scale_m_px'] as num).toDouble();
//     final bleMin = (data['ble_min'] as num).toDouble();
//     final bleMax = (data['ble_max'] as num).toDouble();
//     final noSignal = (data['no_signal'] as num).toDouble();
//
//     // WKNN
//     final wknnData = data['wknn'] as Map<String, dynamic>;
//     final k = wknnData['k'] as int;
//     final xTrain = (wknnData['X_train'] as List)
//         .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
//         .toList();
//     final yTrain = (wknnData['y_train'] as List)
//         .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
//         .toList();
//
//     // Gaussian
//     final gaussData = data['gaussian']['locations'] as Map<String, dynamic>;
//     final gaussLocs = <String, _GaussLoc>{};
//     gaussData.forEach((label, locData) {
//       final ld = locData as Map<String, dynamic>;
//       final beaconMap = <String, _GaussParam>{};
//       (ld['beacons'] as Map<String, dynamic>).forEach((beacon, params) {
//         final p = params as Map<String, dynamic>;
//         beaconMap[beacon] = _GaussParam(
//           mu: (p['mu'] as num).toDouble(),
//           sigma: (p['sigma'] as num).toDouble(),
//         );
//       });
//       gaussLocs[label] = _GaussLoc(
//         x: (ld['x'] as num).toDouble(),
//         y: (ld['y'] as num).toDouble(),
//         floor: (ld['floor'] as num).toInt(),
//         beacons: beaconMap,
//       );
//     });
//
//     return BLELocalizer._(
//       beaconIds: beaconIds,
//       scaleMPx: scaleMPx,
//       bleMin: bleMin,
//       bleMax: bleMax,
//       noSignal: noSignal,
//       k: k,
//       xTrain: xTrain,
//       yTrain: yTrain,
//       gaussLocs: gaussLocs,
//     );
//   }
//
//   // ── Public API ──────────────────────────────────────────────────────
//
//   /// Main prediction method.
//   ///
//   /// [scan] maps beacon ID → list of RSSI readings (dBm).
//   ///        e.g. {'IW25031324': [-85.0, -88.0, -91.0], 'IW25030978': [-92.0]}
//   ///
//   /// Readings outside [-100, -40] dBm are automatically discarded.
//   /// Missing beacons are filled with NO_SIGNAL (-100 dBm).
//   ///
//   /// Returns a [LocalizationResult] with both WKNN and Gaussian estimates
//   /// fused into a single best prediction.
//   LocalizationResult predict(Map<String, List<double>> scan) {
//     final vec = _buildFeatureVector(scan);
//     final wknnPred = _wknnPredict(vec);
//     final gaussResult = _gaussianPredict(vec);
//
//     // Use WKNN as primary; Gaussian for confidence + top candidates
//     final predX = wknnPred[0];
//     final predY = wknnPred[1];
//
//     // Find nearest named reference zone
//     String nearestZone = '';
//     double nearestDist = double.infinity;
//     int nearestFloor = 0;
//     _gaussLocs.forEach((label, loc) {
//       final d = sqrt(pow(predX - loc.x, 2) + pow(predY - loc.y, 2));
//       if (d < nearestDist) {
//         nearestDist = d;
//         nearestZone = label;
//         nearestFloor = loc.floor;
//       }
//     });
//
//     return LocalizationResult(
//       x: predX,
//       y: predY,
//       floor: nearestFloor,
//       xMetres: predX * _scaleMPx,
//       yMetres: predY * _scaleMPx,
//       nearestZone: nearestZone,
//       nearestZoneDistM: nearestDist * _scaleMPx,
//       confidence: gaussResult.topConfidence,
//       topCandidates: gaussResult.candidates,
//     );
//   }
//
//   /// Convenience: pass raw scan as Map<beaconId, singleRSSI>
//   /// (pre-averaged values from BLE scanner)
//   LocalizationResult predictFromMeans(Map<String, double> means) {
//     final scan = means.map((k, v) => MapEntry(k, [v]));
//     return predict(scan);
//   }
//
//   // ── Feature vector ──────────────────────────────────────────────────
//
//   List<double> _buildFeatureVector(Map<String, List<double>> scan) {
//     return _beaconIds.map((beacon) {
//       final readings = scan[beacon];
//       if (readings == null || readings.isEmpty) return _noSignal;
//       final clean = readings
//           .where((v) => v >= _bleMin && v <= _bleMax)
//           .toList();
//       if (clean.isEmpty) return _noSignal;
//       return _trimmedMean(clean);
//     }).toList();
//   }
//
//   double _trimmedMean(List<double> vals) {
//     if (vals.length <= 3) {
//       return vals.reduce((a, b) => a + b) / vals.length;
//     }
//     final sorted = List<double>.from(vals)..sort();
//     final trim = (vals.length * 0.1).round().clamp(1, vals.length ~/ 3);
//     final trimmed = sorted.sublist(trim, sorted.length - trim);
//     return trimmed.reduce((a, b) => a + b) / trimmed.length;
//   }
//
//   // ── WKNN ─────────────────────────────────────────────────────────────
//
//   List<double> _wknnPredict(List<double> vec) {
//     final distances = List<double>.generate(_xTrain.length, (i) {
//       double sum = 0;
//       for (int j = 0; j < vec.length; j++) {
//         final diff = vec[j] - _xTrain[i][j];
//         sum += diff * diff;
//       }
//       return sqrt(sum);
//     });
//
//     // Get top-k indices sorted by distance
//     final indices = List<int>.generate(_xTrain.length, (i) => i)
//       ..sort((a, b) => distances[a].compareTo(distances[b]));
//     final topK = indices.take(_k).toList();
//
//     // Weighted centroid
//     final weights = topK.map((i) => 1.0 / (distances[i] + 1e-9)).toList();
//     final sumW = weights.reduce((a, b) => a + b);
//
//     double px = 0, py = 0;
//     for (int i = 0; i < topK.length; i++) {
//       px += (weights[i] / sumW) * _yTrain[topK[i]][0];
//       py += (weights[i] / sumW) * _yTrain[topK[i]][1];
//     }
//     return [px, py];
//   }
//
//   // ── Gaussian fingerprint ─────────────────────────────────────────────
//
//   _GaussResult _gaussianPredict(List<double> vec) {
//     final scores = <String, double>{};
//
//     _gaussLocs.forEach((label, loc) {
//       double ll = 0.0;
//       for (int i = 0; i < _beaconIds.length; i++) {
//         final beacon = _beaconIds[i];
//         final v = vec[i];
//         final params = loc.beacons[beacon];
//         if (params == null) {
//           if (v > _noSignal + 1) ll += log(1e-9);
//         } else {
//           if (v > _noSignal + 1) {
//             ll += _gaussianLogPdf(v, params.mu, params.sigma);
//           } else if (params.mu > -85) {
//             ll -= 2.0; // penalty for expected-but-absent beacon
//           }
//         }
//       }
//       scores[label] = ll;
//     });
//
//     // Softmax over top-5
//     final sorted = scores.entries.toList()
//       ..sort((a, b) => b.value.compareTo(a.value));
//     final top5 = sorted.take(5).toList();
//     final maxLL = top5.first.value;
//     final expScores = top5.map((e) => exp(e.value - maxLL)).toList();
//     final sumExp = expScores.reduce((a, b) => a + b);
//     final probs = expScores.map((e) => e / sumExp).toList();
//
//     final candidates = List.generate(top5.length, (i) {
//       final loc = _gaussLocs[top5[i].key]!;
//       return ZoneCandidate(
//         label: top5[i].key,
//         x: loc.x,
//         y: loc.y,
//         floor: loc.floor,
//         probability: probs[i],
//       );
//     });
//
//     return _GaussResult(topConfidence: probs[0], candidates: candidates);
//   }
//
//   /// Standard Gaussian log PDF: log(N(x; mu, sigma))
//   double _gaussianLogPdf(double x, double mu, double sigma) {
//     final z = (x - mu) / sigma;
//     return -0.5 * z * z - log(sigma) - 0.9189385332; // log(sqrt(2*pi))
//   }
// }
//
// // ── Internal data classes ─────────────────────────────────────────────
//
// class _GaussParam {
//   final double mu;
//   final double sigma;
//   const _GaussParam({required this.mu, required this.sigma});
// }
//
// class _GaussLoc {
//   final double x;
//   final double y;
//   final int floor;
//   final Map<String, _GaussParam> beacons;
//   const _GaussLoc(
//       {required this.x,
//         required this.y,
//         required this.floor,
//         required this.beacons});
// }
//
// class _GaussResult {
//   final double topConfidence;
//   final List<ZoneCandidate> candidates;
//   const _GaussResult({required this.topConfidence, required this.candidates});
// }


/// BLE Indoor Localization — Flutter/Dart
/// ========================================
/// Drop-in inference engine. No dependencies beyond dart:convert and dart:math.
/// Load model JSON once at startup, call predict() on every scan.
///
/// WKNN now exposes similarity % per candidate and interpolates when
/// top-2 candidates are within [interpolationThreshold] of each other.
///
///   result.wknn.candidates        → List<WKNNCandidate> with similarity %
///   result.wknn.isInterpolated    → true when 49/51-style blend happened
///   result.gaussian.x/y           → exact continuous position
///   result.gaussian.confidence     → certainty [0–1]

import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

// ─────────────────────────────────────────────────────────────────────────────
// When top-2 WKNN candidates are within this gap (e.g. 49% vs 51%),
// interpolate instead of snapping. 10 = gap must be < 10 percentage points.
// ─────────────────────────────────────────────────────────────────────────────
const double _interpolationThreshold = 10.0;

// ── WKNN candidate ────────────────────────────────────────────────────────────
class WKNNCandidate {
  /// Zone label e.g. "113_314"
  final String zone;
  final double x;
  final double y;

  /// Similarity [0–100] — inverse-distance weight normalised across top-k.
  final double similarity;

  const WKNNCandidate({
    required this.zone,
    required this.x,
    required this.y,
    required this.similarity,
  });

  @override
  String toString() =>
      '$zone  ${similarity.toStringAsFixed(1)}%  '
          '(X=${x.toStringAsFixed(1)}, Y=${y.toStringAsFixed(1)})';
}

// ── WKNN result ───────────────────────────────────────────────────────────────
class WKNNResult {
  /// Final X/Y — either snapped to best candidate or interpolated.
  final double x;
  final double y;

  /// Real-world metres from origin
  final double xMetres;
  final double yMetres;

  /// Best-matching zone label
  final String zone;

  /// True when result is an interpolation between two close candidates.
  /// e.g. candidate 1 = 49%, candidate 2 = 51% → interpolated midpoint.
  final bool isInterpolated;

  /// All top-k candidates sorted by similarity descending.
  final List<WKNNCandidate> candidates;

  const WKNNResult({
    required this.x,
    required this.y,
    required this.xMetres,
    required this.yMetres,
    required this.zone,
    required this.isInterpolated,
    required this.candidates,
  });

  @override
  String toString() {
    final tag = isInterpolated ? ' [interpolated]' : ' [snapped]';
    return 'WKNN$tag → X=${x.toStringAsFixed(1)} Y=${y.toStringAsFixed(1)}'
        ' zone=$zone\n'
        + candidates.map((c) => '  ${c.toString()}').join('\n');
  }
}

// ── Gaussian result ───────────────────────────────────────────────────────────
class GaussianResult {
  final double x;
  final double y;
  final double xMetres;
  final double yMetres;

  /// Confidence [0–1]
  final double confidence;

  /// Top-5 candidate zones with probabilities
  final List<ZoneCandidate> topCandidates;

  const GaussianResult({
    required this.x,
    required this.y,
    required this.xMetres,
    required this.yMetres,
    required this.confidence,
    required this.topCandidates,
  });

  @override
  String toString() =>
      'Gaussian → X=${x.toStringAsFixed(1)} Y=${y.toStringAsFixed(1)}'
          ' conf=${(confidence * 100).toStringAsFixed(1)}%';
}

// ── Combined result ───────────────────────────────────────────────────────────
class LocalizationResult {
  final WKNNResult     wknn;
  final GaussianResult gaussian;
  final int            floor;

  // Convenience passthrough — keeps existing code working
  double get x           => wknn.x;
  double get y           => wknn.y;
  double get xMetres     => wknn.xMetres;
  double get yMetres     => wknn.yMetres;
  double get confidence  => gaussian.confidence;
  String get nearestZone => wknn.zone;
  List<ZoneCandidate> get topCandidates => gaussian.topCandidates;

  const LocalizationResult({
    required this.wknn,
    required this.gaussian,
    required this.floor,
  });

  @override
  String toString() => '${wknn.toString()}\n${gaussian.toString()}';
}

class ZoneCandidate {
  final String label;
  final double x;
  final double y;
  final int    floor;
  final double probability;
  const ZoneCandidate({
    required this.label,
    required this.x,
    required this.y,
    required this.floor,
    required this.probability,
  });
}

// ── Model ─────────────────────────────────────────────────────────────────────
class BLELocalizer {
  final List<String>       _beaconIds;
  final double             _scaleMPx;
  final double             _bleMin;
  final double             _bleMax;
  final double             _noSignal;
  final int                _k;
  final List<List<double>> _xTrain;
  final List<List<double>> _yTrain;
  final Map<String, _GaussLoc> _gaussLocs;

  BLELocalizer._({
    required List<String> beaconIds,
    required double scaleMPx,
    required double bleMin,
    required double bleMax,
    required double noSignal,
    required int k,
    required List<List<double>> xTrain,
    required List<List<double>> yTrain,
    required Map<String, _GaussLoc> gaussLocs,
  })  : _beaconIds = beaconIds,
        _scaleMPx  = scaleMPx,
        _bleMin    = bleMin,
        _bleMax    = bleMax,
        _noSignal  = noSignal,
        _k         = k,
        _xTrain    = xTrain,
        _yTrain    = yTrain,
        _gaussLocs = gaussLocs;

  static Future<BLELocalizer> fromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return fromJson(raw);
  }

  static BLELocalizer fromJson(String jsonStr) {
    final Map<String, dynamic> data = json.decode(jsonStr);
    final beaconIds = List<String>.from(data['beacon_ids']);
    final scaleMPx  = (data['scale_m_px'] as num).toDouble();
    final bleMin    = (data['ble_min']    as num).toDouble();
    final bleMax    = (data['ble_max']    as num).toDouble();
    final noSignal  = (data['no_signal']  as num).toDouble();

    final wknnData = data['wknn'] as Map<String, dynamic>;
    final k        = wknnData['k'] as int;
    final xTrain   = (wknnData['X_train'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();
    final yTrain   = (wknnData['y_train'] as List)
        .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
        .toList();

    final gaussData = data['gaussian']['locations'] as Map<String, dynamic>;
    final gaussLocs = <String, _GaussLoc>{};
    gaussData.forEach((label, locData) {
      final ld        = locData as Map<String, dynamic>;
      final beaconMap = <String, _GaussParam>{};
      (ld['beacons'] as Map<String, dynamic>).forEach((beacon, params) {
        final p = params as Map<String, dynamic>;
        beaconMap[beacon] = _GaussParam(
          mu:    (p['mu']    as num).toDouble(),
          sigma: (p['sigma'] as num).toDouble(),
        );
      });
      gaussLocs[label] = _GaussLoc(
        x:       (ld['x']     as num).toDouble(),
        y:       (ld['y']     as num).toDouble(),
        floor:   (ld['floor'] as num).toInt(),
        beacons: beaconMap,
      );
    });

    return BLELocalizer._(
      beaconIds: beaconIds,
      scaleMPx:  scaleMPx,
      bleMin:    bleMin,
      bleMax:    bleMax,
      noSignal:  noSignal,
      k:         k,
      xTrain:    xTrain,
      yTrain:    yTrain,
      gaussLocs: gaussLocs,
    );
  }

  // ── Public API ────────────────────────────────────────────────────────────
  LocalizationResult predict(Map<String, List<double>> scan) {
    final vec     = _buildFeatureVector(scan);
    final wknn    = _wknnPredict(vec);
    final gaussRaw = _gaussianPredict(vec);

    // Floor from best WKNN candidate
    final bestZone = wknn.candidates.first.zone;
    final floor    = _gaussLocs[bestZone]?.floor ?? 0;

    final gauss = GaussianResult(
      x:             gaussRaw.x,
      y:             gaussRaw.y,
      xMetres:       gaussRaw.x * _scaleMPx,
      yMetres:       gaussRaw.y * _scaleMPx,
      confidence:    gaussRaw.topConfidence,
      topCandidates: gaussRaw.candidates,
    );

    return LocalizationResult(wknn: wknn, gaussian: gauss, floor: floor);
  }

  LocalizationResult predictFromMeans(Map<String, double> means) =>
      predict(means.map((k, v) => MapEntry(k, [v])));

  // ── Feature vector ────────────────────────────────────────────────────────
  List<double> _buildFeatureVector(Map<String, List<double>> scan) {
    return _beaconIds.map((beacon) {
      final readings = scan[beacon];
      if (readings == null || readings.isEmpty) return _noSignal;
      final clean = readings.where((v) => v >= _bleMin && v <= _bleMax).toList();
      if (clean.isEmpty) return _noSignal;
      return _trimmedMean(clean);
    }).toList();
  }

  double _trimmedMean(List<double> vals) {
    if (vals.length <= 3) return vals.reduce((a, b) => a + b) / vals.length;
    final sorted  = List<double>.from(vals)..sort();
    final trim    = (vals.length * 0.1).round().clamp(1, vals.length ~/ 3);
    final trimmed = sorted.sublist(trim, sorted.length - trim);
    return trimmed.reduce((a, b) => a + b) / trimmed.length;
  }

  // ── WKNN with similarity % and interpolation ──────────────────────────────
  //
  // Steps:
  //  1. Compute Euclidean distance from live scan to every training session.
  //  2. Take top-k nearest sessions.
  //  3. Convert distances → inverse-distance weights → similarity percentages.
  //  4. Aggregate per unique zone (a zone may have multiple training sessions).
  //  5. If top-2 zones are within [_interpolationThreshold]% of each other
  //     → interpolate their positions weighted by similarity.
  //     Otherwise → snap to the best zone.
  // ─────────────────────────────────────────────────────────────────────────
  WKNNResult _wknnPredict(List<double> vec) {
    // Step 1: distance to every training session
    final distances = List<double>.generate(_xTrain.length, (i) {
      double sum = 0;
      for (int j = 0; j < vec.length; j++) {
        final d = vec[j] - _xTrain[i][j];
        sum += d * d;
      }
      return sqrt(sum);
    });

    // Step 2: top-k indices
    // Use max(k, 5) so we always have enough candidates for zone aggregation
    final kExpanded = max(_k, 5).clamp(1, _xTrain.length);
    final indices   = List<int>.generate(_xTrain.length, (i) => i)
      ..sort((a, b) => distances[a].compareTo(distances[b]));
    final topK = indices.take(kExpanded).toList();

    // Step 3: inverse-distance weights
    final rawWeights = topK.map((i) => 1.0 / (distances[i] + 1e-9)).toList();
    final sumW       = rawWeights.reduce((a, b) => a + b);
    final normW      = rawWeights.map((w) => w / sumW).toList();

    // Step 4: aggregate weight per unique zone
    // zone = nearest Gaussian reference zone to each training session's X,Y
    final zoneWeights = <String, double>{};
    final zonePos     = <String, List<double>>{};

    for (int i = 0; i < topK.length; i++) {
      final tx = _yTrain[topK[i]][0];
      final ty = _yTrain[topK[i]][1];

      // Find nearest named zone to this training point
      String nearestZone = '';
      double nearestDist = double.infinity;
      _gaussLocs.forEach((label, loc) {
        final d = sqrt(pow(tx - loc.x, 2) + pow(ty - loc.y, 2));
        if (d < nearestDist) { nearestDist = d; nearestZone = label; }
      });

      zoneWeights[nearestZone] =
          (zoneWeights[nearestZone] ?? 0) + normW[i];
      zonePos[nearestZone] = [
        _gaussLocs[nearestZone]!.x,
        _gaussLocs[nearestZone]!.y,
      ];
    }

    // Sort zones by weight descending
    final sortedZones = zoneWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Re-normalise to 100%
    final totalW = sortedZones.fold(0.0, (s, e) => s + e.value);
    final candidates = sortedZones.map((e) {
      final pos = zonePos[e.key]!;
      return WKNNCandidate(
        zone:       e.key,
        x:          pos[0],
        y:          pos[1],
        similarity: (e.value / totalW) * 100.0,
      );
    }).toList();

    // Step 5: interpolate or snap
    final best = candidates.first;
    bool interpolated = false;
    double finalX = best.x;
    double finalY = best.y;

    if (candidates.length >= 2) {
      final second = candidates[1];
      final gap    = best.similarity - second.similarity;

      if (gap < _interpolationThreshold) {
        // Too close to call — blend positions by similarity weight
        final w1 = best.similarity / (best.similarity + second.similarity);
        final w2 = second.similarity / (best.similarity + second.similarity);
        finalX       = w1 * best.x + w2 * second.x;
        finalY       = w1 * best.y + w2 * second.y;
        interpolated = true;

        debugWKNN(best, second, gap, finalX, finalY);
      }
    }

    return WKNNResult(
      x:              finalX,
      y:              finalY,
      xMetres:        finalX * _scaleMPx,
      yMetres:        finalY * _scaleMPx,
      zone:           best.zone,
      isInterpolated: interpolated,
      candidates:     candidates,
    );
  }

  // ignore: non_constant_identifier_names
  void debugWKNN(WKNNCandidate a, WKNNCandidate b,
      double gap, double rx, double ry) {
    // ignore: avoid_print
    print('WKNN interpolated: ${a.zone} ${a.similarity.toStringAsFixed(1)}% '
        'vs ${b.zone} ${b.similarity.toStringAsFixed(1)}%  '
        'gap=${gap.toStringAsFixed(1)}%  '
        '→ X=${rx.toStringAsFixed(1)} Y=${ry.toStringAsFixed(1)}');
  }

  // ── Gaussian ──────────────────────────────────────────────────────────────
  _GaussRaw _gaussianPredict(List<double> vec) {
    final scores = <String, double>{};
    _gaussLocs.forEach((label, loc) {
      double ll = 0.0;
      for (int i = 0; i < _beaconIds.length; i++) {
        final beacon = _beaconIds[i];
        final v      = vec[i];
        final params = loc.beacons[beacon];
        if (params == null) {
          if (v > _noSignal + 1) ll += log(1e-9);
        } else {
          if (v > _noSignal + 1) {
            ll += _gaussianLogPdf(v, params.mu, params.sigma);
          } else if (params.mu > -85) {
            ll -= 2.0;
          }
        }
      }
      scores[label] = ll;
    });

    final sorted    = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5      = sorted.take(5).toList();
    final maxLL     = top5.first.value;
    final expScores = top5.map((e) => exp(e.value - maxLL)).toList();
    final sumExp    = expScores.reduce((a, b) => a + b);
    final probs     = expScores.map((e) => e / sumExp).toList();

    // Weighted centroid = exact continuous position
    double gx = 0, gy = 0;
    for (int i = 0; i < top5.length; i++) {
      final loc = _gaussLocs[top5[i].key]!;
      gx += probs[i] * loc.x;
      gy += probs[i] * loc.y;
    }

    final candidates = List.generate(top5.length, (i) {
      final loc = _gaussLocs[top5[i].key]!;
      return ZoneCandidate(
        label:       top5[i].key,
        x:           loc.x,
        y:           loc.y,
        floor:       loc.floor,
        probability: probs[i],
      );
    });

    return _GaussRaw(
        x: gx, y: gy, topConfidence: probs[0], candidates: candidates);
  }

  double _gaussianLogPdf(double x, double mu, double sigma) {
    final z = (x - mu) / sigma;
    return -0.5 * z * z - log(sigma) - 0.9189385332;
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────
class _GaussParam {
  final double mu, sigma;
  const _GaussParam({required this.mu, required this.sigma});
}

class _GaussLoc {
  final double x, y;
  final int    floor;
  final Map<String, _GaussParam> beacons;
  const _GaussLoc(
      {required this.x, required this.y,
        required this.floor, required this.beacons});
}

class _GaussRaw {
  final double x, y, topConfidence;
  final List<ZoneCandidate> candidates;
  const _GaussRaw(
      {required this.x, required this.y,
        required this.topConfidence, required this.candidates});
}