import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert' show json;

class ZooMapPage extends StatefulWidget {
  const ZooMapPage({super.key});

  @override
  State<ZooMapPage> createState() => _ZooMapPageState();
}

class _ZooMapPageState extends State<ZooMapPage> {
  MapboxMap? _mapboxMap;
  bool _isStyleLoaded = false;
  bool _is3DEffectApplied = false;

  @override
  void dispose() {
    _mapboxMap = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delhi Zoo Map - 3D Water'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_is3DEffectApplied ? Icons.terrain : Icons.layers),
            onPressed: _toggle3DEffect,
            tooltip: _is3DEffectApplied ? 'Disable 3D' : 'Enable 3D',
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            key: const ValueKey("mapWidget"),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(77.248, 28.607)),
              zoom: 17.0,
              pitch: _is3DEffectApplied ? 45.0 : 0.0, // 3D pitch for better effect
            ),
            styleUri: 'http://192.168.221.134:8080/styles/zoo/style.json',
            textureView: true, // Better for 3D effects
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),

          if (!_isStyleLoaded)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map style...'),
                ],
              ),
            ),

          // Control panel
          Positioned(
            bottom: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _add3DWaterEffect,
                      child: const Text('Add 3D Water'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _addWaterAnimation,
                      child: const Text('Animate Water'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    debugPrint('Map created');
  }

  void _onStyleLoaded(StyleLoadedEventData data) {
    setState(() {
      _isStyleLoaded = true;
    });

    debugPrint('Style loaded');

    // Automatically add 3D effects after style loads
    Future.delayed(const Duration(milliseconds: 500), () {
      _add3DWaterEffect();
    });
  }

  void _toggle3DEffect() {
    setState(() {
      _is3DEffectApplied = !_is3DEffectApplied;
    });

    _mapboxMap?.setCamera(CameraOptions(
      center: Point(coordinates: Position(77.248, 28.607)),
      zoom: 17.0,
      pitch: _is3DEffectApplied ? 45.0 : 0.0,
      bearing: _is3DEffectApplied ? 15.0 : 0.0,
    ));
  }

  void _add3DWaterEffect() async {
    if (_mapboxMap == null) return;

    try {
      // Method 1: Add 3D extrusion to water bodies
      await _addWater3DExtrusion();

      // Method 2: Add water reflection effects
      await _addWaterReflectionEffect();

      debugPrint("3D water effects added successfully!");

    } catch (e) {
      debugPrint("Error adding 3D water effects: $e");
    }
  }

  Future<void> _addWater3DExtrusion() async {
    try {
      // Add a new layer for 3D water extrusion
      var water3DLayer = {
        "id": "ponds-3d",
        "type": "fill-extrusion",
        "source": "zoo",
        "source-layer": "zoo",
        "filter": ["==", ["get", "type"], "Water"],
        "paint": {
          "fill-extrusion-color": "#1e90ff",
          "fill-extrusion-height": 4, // Height of water "volume"
          "fill-extrusion-base": 0, // Base level (must be positive)
          "fill-extrusion-opacity": 0.7,
          "fill-extrusion-vertical-gradient": true
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(water3DLayer),
        LayerPosition(below: "pond-labels"),
      );

      // Add a dedicated 3D outline layer
      var water3DOutlineLayer = {
        "id": "ponds-3d-outline",
        "type": "line",
        "source": "zoo",
        "source-layer": "zoo",
        "filter": ["==", ["get", "type"], "Water"],
        "paint": {
          "line-color": "#0066cc",
          "line-width": [
            "interpolate",
            ["linear"],
            ["zoom"],
            15, 3,
            18, 5
          ],
          "line-opacity": 1.0
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(water3DOutlineLayer),
        LayerPosition(above: "ponds-3d"),
      );

    } catch (e) {
      debugPrint("Error adding water 3D extrusion: $e");
    }
  }

  Future<void> _addWaterReflectionEffect() async {
    try {
      // Add main bluish outline for water boundaries
      var waterOutlineLayer = {
        "id": "ponds-outline",
        "type": "line",
        "source": "zoo",
        "source-layer": "zoo",
        "filter": ["==", ["get", "type"], "Water"],
        "paint": {
          "line-color": "#0066cc",
          "line-width": [
            "interpolate",
            ["linear"],
            ["zoom"],
            15, 2,
            18, 4
          ],
          "line-opacity": 0.9
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(waterOutlineLayer),
        LayerPosition(below: "pond-labels"),
      );

      // Add a glow/highlight effect around water
      var waterGlowLayer = {
        "id": "ponds-glow",
        "type": "line",
        "source": "zoo",
        "source-layer": "zoo",
        "filter": ["==", ["get", "type"], "Water"],
        "paint": {
          "line-color": "#00bfff",
          "line-width": [
            "interpolate",
            ["linear"],
            ["zoom"],
            15, 4,
            18, 7
          ],
          "line-blur": 4,
          "line-opacity": 0.6
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(waterGlowLayer),
        LayerPosition(above: "ponds-outline"),
      );

      // Add ripple effect (animated)
      var waterRippleLayer = {
        "id": "ponds-ripple",
        "type": "circle",
        "source": "zoo",
        "source-layer": "zoo",
        "filter": ["==", ["get", "type"], "Water"],
        "paint": {
          "circle-radius": [
            "interpolate",
            ["linear"],
            ["zoom"],
            15, 3,
            18, 6
          ],
          "circle-color": "rgba(30, 144, 255, 0.1)",
          "circle-stroke-color": "#1e90ff",
          "circle-stroke-width": 2,
          "circle-stroke-opacity": 0.3
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(waterRippleLayer),
        LayerPosition(above: "ponds-3d"),
      );

    } catch (e) {
      debugPrint("Error adding water reflection effects: $e");
    }
  }

  void _addWaterAnimation() async {
    if (_mapboxMap == null) return;

    try {
      // Animate the water ripple effect
      var animatedRipple = {
        "circle-radius": [
          "interpolate",
          ["linear"],
          ["get", "animationPhase"], // You'd need to add this property to your data
          0, 5,
          1, 25
        ],
        "circle-opacity": [
          "interpolate",
          ["linear"],
          ["get", "animationPhase"],
          0, 0.8,
          1, 0.1
        ]
      };

      // Update the existing ripple layer
      await _mapboxMap?.style.setStyleLayerProperty(
        "ponds-ripple",
        "paint",
        json.encode({
          "circle-radius": [
            "interpolate",
            ["exponential", 2],
            ["zoom"],
            15, ["*", 2, ["sin", ["*", 6.28, ["get", "id", ["literal", 0]]]]],
            18, ["*", 4, ["sin", ["*", 6.28, ["get", "id", ["literal", 0]]]]]
          ],
          "circle-color": "rgba(30, 144, 255, 0.2)",
          "circle-stroke-color": "#1e90ff",
          "circle-stroke-width": 1
        }),
      );

      debugPrint("Water animation added!");

    } catch (e) {
      debugPrint("Error adding water animation: $e");
    }
  }
}