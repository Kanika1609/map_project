import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:convert' show json;
import 'dart:typed_data';

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
              pitch: _is3DEffectApplied ? 45.0 : 0.0,
            ),
            styleUri: 'http://10.206.234.134:8080/styles/zoo/style.json',
            textureView: true,
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
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _addGrassPatternEffect,
                      child: const Text('Add Grass Pattern'),
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

    // Load custom images first, then add effects and model
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _addCustomImages();
      _add3DWaterEffect();
      _addGrassPatternEffect();
      await _addTigerModel(); // 👈 this is the new line you add
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

  Future<void> _addCustomImages() async {
    if (_mapboxMap == null) return;
    try {
      // Load grass pattern image
      final ByteData grassData = await rootBundle.load('assets/grass_pattern.png');
      final Uint8List grassBytes = grassData.buffer.asUint8List();
      await _mapboxMap!.style.addStyleImage(
        'grass_pattern',
        1.0,
        MbxImage(width: 16, height: 16, data: grassBytes), // Adjust size as needed
        false,
        [],
        [],
        null,
      );

      // Load water pattern image
      final ByteData waterData = await rootBundle.load('assets/water_pattern.png');
      final Uint8List waterBytes = waterData.buffer.asUint8List();
      await _mapboxMap!.style.addStyleImage(
        'water_pattern',
        1.0,
        MbxImage(width: 16, height: 16, data: waterBytes), // Adjust size as needed
        false,
        [],
        [],
        null,
      );

      debugPrint('Custom images loaded successfully');
    } catch (e) {
      debugPrint('Error adding custom images: $e');
    }
  }

  void _add3DWaterEffect() async {
    if (_mapboxMap == null) return;

    try {
      // Method 1: Add water pattern fill layer
      await _addWaterPatternFill();

      // Method 2: Add 3D extrusion to water bodies
      await _addWater3DExtrusion();

      // Method 3: Add water reflection effects
      await _addWaterReflectionEffect();

      debugPrint("3D water effects added successfully!");

    } catch (e) {
      debugPrint("Error adding 3D water effects: $e");
    }
  }

  Future<void> _addTigerModel() async {
    if (_mapboxMap == null) return;

    const modelId = "tiger-model-layer";
    const sourceId = "tiger-model-source";

    try {
      // First, add the model source to the style
      final modelSource = {
        "type": "model",
        "models": {
          "tiger-model": {
            "uri": "https://maps.iwayplus.in/uploads/70tX7mpAIk9a-Wed Jul 09 2025 07:31:32 GMT+0000 (Coordinated Universal Time)-Tiger.glb",
            "position": [77.24657288531034, 28.605579652959833], // lon, lat
            "orientation": [0, 0, 0], // heading, pitch, roll in degrees
            "scale": [5.0, 5.0, 5.0], // Reduced scale for better visibility
          }
        }
      };

      await _mapboxMap!.style.addStyleSource(
        sourceId,
        json.encode(modelSource),
      );

      debugPrint("✅ Tiger model source added");

      // Wait a moment for the source to be registered
      await Future.delayed(const Duration(milliseconds: 500));

      // Then add the model layer
      await _mapboxMap!.style.addStyleLayer(
        json.encode({
          "id": modelId,
          "type": "model",
          "source": sourceId,
          "layout": {
            "visibility": "visible"
          },
          "paint": {
            "model-opacity": 1.0,
            "model-color": "#ffffff",
            "model-color-mix-intensity": 0.0
          }
        }),
        null,
      );

      debugPrint("✅ Tiger 3D model added successfully!");
    } catch (e) {
      debugPrint("❌ Error adding tiger model: $e");
    }
  }

  Future<void> _addWaterPatternFill() async {
    try {
      // Add a base fill layer with water pattern
      var waterPatternLayer = {
        "id": "water-pattern-fill",
        "type": "fill",
        "source": "zoo",
        "source-layer": "zoo",
        "filter": ["==", ["get", "type"], "Water"],
        "paint": {
          "fill-pattern": "water_pattern",
          "fill-opacity": 0.9
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(waterPatternLayer),
        null, // Add to the top initially
      );
      debugPrint('Water pattern layer added');

      // Add a semi-transparent overlay for depth effect
      var waterOverlayLayer = {
        "id": "water-overlay",
        "type": "fill",
        "source": "zoo",
        "source-layer": "zoo",
        "filter": ["==", ["get", "type"], "Water"],
        "paint": {
          "fill-color": "#1e90ff",
          "fill-opacity": 0.3
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(waterOverlayLayer),
        LayerPosition(above: "water-pattern-fill"),
      );
      debugPrint('Water overlay layer added');

    } catch (e) {
      debugPrint("Error adding water pattern fill: $e");
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
          "fill-extrusion-height": 4,
          "fill-extrusion-base": 0,
          "fill-extrusion-opacity": 0.7,
          "fill-extrusion-vertical-gradient": true
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(water3DLayer),
        LayerPosition(above: "water-overlay"),
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

      // Animate the water pattern by shifting it slightly
      await _mapboxMap?.style.setStyleLayerProperty(
        "water-pattern-fill",
        "paint",
        json.encode({
          "fill-pattern": "water_pattern",
          "fill-opacity": 0.8,
          "fill-translate": [
            "interpolate",
            ["linear"],
            ["zoom"],
            15, [1, 1],
            18, [2, 2]
          ],
          "fill-translate-anchor": "map"
        }),
      );

      debugPrint("Water animation added!");

    } catch (e) {
      debugPrint("Error adding water animation: $e");
    }
  }

  void _addGrassPatternEffect() async {
    if (_mapboxMap == null) return;

    try {
      // Add grass pattern for green areas
      var grassPatternLayer = {
        "id": "grass-pattern-fill",
        "type": "fill",
        "source": "zoo",
        "source-layer": "zoo",
        "filter": [
          "any",
          ["==", ["get", "type"], "Green Area"],
          ["==", ["get", "type"], "Field"]
        ],
        "paint": {
          "fill-pattern": "grass_pattern",
          "fill-opacity": 0.9
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(grassPatternLayer),
        null, // Add to the top initially
      );
      debugPrint('Grass pattern layer added');

      // Add a subtle green overlay for natural look
      var grassOverlayLayer = {
        "id": "grass-overlay",
        "type": "fill",
        "source": "zoo",
        "source-layer": "zoo",
        "filter": [
          "any",
          ["==", ["get", "type"], "Green Area"],
          ["==", ["get", "type"], "Field"]
        ],
        "paint": {
          "fill-color": "#228B22",
          "fill-opacity": 0.2
        }
      };

      await _mapboxMap?.style.addStyleLayer(
        json.encode(grassOverlayLayer),
        LayerPosition(above: "grass-pattern-fill"),
      );
      debugPrint('Grass overlay layer added');

      debugPrint("Grass pattern effects added successfully!");

    } catch (e) {

      debugPrint("Error adding grass pattern effects: $e");
    }
  }
}

