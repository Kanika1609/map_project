// import 'package:flutter/material.dart' hide Theme;
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:vector_map_tiles/vector_map_tiles.dart';
// import 'package:vector_tile_renderer/vector_tile_renderer.dart';
//
// void main() {
//   runApp(const MaterialApp(home: VectorTileMap()));
// }
//
// class VectorTileMap extends StatefulWidget {
//   const VectorTileMap({super.key});
//
//   @override
//   State<VectorTileMap> createState() => _VectorTileMapState();
// }
//
// class _VectorTileMapState extends State<VectorTileMap> {
//   Theme? _theme;
//   final MapController _mapController = MapController();
//
//   @override
//   void initState() {
//     super.initState();
//     _loadStyle();
//   }
//
//   Future<void> _loadStyle() async {
//     try {
//       final style = await StyleReader(
//         uri: 'http://172.18.32.1:8080/styles/aiims/style.json',
//         logger: Logger.console(),
//       ).read();
//
//       setState(() {
//         _theme = style.theme;
//       });
//
//       debugPrint('Style loaded successfully');
//       debugPrint('Theme layers: ${_theme?.layers.length}');
//     } catch (e) {
//       debugPrint('Error loading style: $e');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_theme == null) {
//       return const Scaffold(
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(height: 16),
//               Text('Loading AIIMS Map...'),
//             ],
//           ),
//         ),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("AIIMS Jammu Vector Map"),
//         backgroundColor: Colors.blue.shade800,
//         foregroundColor: Colors.white,
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: LatLng(32.56497, 75.03575),
//               initialZoom: 17,
//               minZoom: 10,
//               maxZoom: 21,
//               onTap: (tapPosition, point) {
//                 debugPrint('Tapped at: ${point.latitude}, ${point.longitude}');
//               },
//             ),
//             children: [
//               VectorTileLayer(
//                 theme: _theme!,
//                 tileProviders: TileProviders({
//                   'combined_with_layers': NetworkVectorTileProvider(
//                     urlTemplate:
//                     'http://172.18.32.1:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
//                     maximumZoom: 21,
//                   ),
//                   'indooraiimsj': NetworkVectorTileProvider(
//                     urlTemplate:
//                     'http://172.18.32.1:8080/data/indooraiimsj/{z}/{x}/{y}.pbf',
//                     maximumZoom: 21,
//                   ),
//                 }),
//                 layerMode: VectorTileLayerMode.vector,
//               ),
//             ],
//           ),
//           // Informational label
//           Positioned(
//             top: 10,
//             right: 10,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               decoration: BoxDecoration(
//                 color: Colors.black87,
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.3),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: const Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.layers, color: Colors.white, size: 16),
//                   SizedBox(width: 6),
//                   Text(
//                     'All Floors Visible',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           _mapController.move(LatLng(32.56497, 75.03575), 17);
//         },
//         backgroundColor: Colors.blue.shade800,
//         child: const Icon(Icons.my_location, color: Colors.white),
//       ),
//     );
//   }
// }
//

// import 'package:flutter/material.dart' hide Theme;
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:vector_map_tiles/vector_map_tiles.dart';
// import 'package:vector_tile_renderer/vector_tile_renderer.dart';
//
// void main() {
//   runApp(const MaterialApp(home: VectorTileMap()));
// }
//
// class VectorTileMap extends StatefulWidget {
//   const VectorTileMap({super.key});
//
//   @override
//   State<VectorTileMap> createState() => _VectorTileMapState();
// }
//
// class _VectorTileMapState extends State<VectorTileMap> {
//   Theme? _theme;
//   final MapController _mapController = MapController();
//
//   bool _showIndoorOnly = false; // false = combined, true = indoor only
//
//   @override
//   void initState() {
//     super.initState();
//     _loadStyle();
//   }
//
//   Future<void> _loadStyle() async {
//     try {
//       final style = await StyleReader(
//         uri: 'http://172.18.32.1:8080/styles/aiims/style.json',
//         logger: Logger.console(),
//       ).read();
//
//       setState(() {
//         _theme = style.theme;
//       });
//
//       debugPrint('Style loaded successfully');
//       debugPrint('Theme layers: ${_theme?.layers.length}');
//     } catch (e) {
//       debugPrint('Error loading style: $e');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_theme == null) {
//       return const Scaffold(
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(height: 16),
//               Text('Loading AIIMS Map...'),
//             ],
//           ),
//         ),
//       );
//     }
//
//     // Only one tile provider at a time
//     final tileProviders = _showIndoorOnly
//         ? TileProviders({
//       'floor_6': NetworkVectorTileProvider(
//         urlTemplate:
//         'http://172.18.32.1:8080/data/floor_6/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//     })
//         : TileProviders({
//       'combined_with_layers': NetworkVectorTileProvider(
//         urlTemplate:
//         'http://172.18.32.1:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
//         maximumZoom: 21,
//       ),
//     });
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("AIIMS Jammu Vector Map"),
//         backgroundColor: Colors.blue.shade800,
//         foregroundColor: Colors.white,
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: LatLng(32.56497, 75.03575),
//               initialZoom: 17,
//               minZoom: 10,
//               maxZoom: 21,
//               onTap: (tapPosition, point) {
//                 debugPrint('Tapped at: ${point.latitude}, ${point.longitude}');
//               },
//             ),
//             children: [
//               VectorTileLayer(
//                 key: ValueKey(_showIndoorOnly), // Forces rebuild on toggle
//                 theme: _theme!,
//                 tileProviders: tileProviders,
//                 layerMode: VectorTileLayerMode.vector,
//               ),
//             ],
//           ),
//           // Informational label and toggle button
//           Positioned(
//             top: 10,
//             right: 10,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                   decoration: BoxDecoration(
//                     color: Colors.black87,
//                     borderRadius: BorderRadius.circular(20),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.3),
//                         blurRadius: 4,
//                         offset: const Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         _showIndoorOnly ? Icons.home : Icons.layers,
//                         color: Colors.white,
//                         size: 16,
//                       ),
//                       const SizedBox(width: 6),
//                       Text(
//                         _showIndoorOnly ? 'Indoor Only' : 'Combined Map',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 ElevatedButton.icon(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue.shade800,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(20),
//                     ),
//                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   ),
//                   icon: Icon(_showIndoorOnly ? Icons.layers : Icons.home),
//                   label: Text(_showIndoorOnly ? 'Show Combined' : 'Show Indoor Only'),
//                   onPressed: () {
//                     setState(() {
//                       _showIndoorOnly = !_showIndoorOnly;
//                     });
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           _mapController.move(LatLng(32.56497, 75.03575), 17);
//         },
//         backgroundColor: Colors.blue.shade800,
//         child: const Icon(Icons.my_location, color: Colors.white),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart' hide Theme;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

void main() {
  runApp(const MaterialApp(home: VectorTileMap()));
}

class VectorTileMap extends StatefulWidget {
  const VectorTileMap({super.key});

  @override
  State<VectorTileMap> createState() => _VectorTileMapState();
}

class _VectorTileMapState extends State<VectorTileMap> {
  Theme? _theme;
  final MapController _mapController = MapController();
  int _currentFloor = 0; // Track current floor (-1 to 6)

  // Floor options for the selector
  final List<int> _floors = [-1, 0, 1, 2, 3, 4, 5, 6];

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    try {
      final style = await StyleReader(
        uri: 'http://172.18.32.1:8080/styles/aiims/style.json',
        logger: Logger.console(),
      ).read();

      setState(() {
        _theme = style.theme;
      });

      debugPrint('Style loaded successfully');
      debugPrint('Theme layers: ${_theme?.layers.length}');
    } catch (e) {
      debugPrint('Error loading style: $e');
    }
  }

  TileProviders _getTileProviders() {
    return TileProviders({
      // Combined layers (always shown)
      'combined_with_layers': NetworkVectorTileProvider(
        urlTemplate: 'http://172.18.32.1:8080/data/combined_with_layers/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      // All floor layers
      'floor_-1': NetworkVectorTileProvider(
        urlTemplate: 'http://172.18.32.1:8080/data/floor_-1/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_0': NetworkVectorTileProvider(
        urlTemplate: 'http://172.18.32.1:8080/data/floor_0/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_1': NetworkVectorTileProvider(
        urlTemplate: 'http://172.18.32.1:8080/data/floor_1/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_2': NetworkVectorTileProvider(
        urlTemplate: 'http://172.18.32.1:8080/data/floor_2/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_3': NetworkVectorTileProvider(
        urlTemplate: 'http://172.18.32.1:8080/data/floor_3/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_4': NetworkVectorTileProvider(
        urlTemplate: 'http://172.18.32.1:8080/data/floor_4/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_5': NetworkVectorTileProvider(
        urlTemplate: 'http://172.18.32.1:8080/data/floor_5/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
      'floor_6': NetworkVectorTileProvider(
        urlTemplate: 'http://172.18.32.1:8080/data/floor_6/{z}/{x}/{y}.pbf',
        maximumZoom: 21,
      ),
    });
  }

  // Create a modified theme that only shows the selected floor
  Theme _getFilteredTheme() {
    if (_theme == null) return Theme(id: 'filtered', version: '8', layers: []);

    final filteredLayers = _theme!.layers.where((layer) {
      // Always show background and combined layers
      if (layer.id == 'background' ||
          layer.id.startsWith('combined_with_layers')) {
        return true;
      }

      // Show only layers for the current floor
      String floorSuffix;
      if (_currentFloor == -1) {
        floorSuffix = '_-1';
      } else {
        floorSuffix = '_' + _currentFloor.toString();
      }
      return layer.id.startsWith('floor' + floorSuffix);
    }).toList();

    return Theme(
      id: 'filtered',
      version: '8',
      layers: filteredLayers,
    );
  }

  String _getFloorDisplayName(int floor) {
    switch (floor) {
      case -1:
        return 'Basement';
      case 0:
        return 'Ground Floor';
      default:
        return 'Floor ' + floor.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_theme == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading AIIMS Map Style...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("AIIMS Jammu Indoor Map"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(32.56497, 75.03575),
              initialZoom: 17,
              minZoom: 10,
              maxZoom: 21,
              onTap: (tapPosition, point) {
                debugPrint('Tapped at: ${point.latitude}, ${point.longitude}');
              },
            ),
            children: [
              VectorTileLayer(
                key: Key('floor_' + _currentFloor.toString()),
                theme: _getFilteredTheme(),
                tileProviders: _getTileProviders(),
                layerMode: VectorTileLayerMode.vector,
              ),
            ],
          ),

          // Floor selector
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Current floor indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.layers,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getFloorDisplayName(_currentFloor),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Floor selector dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButton<int>(
                    value: _currentFloor,
                    icon: const Icon(Icons.arrow_drop_down),
                    elevation: 0,
                    underline: Container(),
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    items: _floors.map((floor) {
                      return DropdownMenuItem<int>(
                        value: floor,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              floor == -1 ? Icons.home_work : Icons.layers_outlined,
                              size: 16,
                              color: Colors.blue.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getFloorDisplayName(floor),
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (int? newFloor) {
                      if (newFloor != null) {
                        setState(() {
                          _currentFloor = newFloor;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Legend
          Positioned(
            bottom: 80,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
              ),
            ),
          ),
        ],
      ),

      // Reset position button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController.move(LatLng(32.56497, 75.03575), 17);
        },
        backgroundColor: Colors.blue.shade800,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.grey.shade400, width: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

