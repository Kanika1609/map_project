// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:maplibre_gl/maplibre_gl.dart';
//
// class IndoorMapScreen extends StatefulWidget {
//   const IndoorMapScreen({super.key});
//
//   @override
//   State<IndoorMapScreen> createState() => _IndoorMapScreenState();
// }
//
// class _IndoorMapScreenState extends State<IndoorMapScreen> {
//   MapLibreMapController? _mapController;
//   String? _styleJson;
//
//   static const double _roomHeightMeters = 3.0;
//   static const double _initialPitchDeg = 45.0;
//   static const double _initialBearingDeg = 0.0;
//
//   // ALL labels in the dataset — could be 50, could be 5000. We never loop
//   // over this whole list on every camera move; only the visible slice.
//   final List<Map<String, dynamic>> _rawLabels = [];
//
//   double? _lastPitch;
//   double? _lastBearing;
//   DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
//
//   @override
//   void initState() {
//     super.initState();
//     _loadStyle();
//   }
//
//   @override
//   void dispose() {
//     _mapController?.removeListener(_onCameraMoved);
//     super.dispose();
//   }
//
//   Future<void> _loadStyle() async {
//     final jsonStr = await rootBundle.loadString('assets/style/basemap.json');
//     if (mounted) setState(() => _styleJson = jsonStr);
//   }
//
//   LatLng _elevatedLabelPosition(double lat, double lng, double pitchDeg, double bearingDeg) {
//     final pitchRad = pitchDeg * math.pi / 180.0;
//     final bearingRad = bearingDeg * math.pi / 180.0;
//     final offsetMeters = _roomHeightMeters * math.tan(pitchRad);
//     const metersPerDegreeLat = 111320.0;
//     final metersPerDegreeLng = 111320.0 * math.cos(lat * math.pi / 180.0);
//     final dLat = offsetMeters * math.cos(bearingRad) / metersPerDegreeLat;
//     final dLng = offsetMeters * math.sin(bearingRad) / metersPerDegreeLng;
//     return LatLng(lat + dLat, lng + dLng);
//   }
//
//   Future<void> _loadRoomsOntoMap() async {
//     final jsonString = await rootBundle.loadString('assets/data/floor_0.json');
//     final List<dynamic> allFeatures = jsonDecode(jsonString);
//
//     final List<Map<String, dynamic>> roomFeatures = [];
//     _rawLabels.clear();
//
//     for (final feature in allFeatures) {
//       final properties = feature['properties'] ?? {};
//       final polygonType = properties['polygonType'];
//       final isRoomOrCubicle = polygonType == 'Room' || polygonType == 'Cubicle';
//       final isPolygon = feature['geometry']?['type'] == 'Polygon';
//
//       if (isRoomOrCubicle && isPolygon) {
//         roomFeatures.add({
//           'type': 'Feature',
//           'geometry': feature['geometry'],
//           'properties': {'polygonType': polygonType},
//         });
//
//         final List<dynamic> ring = feature['geometry']['coordinates'][0];
//         double latSum = 0, lngSum = 0;
//         for (final coord in ring) {
//           lngSum += (coord[0] as num).toDouble();
//           latSum += (coord[1] as num).toDouble();
//         }
//         final centerLat = latSum / ring.length;
//         final centerLng = lngSum / ring.length;
//
//         final String? label = properties['name'] ?? properties['cubicleName'];
//         if (label != null && label != 'undefined' && label.toString().trim().isNotEmpty) {
//           _rawLabels.add({
//             'lat': centerLat,
//             'lng': centerLng,
//             'label': label,
//             'rotation': _dominantEdgeBearing(ring, centerLat),
//           });
//         }
//       }
//     }
//
//     await _mapController!.addSource(
//       'roomsSource',
//       GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': roomFeatures}),
//     );
//     await _mapController!.addFillExtrusionLayer(
//       'roomsSource',
//       'roomsExtrusion',
//       const FillExtrusionLayerProperties(
//         fillExtrusionHeight: _roomHeightMeters,
//         fillExtrusionBase: 0.0,
//         fillExtrusionOpacity: 0.75,
//         fillExtrusionColor: [
//           'match',
//           ['get', 'polygonType'],
//           'Room', '#3388ff',
//           'Cubicle', '#ff9933',
//           '#999999',
//         ],
//       ),
//     );
//
//     await _mapController!.addSource(
//       'labelsSource',
//       GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
//     );
//     await _mapController!.addSymbolLayer(
//       'labelsSource',
//       'roomLabels',
//       const SymbolLayerProperties(
//         textField: ['get', 'label'],
//         textFont: ['Open Sans Regular'],
//         textSize: 12,
//         textColor: '#000000',
//         textHaloColor: '#ffffff',
//         textHaloWidth: 1.2,
//         textAllowOverlap: false,
//         textIgnorePlacement: false,
//         textOptional: true,
//         textRotate: ['get', 'rotation'],
//         textRotationAlignment: 'map',
//         textPitchAlignment: 'map',
//       ),
//       minzoom: 18,
//     );
//
//     _mapController!.addListener(_onCameraMoved);
//
//     // Initial placement.
//     await _refreshVisibleLabels();
//   }
//
//   void _onCameraMoved() {
//     // Cap updates to ~20 times/second max — protects against extremely
//     // fast gesture events firing faster than the map can actually redraw.
//     final now = DateTime.now();
//     if (now.difference(_lastUpdate).inMilliseconds < 50) return;
//
//     if (_mapController == null) return;
//     final camera = _mapController!.cameraPosition;
//     if (camera == null) return;
//
//     if (_lastPitch != null &&
//         (camera.tilt - _lastPitch!).abs() < 0.1 &&
//         (camera.bearing - _lastBearing!).abs() < 0.1) {
//       return; // camera didn't meaningfully move, skip
//     }
//
//     _lastUpdate = now;
//     _lastPitch = camera.tilt;
//     _lastBearing = camera.bearing;
//     _refreshVisibleLabels();
//   }
//
//   // THE KEY FIX: only rebuild labels that are actually inside the visible
//   // map area right now, no matter how many total rooms exist in the data.
//   Future<void> _refreshVisibleLabels() async {
//     if (_mapController == null || _rawLabels.isEmpty) return;
//
//     final camera = _mapController!.cameraPosition;
//     if (camera == null) return;
//
//     // Ask MapLibre what area of the world is currently on screen.
//     final bounds = await _mapController!.getVisibleRegion();
//
//     // Add a little padding around the edges so labels don't pop in/out
//     // abruptly right at the screen border.
//     const padding = 0.002; // roughly ~200m of lat/lng padding
//     final minLat = bounds.southwest.latitude - padding;
//     final maxLat = bounds.northeast.latitude + padding;
//     final minLng = bounds.southwest.longitude - padding;
//     final maxLng = bounds.northeast.longitude + padding;
//
//     // Cheap filter: no matter if _rawLabels has 50 or 50,000 entries, this
//     // is just a fast in-memory loop with simple number comparisons.
//     final visibleLabels = _rawLabels.where((raw) {
//       final lat = raw['lat'] as double;
//       final lng = raw['lng'] as double;
//       return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
//     }).toList();
//
//     // Only the visible subset gets the (relatively) expensive elevation
//     // math + GeoJSON rebuild — this is what keeps performance flat
//     // regardless of total dataset size.
//     final features = visibleLabels.map((raw) {
//       final elevated = _elevatedLabelPosition(
//         raw['lat'] as double,
//         raw['lng'] as double,
//         camera.tilt,
//         camera.bearing,
//       );
//       return {
//         'type': 'Feature',
//         'geometry': {
//           'type': 'Point',
//           'coordinates': [elevated.longitude, elevated.latitude],
//         },
//         'properties': {
//           'label': raw['label'],
//           'rotation': raw['rotation'],
//         },
//       };
//     }).toList();
//
//     await _mapController!.setGeoJsonSource(
//       'labelsSource',
//       {'type': 'FeatureCollection', 'features': features},
//     );
//   }
//
//   double _dominantEdgeBearing(List<dynamic> ring, double centerLat) {
//     final latRad = centerLat * (math.pi / 180.0);
//     final lngScale = math.cos(latRad);
//     double bestLength = -1, bestBearing = 0;
//     for (int i = 0; i < ring.length - 1; i++) {
//       final lng1 = (ring[i][0] as num).toDouble();
//       final lat1 = (ring[i][1] as num).toDouble();
//       final lng2 = (ring[i + 1][0] as num).toDouble();
//       final lat2 = (ring[i + 1][1] as num).toDouble();
//       final dx = (lng2 - lng1) * lngScale;
//       final dy = lat2 - lat1;
//       final length = (dx * dx + dy * dy);
//       if (length > bestLength) {
//         bestLength = length;
//         bestBearing = math.atan2(dx, dy) * (180.0 / math.pi);
//       }
//     }
//     while (bestBearing > 90) bestBearing -= 180;
//     while (bestBearing < -90) bestBearing += 180;
//     return bestBearing;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_styleJson == null) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Indoor Map')),
//       body: MapLibreMap(
//         styleString: _styleJson!,
//         initialCameraPosition: const CameraPosition(
//           target: LatLng(32.5645, 75.0359),
//           zoom: 18,
//           tilt: _initialPitchDeg,
//           bearing: _initialBearingDeg,
//         ),
//         trackCameraPosition: true,
//         rotateGesturesEnabled: true,
//         tiltGesturesEnabled: true,
//         onMapCreated: (controller) => _mapController = controller,
//         onStyleLoadedCallback: () async => await _loadRoomsOntoMap(),
//       ),
//     );
//   }
// }
//
//

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre_gl/maplibre_gl.dart';

class IndoorMapScreen extends StatefulWidget {
  const IndoorMapScreen({super.key});

  @override
  State<IndoorMapScreen> createState() => _IndoorMapScreenState();
}

class _IndoorMapScreenState extends State<IndoorMapScreen> {
  MapLibreMapController? _mapController;
  String? _styleJson;

  static const double _roomHeightMeters = 3.0;
  static const double _initialPitchDeg = 45.0;
  static const double _initialBearingDeg = 0.0;

  // Hindi word appended next to every room/cubicle label.
  static const String _hindiRoomWord = 'कक्ष';

  // ALL labels in the dataset — could be 50, could be 5000. We never loop
  // over this whole list on every camera move; only the visible slice.
  final List<Map<String, dynamic>> _rawLabels = [];

  double? _lastPitch;
  double? _lastBearing;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  @override
  void dispose() {
    _mapController?.removeListener(_onCameraMoved);
    super.dispose();
  }

  Future<void> _loadStyle() async {
    final jsonStr = await rootBundle.loadString('assets/style/basemap.json');
    if (mounted) setState(() => _styleJson = jsonStr);
  }

  LatLng _elevatedLabelPosition(double lat, double lng, double pitchDeg, double bearingDeg) {
    final pitchRad = pitchDeg * math.pi / 180.0;
    final bearingRad = bearingDeg * math.pi / 180.0;
    final offsetMeters = _roomHeightMeters * math.tan(pitchRad);
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng = 111320.0 * math.cos(lat * math.pi / 180.0);
    final dLat = offsetMeters * math.cos(bearingRad) / metersPerDegreeLat;
    final dLng = offsetMeters * math.sin(bearingRad) / metersPerDegreeLng;
    return LatLng(lat + dLat, lng + dLng);
  }

  // Returns true if a name value is missing/unusable ("undefined", null, empty, etc.)
  bool _isUnusableName(String? value) {
    if (value == null) return true;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    return trimmed.toLowerCase() == 'undefined';
  }

  // Builds the bilingual label text: "<English label>\n<कक्ष>"
  // If the source name is a pipe-delimited pair (e.g. "Sitting Area | Reception"),
  // only the first segment is used before appending the Hindi word.
  String _buildBilingualLabel(String rawLabel) {
    final firstSegment = rawLabel.split('|').first.trim();
    return '$firstSegment\n$_hindiRoomWord';
  }

  // Standard Web Mercator meters-per-pixel formula for a given latitude/zoom.
  double _metersPerPixel(double latDeg, double zoom) {
    final latRad = latDeg * math.pi / 180.0;
    return 156543.03392 * math.cos(latRad) / math.pow(2, zoom);
  }

  // Computes a FIXED font size (px) for one room's label so the widest line
  // of text stays within that room's on-screen width — evaluated at the
  // symbol layer's minzoom (18), the most "zoomed out" the label is ever
  // shown. Because text-size below is a plain per-feature value (not a
  // zoom-interpolated expression), this number never changes afterward —
  // and since rooms only get visually larger as you zoom in past minzoom,
  // a size that fits at minzoom is guaranteed to keep fitting beyond it.
  double _computeFixedFontSize({
    required List<dynamic> ring,
    required double centerLat,
    required double centerLng,
    required double rotationDeg,
    required String englishLabel,
  }) {
    final latRad = centerLat * math.pi / 180.0;
    final rotRad = rotationDeg * math.pi / 180.0;
    // Unit vector along the text's rotation direction — the room's extent
    // along THIS axis is what actually constrains the text width.
    final axisX = math.sin(rotRad);
    final axisY = math.cos(rotRad);

    double minProj = double.infinity, maxProj = -double.infinity;
    for (final coord in ring) {
      final lng = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      final dx = (lng - centerLng) * 111320.0 * math.cos(latRad);
      final dy = (lat - centerLat) * 111320.0;
      final proj = dx * axisX + dy * axisY;
      if (proj < minProj) minProj = proj;
      if (proj > maxProj) maxProj = proj;
    }
    final roomWidthMeters = (maxProj - minProj).abs();

    const referenceZoom = 18.0; // matches addSymbolLayer's minzoom below
    final metersPerPixel = _metersPerPixel(centerLat, referenceZoom);
    final roomWidthPixels = roomWidthMeters / metersPerPixel;

    // The longer of the two lines (English name vs. the Hindi word) is what
    // actually determines the text block's on-screen width.
    final longestLineChars = math.max(englishLabel.length, _hindiRoomWord.length);

    const avgCharWidthFactor = 0.6; // rough average glyph width / font size
    const marginFactor = 0.85; // small margin so text doesn't touch the edges
    const defaultFontSize = 12.0; // previous fixed size, used as a ceiling
    const minFontSize = 7.0; // floor so text never becomes unreadable

    final maxFittingSize =
        (roomWidthPixels * marginFactor) / (longestLineChars * avgCharWidthFactor);

    return maxFittingSize.clamp(minFontSize, defaultFontSize);
  }

  double _normalizeRotation(double deg) {
    var d = deg;
    while (d > 90) d -= 180;
    while (d < -90) d += 180;
    return d;
  }

  // Tries the text along the room's long axis (dominant edge) AND its
  // perpendicular (short axis), and picks whichever orientation lets the
  // text render at a LARGER fitting size — i.e. whichever axis actually has
  // more usable space for this specific label. This is what makes a label
  // that doesn't fit along the width fall back to running along the length.
  ({double rotation, double fontSize}) _computeBestFit({
    required List<dynamic> ring,
    required double centerLat,
    required double centerLng,
    required String englishLabel,
  }) {
    final longAxisRotation = _dominantEdgeBearing(ring, centerLat);
    final shortAxisRotation = _normalizeRotation(longAxisRotation + 90.0);

    final longAxisFontSize = _computeFixedFontSize(
      ring: ring,
      centerLat: centerLat,
      centerLng: centerLng,
      rotationDeg: longAxisRotation,
      englishLabel: englishLabel,
    );
    final shortAxisFontSize = _computeFixedFontSize(
      ring: ring,
      centerLat: centerLat,
      centerLng: centerLng,
      rotationDeg: shortAxisRotation,
      englishLabel: englishLabel,
    );

    if (shortAxisFontSize > longAxisFontSize) {
      return (rotation: shortAxisRotation, fontSize: shortAxisFontSize);
    }
    return (rotation: longAxisRotation, fontSize: longAxisFontSize);
  }

  Future<void> _loadRoomsOntoMap() async {
    final jsonString = await rootBundle.loadString('assets/data/floor_0.json');
    final List<dynamic> allFeatures = jsonDecode(jsonString);

    final List<Map<String, dynamic>> roomFeatures = [];
    _rawLabels.clear();

    for (final feature in allFeatures) {
      final properties = feature['properties'] ?? {};
      final polygonType = properties['polygonType'];
      final isRoomOrCubicle = polygonType == 'Room' || polygonType == 'Cubicle';
      final isPolygon = feature['geometry']?['type'] == 'Polygon';

      if (isRoomOrCubicle && isPolygon) {
        roomFeatures.add({
          'type': 'Feature',
          'geometry': feature['geometry'],
          'properties': {'polygonType': polygonType},
        });

        final List<dynamic> ring = feature['geometry']['coordinates'][0];
        double latSum = 0, lngSum = 0;
        for (final coord in ring) {
          lngSum += (coord[0] as num).toDouble();
          latSum += (coord[1] as num).toDouble();
        }
        final centerLat = latSum / ring.length;
        final centerLng = lngSum / ring.length;

        // Prefer `name`, fall back to `cubicleName`. Both are checked against
        // the "undefined" sentinel value (case-insensitive, trimmed) so rows
        // where `name` is the literal string "undefined" don't slip through.
        final String? nameField = properties['name'] as String?;
        final String? cubicleField = properties['cubicleName'] as String?;

        String? label;
        if (!_isUnusableName(nameField)) {
          label = nameField;
        } else if (!_isUnusableName(cubicleField)) {
          label = cubicleField;
        }

        if (label != null && label.trim().toLowerCase() != 'wall') {
          final englishLabel = label.split('|').first.trim();
          final fit = _computeBestFit(
            ring: ring,
            centerLat: centerLat,
            centerLng: centerLng,
            englishLabel: englishLabel,
          );
          _rawLabels.add({
            'lat': centerLat,
            'lng': centerLng,
            'label': _buildBilingualLabel(label),
            'rotation': fit.rotation,
            'fontSize': fit.fontSize,
          });
        }
      }
    }

    await _mapController!.addSource(
      'roomsSource',
      GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': roomFeatures}),
    );
    await _mapController!.addFillExtrusionLayer(
      'roomsSource',
      'roomsExtrusion',
      const FillExtrusionLayerProperties(
        fillExtrusionHeight: _roomHeightMeters,
        fillExtrusionBase: 0.0,
        fillExtrusionOpacity: 0.75,
        fillExtrusionColor: [
          'match',
          ['get', 'polygonType'],
          'Room', '#3388ff',
          'Cubicle', '#ff9933',
          '#999999',
        ],
      ),
    );

    await _mapController!.addSource(
      'labelsSource',
      GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
    );
    await _mapController!.addSymbolLayer(
      'labelsSource',
      'roomLabels',
      const SymbolLayerProperties(
        textField: ['get', 'label'],
        // "Noto Sans Devanagari Regular" is NOT a real folder on
        // fonts.openmaptiles.org — the per-script .ttf files in the
        // openmaptiles/fonts source repo get merged at build time into ONE
        // combined multi-script font, deployed under the name
        // "Klokantech Noto Sans Regular". That's the correct name to request.
        textFont: ['Klokantech Noto Sans Regular'],
        // Per-room fixed size (computed in _computeFixedFontSize) instead of
        // a flat constant — guarantees the text fits under each room's own
        // width, and since this isn't a zoom-interpolated expression it
        // never changes as you zoom in/out.
        textSize: ['get', 'fontSize'],
        textColor: '#000000',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.2,
        textAllowOverlap: false,
        textIgnorePlacement: false,
        textOptional: true,
        textRotate: ['get', 'rotation'],
        textRotationAlignment: 'map',
        textPitchAlignment: 'map',
      ),
      minzoom: 18,
    );

    _mapController!.addListener(_onCameraMoved);

    // Initial placement.
    await _refreshVisibleLabels();
  }

  void _onCameraMoved() {
    // Cap updates to ~20 times/second max — protects against extremely
    // fast gesture events firing faster than the map can actually redraw.
    final now = DateTime.now();
    if (now.difference(_lastUpdate).inMilliseconds < 50) return;

    if (_mapController == null) return;
    final camera = _mapController!.cameraPosition;
    if (camera == null) return;

    if (_lastPitch != null &&
        (camera.tilt - _lastPitch!).abs() < 0.1 &&
        (camera.bearing - _lastBearing!).abs() < 0.1) {
      return; // camera didn't meaningfully move, skip
    }

    _lastUpdate = now;
    _lastPitch = camera.tilt;
    _lastBearing = camera.bearing;
    _refreshVisibleLabels();
  }

  // THE KEY FIX: only rebuild labels that are actually inside the visible
  // map area right now, no matter how many total rooms exist in the data.
  Future<void> _refreshVisibleLabels() async {
    if (_mapController == null || _rawLabels.isEmpty) return;

    // cameraPosition can briefly be null right after the style finishes
    // loading, before trackCameraPosition reports its first update. Bailing
    // out here (as before) meant labelsSource was never populated on the
    // very first call — fall back to the initial pitch/bearing instead.
    final camera = _mapController!.cameraPosition;
    final double tilt = camera?.tilt ?? _initialPitchDeg;
    final double bearing = camera?.bearing ?? _initialBearingDeg;

    // Ask MapLibre what area of the world is currently on screen.
    LatLngBounds bounds;
    try {
      bounds = await _mapController!.getVisibleRegion();
    } catch (e) {
      // If this throws right after style load (native view not fully ready
      // yet on some platforms), retry once on the next frame instead of
      // silently dropping all labels.
      debugPrint('getVisibleRegion failed, retrying next frame: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshVisibleLabels());
      return;
    }

    // Add a little padding around the edges so labels don't pop in/out
    // abruptly right at the screen border.
    const padding = 0.002; // roughly ~200m of lat/lng padding
    final minLat = bounds.southwest.latitude - padding;
    final maxLat = bounds.northeast.latitude + padding;
    final minLng = bounds.southwest.longitude - padding;
    final maxLng = bounds.northeast.longitude + padding;

    // Cheap filter: no matter if _rawLabels has 50 or 50,000 entries, this
    // is just a fast in-memory loop with simple number comparisons.
    final visibleLabels = _rawLabels.where((raw) {
      final lat = raw['lat'] as double;
      final lng = raw['lng'] as double;
      return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
    }).toList();

    // Only the visible subset gets the (relatively) expensive elevation
    // math + GeoJSON rebuild — this is what keeps performance flat
    // regardless of total dataset size.
    final features = visibleLabels.map((raw) {
      final elevated = _elevatedLabelPosition(
        raw['lat'] as double,
        raw['lng'] as double,
        tilt,
        bearing,
      );
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [elevated.longitude, elevated.latitude],
        },
        'properties': {
          'label': raw['label'],
          'rotation': raw['rotation'],
          'fontSize': raw['fontSize'],
        },
      };
    }).toList();

    debugPrint('roomLabels: ${features.length} features in view (of ${_rawLabels.length} total)');

    await _mapController!.setGeoJsonSource(
      'labelsSource',
      {'type': 'FeatureCollection', 'features': features},
    );
  }

  double _dominantEdgeBearing(List<dynamic> ring, double centerLat) {
    final latRad = centerLat * (math.pi / 180.0);
    final lngScale = math.cos(latRad);
    double bestLength = -1, bestBearing = 0;
    for (int i = 0; i < ring.length - 1; i++) {
      final lng1 = (ring[i][0] as num).toDouble();
      final lat1 = (ring[i][1] as num).toDouble();
      final lng2 = (ring[i + 1][0] as num).toDouble();
      final lat2 = (ring[i + 1][1] as num).toDouble();
      final dx = (lng2 - lng1) * lngScale;
      final dy = lat2 - lat1;
      final length = (dx * dx + dy * dy);
      if (length > bestLength) {
        bestLength = length;
        bestBearing = math.atan2(dx, dy) * (180.0 / math.pi);
      }
    }
    while (bestBearing > 90) bestBearing -= 180;
    while (bestBearing < -90) bestBearing += 180;
    return bestBearing;
  }

  @override
  Widget build(BuildContext context) {
    if (_styleJson == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Indoor Map')),
      body: MapLibreMap(
        styleString: _styleJson!,
        initialCameraPosition: const CameraPosition(
          target: LatLng(32.5645, 75.0359),
          zoom: 18,
          tilt: _initialPitchDeg,
          bearing: _initialBearingDeg,
        ),
        trackCameraPosition: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        onMapCreated: (controller) => _mapController = controller,
        onStyleLoadedCallback: () async => await _loadRoomsOntoMap(),
      ),
    );
  }
}

// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:maplibre_gl/maplibre_gl.dart';
//
// class IndoorMapScreen extends StatefulWidget {
//   const IndoorMapScreen({super.key});
//
//   @override
//   State<IndoorMapScreen> createState() => _IndoorMapScreenState();
// }
//
// class _IndoorMapScreenState extends State<IndoorMapScreen> {
//   MapLibreMapController? _mapController;
//   String? _styleJson;
//
//   static const double _roomHeightMeters = 3.0;
//   static const double _initialPitchDeg = 45.0;
//   static const double _initialBearingDeg = 0.0;
//
//   // Hindi word appended next to every room/cubicle label.
//   static const String _hindiRoomWord = 'कक्ष';
//
//   // How far "up" (in screen pixels) the text floats above its ground point
//   // to visually suggest a roof label. This is applied via textTranslate
//   // with textTranslateAnchor: 'viewport' — a pure screen-space pixel shift
//   // that is NOT affected by textRotationAlignment or textPitchAlignment.
//   // (textOffset, by contrast, gets rotated along with each room's own
//   // text-rotation angle, which is why labels appeared to "wander" instead
//   // of staying fixed — textTranslate avoids that entirely.)
//   static const double _roofOffsetPixels = -28.0;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadStyle();
//   }
//
//   Future<void> _loadStyle() async {
//     final jsonStr = await rootBundle.loadString('assets/style/basemap.json');
//     if (mounted) setState(() => _styleJson = jsonStr);
//   }
//
//   // Returns true if a name value is missing/unusable ("undefined", null, empty, etc.)
//   bool _isUnusableName(String? value) {
//     if (value == null) return true;
//     final trimmed = value.trim();
//     if (trimmed.isEmpty) return true;
//     return trimmed.toLowerCase() == 'undefined';
//   }
//
//   // Builds the bilingual label text: "<English label>\n<कक्ष>"
//   // If the source name is a pipe-delimited pair (e.g. "Sitting Area | Reception"),
//   // only the first segment is used before appending the Hindi word.
//   String _buildBilingualLabel(String rawLabel) {
//     final firstSegment = rawLabel.split('|').first.trim();
//     return '$firstSegment\n$_hindiRoomWord';
//   }
//
//   // Standard Web Mercator meters-per-pixel formula for a given latitude/zoom.
//   double _metersPerPixel(double latDeg, double zoom) {
//     final latRad = latDeg * math.pi / 180.0;
//     return 156543.03392 * math.cos(latRad) / math.pow(2, zoom);
//   }
//
//   // Computes a FIXED font size (px) for one room's label so the widest line
//   // of text stays within that room's on-screen width — evaluated at the
//   // symbol layer's minzoom (18), the most "zoomed out" the label is ever
//   // shown. Because text-size below is a plain per-feature value (not a
//   // zoom-interpolated expression) AND textPitchAlignment is 'viewport'
//   // (billboarded, so no perspective scaling), this number never changes
//   // afterward no matter how you zoom, tilt, or rotate.
//   double _computeFixedFontSize({
//     required List<dynamic> ring,
//     required double centerLat,
//     required double centerLng,
//     required double rotationDeg,
//     required String englishLabel,
//   }) {
//     final latRad = centerLat * math.pi / 180.0;
//     final rotRad = rotationDeg * math.pi / 180.0;
//     final axisX = math.sin(rotRad);
//     final axisY = math.cos(rotRad);
//
//     double minProj = double.infinity, maxProj = -double.infinity;
//     for (final coord in ring) {
//       final lng = (coord[0] as num).toDouble();
//       final lat = (coord[1] as num).toDouble();
//       final dx = (lng - centerLng) * 111320.0 * math.cos(latRad);
//       final dy = (lat - centerLat) * 111320.0;
//       final proj = dx * axisX + dy * axisY;
//       if (proj < minProj) minProj = proj;
//       if (proj > maxProj) maxProj = proj;
//     }
//     final roomWidthMeters = (maxProj - minProj).abs();
//
//     const referenceZoom = 18.0; // matches addSymbolLayer's minzoom below
//     final metersPerPixel = _metersPerPixel(centerLat, referenceZoom);
//     final roomWidthPixels = roomWidthMeters / metersPerPixel;
//
//     final longestLineChars = math.max(englishLabel.length, _hindiRoomWord.length);
//
//     const avgCharWidthFactor = 0.6;
//     const marginFactor = 0.85;
//     const defaultFontSize = 12.0;
//     const minFontSize = 7.0;
//
//     final maxFittingSize =
//         (roomWidthPixels * marginFactor) / (longestLineChars * avgCharWidthFactor);
//
//     return maxFittingSize.clamp(minFontSize, defaultFontSize);
//   }
//
//   double _normalizeRotation(double deg) {
//     var d = deg;
//     while (d > 90) d -= 180;
//     while (d < -90) d += 180;
//     return d;
//   }
//
//   // Tries the text along the room's long axis AND its perpendicular, and
//   // picks whichever orientation lets the text render at a LARGER fitting
//   // size for this specific label.
//   ({double rotation, double fontSize}) _computeBestFit({
//     required List<dynamic> ring,
//     required double centerLat,
//     required double centerLng,
//     required String englishLabel,
//   }) {
//     final longAxisRotation = _dominantEdgeBearing(ring, centerLat);
//     final shortAxisRotation = _normalizeRotation(longAxisRotation + 90.0);
//
//     final longAxisFontSize = _computeFixedFontSize(
//       ring: ring,
//       centerLat: centerLat,
//       centerLng: centerLng,
//       rotationDeg: longAxisRotation,
//       englishLabel: englishLabel,
//     );
//     final shortAxisFontSize = _computeFixedFontSize(
//       ring: ring,
//       centerLat: centerLat,
//       centerLng: centerLng,
//       rotationDeg: shortAxisRotation,
//       englishLabel: englishLabel,
//     );
//
//     if (shortAxisFontSize > longAxisFontSize) {
//       return (rotation: shortAxisRotation, fontSize: shortAxisFontSize);
//     }
//     return (rotation: longAxisRotation, fontSize: longAxisFontSize);
//   }
//
//   Future<void> _loadRoomsOntoMap() async {
//     final jsonString = await rootBundle.loadString('assets/data/floor_0.json');
//     final List<dynamic> allFeatures = jsonDecode(jsonString);
//
//     final List<Map<String, dynamic>> roomFeatures = [];
//     final List<Map<String, dynamic>> labelFeatures = [];
//
//     for (final feature in allFeatures) {
//       final properties = feature['properties'] ?? {};
//       final polygonType = properties['polygonType'];
//       final isRoomOrCubicle = polygonType == 'Room' || polygonType == 'Cubicle';
//       final isPolygon = feature['geometry']?['type'] == 'Polygon';
//
//       if (isRoomOrCubicle && isPolygon) {
//         roomFeatures.add({
//           'type': 'Feature',
//           'geometry': feature['geometry'],
//           'properties': {'polygonType': polygonType},
//         });
//
//         final List<dynamic> ring = feature['geometry']['coordinates'][0];
//         double latSum = 0, lngSum = 0;
//         for (final coord in ring) {
//           lngSum += (coord[0] as num).toDouble();
//           latSum += (coord[1] as num).toDouble();
//         }
//         final centerLat = latSum / ring.length;
//         final centerLng = lngSum / ring.length;
//
//         final String? nameField = properties['name'] as String?;
//         final String? cubicleField = properties['cubicleName'] as String?;
//
//         String? label;
//         if (!_isUnusableName(nameField)) {
//           label = nameField;
//         } else if (!_isUnusableName(cubicleField)) {
//           label = cubicleField;
//         }
//
//         if (label != null && label.trim().toLowerCase() != 'wall') {
//           final englishLabel = label.split('|').first.trim();
//           final fit = _computeBestFit(
//             ring: ring,
//             centerLat: centerLat,
//             centerLng: centerLng,
//             englishLabel: englishLabel,
//           );
//
//           // Label sits at the room's ground-level centroid. There is no
//           // lat/lng "elevation" trick here anymore — the roof-floating look
//           // comes entirely from textOffset + textPitchAlignment: 'viewport'
//           // in the symbol layer below, which is pure screen-space and never
//           // needs to be recalculated as the camera moves.
//           labelFeatures.add({
//             'type': 'Feature',
//             'geometry': {
//               'type': 'Point',
//               'coordinates': [centerLng, centerLat],
//             },
//             'properties': {
//               'label': _buildBilingualLabel(label),
//               'rotation': fit.rotation,
//               'fontSize': fit.fontSize,
//             },
//           });
//         }
//       }
//     }
//
//     await _mapController!.addSource(
//       'roomsSource',
//       GeojsonSourceProperties(data: {'type': 'FeatureCollection', 'features': roomFeatures}),
//     );
//     await _mapController!.addFillExtrusionLayer(
//       'roomsSource',
//       'roomsExtrusion',
//       const FillExtrusionLayerProperties(
//         fillExtrusionHeight: _roomHeightMeters,
//         fillExtrusionBase: 0.0,
//         fillExtrusionOpacity: 0.75,
//         fillExtrusionColor: [
//           'match',
//           ['get', 'polygonType'],
//           'Room', '#3388ff',
//           'Cubicle', '#ff9933',
//           '#999999',
//         ],
//       ),
//     );
//
//     // Labels are added ONCE, as a static source containing every room on
//     // this floor. MapLibre's own renderer already only draws/labels the
//     // features that fall within the current viewport — there is no need to
//     // hand-roll viewport culling in Dart, and doing so is exactly what was
//     // causing the source to be rebuilt (and labels to visibly flicker/
//     // "reload") on every camera movement.
//     await _mapController!.addSource(
//       'labelsSource',
//       GeojsonSourceProperties(
//         data: {'type': 'FeatureCollection', 'features': labelFeatures},
//       ),
//     );
//     await _mapController!.addSymbolLayer(
//       'labelsSource',
//       'roomLabels',
//       SymbolLayerProperties(
//         textField: ['get', 'label'],
//         textFont: const ['Klokantech Noto Sans Regular'],
//         // Per-room fixed size, computed once at minzoom. Combined with
//         // textPitchAlignment: 'viewport' below, this is now GENUINELY fixed
//         // — it will not grow or shrink as you zoom in/out or tilt the
//         // camera, because the label is billboarded (always rendered flat
//         // toward the viewer) instead of being embedded in the tilted 3D map
//         // plane where perspective would scale it.
//         textSize: ['get', 'fontSize'],
//         textColor: '#000000',
//         textHaloColor: '#ffffff',
//         textHaloWidth: 1.2,
//         textAllowOverlap: false,
//         textIgnorePlacement: false,
//         textOptional: true,
//         // Keep the label's in-plane rotation aligned to the room's own
//         // orientation (this is unrelated to the pitch/perspective issue).
//         textRotate: ['get', 'rotation'],
//         textRotationAlignment: 'map',
//         // THE KEY FIX: 'viewport' instead of 'map'. The label always faces
//         // the camera at a constant on-screen size, regardless of zoom or
//         // tilt — no more perspective-driven size changes.
//         textPitchAlignment: 'viewport',
//         // Fixed screen-space nudge upward, giving the "floating above the
//         // room" / roof-anchored look. Because this is a static pixel value
//         // (not computed from bearing/pitch, and not affected by rotation
//         // alignment the way textOffset is), it never needs to be touched
//         // again and never drifts — this is what lets us delete the camera
//         // listener entirely while keeping the label position truly fixed.
//         textTranslate: const [0, _roofOffsetPixels],
//         textTranslateAnchor: 'viewport',
//       ),
//       minzoom: 18,
//     );
//   }
//
//   double _dominantEdgeBearing(List<dynamic> ring, double centerLat) {
//     final latRad = centerLat * (math.pi / 180.0);
//     final lngScale = math.cos(latRad);
//     double bestLength = -1, bestBearing = 0;
//     for (int i = 0; i < ring.length - 1; i++) {
//       final lng1 = (ring[i][0] as num).toDouble();
//       final lat1 = (ring[i][1] as num).toDouble();
//       final lng2 = (ring[i + 1][0] as num).toDouble();
//       final lat2 = (ring[i + 1][1] as num).toDouble();
//       final dx = (lng2 - lng1) * lngScale;
//       final dy = lat2 - lat1;
//       final length = (dx * dx + dy * dy);
//       if (length > bestLength) {
//         bestLength = length;
//         bestBearing = math.atan2(dx, dy) * (180.0 / math.pi);
//       }
//     }
//     while (bestBearing > 90) bestBearing -= 180;
//     while (bestBearing < -90) bestBearing += 180;
//     return bestBearing;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_styleJson == null) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Indoor Map')),
//       body: MapLibreMap(
//         styleString: _styleJson!,
//         initialCameraPosition: const CameraPosition(
//           target: LatLng(32.5645, 75.0359),
//           zoom: 18,
//           tilt: _initialPitchDeg,
//           bearing: _initialBearingDeg,
//         ),
//         // trackCameraPosition is no longer needed for label logic (there is
//         // none left that depends on the camera), but harmless to keep if
//         // you use camera state elsewhere in the app.
//         trackCameraPosition: true,
//         rotateGesturesEnabled: true,
//         tiltGesturesEnabled: true,
//         onMapCreated: (controller) => _mapController = controller,
//         onStyleLoadedCallback: () async => await _loadRoomsOntoMap(),
//       ),
//     );
//   }
// }







