// map_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Renders the Lecture Hall Complex (LHC) floor plan from the GeoJSON bundled
// as  assets/maps/LHC_geojson.geojson  and places a pulsing marker at the
// position that BLELocalizer.predict() returns.
//
// HOW THE COORDINATE TRANSFORM WORKS
// ────────────────────────────────────
// The BLE model outputs (X, Y) in the same local pixel coordinate system used
// by beacons.geojson  (coordinnatesLocal).  The LHC GeoJSON already uses real
// GPS lat/lon, so no transform is needed for the floor polygons — they just
// get drawn directly.  The marker is placed by converting (X, Y) → (lat, lon)
// via a least-squares affine transform fitted from the 12 beacon control
// points (sub-0.25 m residuals).
//
// Affine coefficients (fitted from beacons.geojson):
//   lat = LAT_A * x  +  LAT_B * y  +  LAT_C
//   lon = LON_A * x  +  LON_B * y  +  LON_C
//
// USAGE
// ─────
// 1. Add to pubspec.yaml:
//      flutter_map: ^7.0.2          (or latest)
//      latlong2: ^0.9.1
//
// 2. Bundle the GeoJSON:
//      assets:
//        - assets/maps/LHC_geojson.geojson
//
// 3. In main.dart, import this file and call:
//      Navigator.push(context, MaterialPageRoute(
//        builder: (_) => LHCMapScreen(predictedX: result.xMetres,
//                                     predictedY: result.yMetres,
//                                     confidence: result.confidence),
//      ));
//
//    Or embed MapFloorView() directly inside your existing Scaffold.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ── Affine transform coefficients ────────────────────────────────────────────
// Fitted by LSQ from all 12 beacons in beacons.geojson.
// Residuals < 0.25 m for all control points.
const double _LAT_A = -2.581647e-06; // ∂lat / ∂x
const double _LAT_B = -9.345429e-07; // ∂lat / ∂y
const double _LAT_C =  2.854359e+01; // lat intercept

const double _LON_A =  1.051413e-06; // ∂lon / ∂x
const double _LON_B = -2.941074e-06; // ∂lon / ∂y
const double _LON_C =  7.719397e+01; // lon intercept

/// Convert model-space (X, Y) → WGS-84 (lat, lon).
LatLng localToGps(double x, double y) => LatLng(
  _LAT_A * x + _LAT_B * y + _LAT_C,
  _LON_A * x + _LON_B * y + _LON_C,
);

// ── Colour palette (taken from the GeoJSON fillColor values) ─────────────────
const _kColors = {
  'Wall'               : Color(0xFF91A5BA),
  'Piller'             : Color(0xFF91A5BA),
  'Stairs'             : Color(0xFF91A5BA),
  'Boundary'           : Color(0xFFB0BEC5),
  'Non Walkable'       : Color(0xFF2D2D2D),
  'room'               : Color(0xFF71A6AD),
  'Lab'                : Color(0xFF71A6AD),
  'Reception'          : Color(0xFF71A6AD),
  'Sitting Area'       : Color(0xFF9BBFC3),
  'Lift'               : Color(0xFFF9F44D),
  'Male Washroom'      : Color(0xFF465BC3),
  'Female Washroom'    : Color(0xFFE585E2),
  'Accessible Washroom': Color(0xFF3ADDE9),
  'Restricted Area'    : Color(0xFFA74444),
};

Color _fillFor(String type) => _kColors[type] ?? const Color(0xFF90A4AE);

// ── Data models ───────────────────────────────────────────────────────────────
class _Room {
  final String name;
  final String type;
  final List<LatLng> points;
  const _Room(this.name, this.type, this.points);
}

// ─────────────────────────────────────────────────────────────────────────────
// Public widget: full-screen map + prediction marker
// ─────────────────────────────────────────────────────────────────────────────
class LHCMapScreen extends StatelessWidget {
  final double predictedX;
  final double predictedY;
  final double confidence;   // 0.0–1.0
  final String nearestZone;

  const LHCMapScreen({
    super.key,
    required this.predictedX,
    required this.predictedY,
    required this.confidence,
    this.nearestZone = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text('Lecture Hall Complex',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _ConfidenceBadge(confidence: confidence),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MapFloorView(
              predictedX: predictedX,
              predictedY: predictedY,
            ),
          ),
          _InfoBar(
            x: predictedX,
            y: predictedY,
            confidence: confidence,
            zone: nearestZone,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Embeddable map widget — use this if you want to embed inside your own Scaffold
// ─────────────────────────────────────────────────────────────────────────────
class MapFloorView extends StatefulWidget {
  /// Gaussian — exact continuous position (blue marker)
  final double predictedX;
  final double predictedY;

  /// WKNN — nearest zone snap (orange marker). Optional.
  final double? wknnX;
  final double? wknnY;

  /// Set to true to auto-centre on the Gaussian marker when prediction updates.
  final bool followMarker;

  const MapFloorView({
    super.key,
    required this.predictedX,
    required this.predictedY,
    this.wknnX,
    this.wknnY,
    this.followMarker = true,
  });

  @override
  State<MapFloorView> createState() => _MapFloorViewState();
}

class _MapFloorViewState extends State<MapFloorView> {
  final MapController _mapCtrl = MapController();
  List<_Room> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
  }

  @override
  void didUpdateWidget(MapFloorView old) {
    super.didUpdateWidget(old);
    if (widget.followMarker &&
        (widget.predictedX != old.predictedX ||
            widget.predictedY != old.predictedY)) {
      final pt = localToGps(widget.predictedX, widget.predictedY);
      try { _mapCtrl.move(pt, _mapCtrl.camera.zoom); } catch (_) {}
    }
  }

  Future<void> _loadGeoJson() async {
    try {
      final raw = await rootBundle.loadString('assets/maps/LHC_geojson.geojson');
      final Map<String, dynamic> gj = json.decode(raw);
      final rooms = <_Room>[];

      for (final feat in (gj['features'] as List)) {
        final props = feat['properties'] as Map<String, dynamic>? ?? {};

        // Only LHC floor-0 polygons
        if (props['buildingName'] != 'LectureHallComplex') continue;
        if ((props['floor'] as num?)?.toInt() != 0) continue;

        final geom = feat['geometry'] as Map<String, dynamic>?;
        if (geom == null) continue;
        if (geom['type'] != 'Polygon') continue;

        final coordsRaw = geom['coordinates'] as List?;
        if (coordsRaw == null || coordsRaw.isEmpty) continue;

        final ring = coordsRaw[0] as List;
        final pts = <LatLng>[];
        for (final pt in ring) {
          if (pt is List && pt.length >= 2) {
            final lon = (pt[0] as num).toDouble();
            final lat = (pt[1] as num).toDouble();
            // Sanity-check: must be within IIT Delhi campus bounds
            if (lat > 28.540 && lat < 28.547 &&
                lon > 77.185 && lon < 77.200) {
              pts.add(LatLng(lat, lon));
            }
          }
        }
        if (pts.length >= 3) {
          rooms.add(_Room(
            (props['name'] as String? ?? ''),
            (props['type'] as String? ?? ''),
            pts,
          ));
        }
      }

      if (mounted) setState(() { _rooms = rooms; _loading = false; });
    } catch (e) {
      debugPrint('MapFloorView GeoJSON load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white70),
            SizedBox(height: 12),
            Text('Loading floor plan…',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      );
    }

    final markerPos = localToGps(widget.predictedX, widget.predictedY);

    // Build polygon layers grouped by draw order (walls on top of floors)
    final bgTypes  = {'Non Walkable', 'Boundary'};
    final topTypes = {'Wall', 'Piller'};

    final bgPolygons  = <Polygon>[];
    final midPolygons = <Polygon>[];
    final topPolygons = <Polygon>[];

    for (final room in _rooms) {
      final fill = _fillFor(room.type);
      final poly = Polygon(
        points: room.points,
        color: fill.withOpacity(bgTypes.contains(room.type) ? 0.85 : 0.55),
        borderColor: fill.withOpacity(0.9),
        borderStrokeWidth: topTypes.contains(room.type) ? 1.5 : 0.8,
        label: _shouldLabel(room.type) ? room.name : null,
        labelStyle: const TextStyle(
          fontSize: 9, color: Colors.white,
          shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
        ),
      );
      if (bgTypes.contains(room.type))  bgPolygons.add(poly);
      else if (topTypes.contains(room.type)) topPolygons.add(poly);
      else midPolygons.add(poly);
    }

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: const LatLng(28.543016, 77.193173), // LHC centroid
        initialZoom: 19.5,
        minZoom: 17,
        maxZoom: 22,
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      children: [
        // Dark tile base (optional — remove if offline)
        TileLayer(
          urlTemplate:
          'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}@2x.png',
          userAgentPackageName: 'com.example.ble_live_test',
          fallbackUrl:
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          errorTileCallback: (tile, e, st) {},
        ),
        // Floor polygons — background (non-walkable, boundary)
        PolygonLayer(polygons: bgPolygons),
        // Floor polygons — rooms, labs, washrooms, etc.
        PolygonLayer(polygons: midPolygons),
        // Floor polygons — walls, pillars (drawn on top so edges are crisp)
        PolygonLayer(polygons: topPolygons),
        // WKNN marker — orange, nearest zone snap
        if (widget.wknnX != null && widget.wknnY != null)
          MarkerLayer(
            markers: [
              Marker(
                point: localToGps(widget.wknnX!, widget.wknnY!),
                width: 52,
                height: 52,
                child: const _WKNNMarker(),
              ),
            ],
          ),
        // Gaussian marker — blue, exact continuous position
        MarkerLayer(
          markers: [
            Marker(
              point: markerPos,
              width: 48,
              height: 48,
              child: _PulsingDot(
                  accuracy: _accuracyRadius(
                      widget.predictedX, widget.predictedY)),
            ),
          ],
        ),
      ],
    );
  }

  /// Only label rooms/labs/reception — not walls or pillars.
  bool _shouldLabel(String type) =>
      {'room', 'Lab', 'Reception', 'Sitting Area'}.contains(type);

  /// Rough accuracy ring size based on distance to nearest beacon.
  double _accuracyRadius(double x, double y) {
    // Beacon local coords (from beacons.geojson)
    const beaconCoords = [
      [91.0, 336.0], [133.0, 290.0], [91.0, 295.0], [144.0, 304.0],
      [84.0, 324.0], [145.0, 319.0], [100.0, 287.0], [125.0, 345.0],
      [139.0, 336.0], [84.0, 307.0], [118.0, 283.0], [106.0, 346.0],
    ];
    double minD = double.infinity;
    for (final b in beaconCoords) {
      final d = sqrt(pow(x - b[0], 2) + pow(y - b[1], 2));
      if (d < minD) minD = d;
    }
    // Scale: ~1 local unit ≈ 0.3 m; clamp ring to 4–12 m
    return (minD * 0.3).clamp(4.0, 12.0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom info bar
// ─────────────────────────────────────────────────────────────────────────────
class _InfoBar extends StatelessWidget {
  final double x, y, confidence;
  final String zone;
  const _InfoBar({required this.x, required this.y,
    required this.confidence, required this.zone});

  @override
  Widget build(BuildContext context) {
    final gps = localToGps(x, y);
    return Container(
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (zone.isNotEmpty)
            Text(zone,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              _InfoChip(
                  icon: Icons.straighten,
                  label: 'X ${x.toStringAsFixed(1)} · Y ${y.toStringAsFixed(1)}'),
              const SizedBox(width: 8),
              _InfoChip(
                  icon: Icons.location_on_outlined,
                  label:
                  '${gps.latitude.toStringAsFixed(5)}, ${gps.longitude.toStringAsFixed(5)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.white54),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: Colors.white60, fontSize: 11, fontFamily: 'monospace')),
    ],
  );
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).toStringAsFixed(0);
    final color = confidence > 0.7
        ? Colors.greenAccent
        : confidence > 0.4
        ? Colors.amber
        : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text('$pct% conf',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WKNN marker — static orange diamond, nearest zone snap
// ─────────────────────────────────────────────────────────────────────────────
class _WKNNMarker extends StatelessWidget {
  const _WKNNMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ring
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF9800).withOpacity(0.15),
            border: Border.all(
                color: const Color(0xFFFF9800).withOpacity(0.5), width: 1.5),
          ),
        ),
        // Diamond core
        Transform.rotate(
          angle: 0.785, // 45 degrees
          child: Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9800).withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        // "W" label
        const Positioned(
          top: 4,
          child: Text('W',
              style: TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 9,
                  fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing marker with accuracy ring
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final double accuracy; // metres — used only for visual styling
  const _PulsingDot({this.accuracy = 5});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = 0.7 + 0.3 * _pulse.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer accuracy ring
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4FC3F7).withOpacity(0.15 * scale),
                border: Border.all(
                  color: const Color(0xFF4FC3F7).withOpacity(0.4 * scale),
                  width: 1.5,
                ),
              ),
            ),
            // Inner pulsing glow
            Container(
              width: 22 * scale,
              height: 22 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4FC3F7).withOpacity(0.25),
              ),
            ),
            // Core dot
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0288D1),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4FC3F7).withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}