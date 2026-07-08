import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Renders a GLB "stuck" at a fixed GPS location by projecting that point
/// to screen coordinates every time the map camera moves, and resizing it
/// with zoom. Uses model_viewer_plus (a WebView), which renders through a
/// completely separate process from MapLibre's native GPU surface — this
/// avoids the Vulkan driver crash that the three_js approach hit on some
/// devices (two native GL/Vulkan contexts fighting over the same GPU).
///
/// Trade-off vs. the three_js approach: this chair does NOT rotate in true
/// 3D lockstep with map pitch/bearing — it resizes and repositions
/// correctly, but its own internal camera stays roughly fixed. For a
/// single static prop this still reads as "sitting in the room."
class ChairSticker extends StatefulWidget {
  final MapLibreMapController mapController;
  final LatLng chairAnchor;
  const ChairSticker({
    super.key,
    required this.mapController,
    required this.chairAnchor,
  });

  @override
  State<ChairSticker> createState() => ChairStickerState();
}

class ChairStickerState extends State<ChairSticker> {
  static const double _minZoomVisible = 17.0;
  static const double _baseSizePx = 26.0;

  Offset? _screenPos;
  double _scale = 1.0;
  bool _visible = false;

  /// Call this every time the MapLibre camera moves (pan/zoom/tilt/rotate).
  Future<void> syncToMapCamera(CameraPosition camera) async {
    if (camera.zoom < _minZoomVisible) {
      if (_visible && mounted) setState(() => _visible = false);
      return;
    }

    final screenPoint =
    await widget.mapController.toScreenLocation(widget.chairAnchor);

    // Grows as you zoom in, like a real object would.
    final zoomFactor =
    math.pow(2, camera.zoom - _minZoomVisible).toDouble();
    final newScale = zoomFactor.clamp(0.4, 1.8).toDouble();

    if (!mounted) return;
    setState(() {
      _screenPos = Offset(screenPoint.x.toDouble(), screenPoint.y.toDouble());
      _scale = newScale;
      _visible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _screenPos == null) {
      // Keep it a Positioned child of the Stack at all times (off-screen)
      // rather than swapping widget types, to avoid Stack layout churn.
      return const Positioned(
        left: -9999,
        top: -9999,
        child: SizedBox.shrink(),
      );
    }

    final size = _baseSizePx * _scale;
    return Positioned(
      left: _screenPos!.dx - size / 2,
      top: _screenPos!.dy - size, // anchor at the base, not the center
      width: size,
      height: size,
      child: IgnorePointer(
        child: ModelViewer(
          key: const ValueKey('chair-sticker-model'),
          // Adjust path/filename if yours differs. pubspec.yaml already
          // lists assets/models/Long_Chair.glb.
          src: 'assets/models/Long_Chair.glb',
          alt: 'Chair',
          ar: false,
          autoRotate: false,
          cameraControls: false,
          disableZoom: true,
          backgroundColor: Colors.transparent,
          // Rough angle approximating a tilted top-down view. Tune to
          // taste — this does NOT dynamically track map pitch/bearing.
          cameraOrbit: '0deg 60deg 4m',
          fieldOfView: '30deg',
        ),
      ),
    );
  }
}