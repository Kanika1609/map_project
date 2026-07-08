import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rni_project_app/app_config.dart';
import 'package:rni_project_app/models/building.dart';

class ApiService {
  static Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  static Future<List<Building>> fetchBuildings() async {
    final url = "${AppConfig.baseUrl}/secured/building/all?api_key=${AppConfig.apiKey}";
    final response = await http.post(Uri.parse(url), headers: _jsonHeaders);

    if (response.statusCode != 200) {
      throw Exception('Failed to load buildings (${response.statusCode})');
    }

    final decoded = json.decode(response.body);
    print('RAW BUILDING LIST RESPONSE: $decoded');

    List<dynamic> rawList;
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawList = (decoded['data'] ?? decoded['buildings'] ?? decoded['result'] ?? decoded['venues'] ?? []) as List<dynamic>;
    } else {
      rawList = [];
    }

    return rawList.whereType<Map<String, dynamic>>().map((e) => Building.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> fetchGeoJson(String venueName) async {
    final url = "${AppConfig.baseUrl}/secured/get-indoor-geojson-venue/$venueName?api_key=${AppConfig.apiKey}";
    print('Fetching geoJson for venueName: $venueName');

    final response = await http.get(Uri.parse(url), headers: _jsonHeaders);

    if (response.statusCode != 200) {
      print('Failed to load GeoJSON for $venueName (${response.statusCode})');
      throw Exception('Failed to load GeoJSON for $venueName (${response.statusCode})');
    } else {
      print("GEOJSON data ${response.statusCode} ${response.body}");
    }

    final preview = response.body.length > 800 ? response.body.substring(0, 800) : response.body;
    print('RAW GEOJSON RESPONSE (first 800 chars): $preview');

    final decoded = json.decode(response.body);

    if (decoded is Map<String, dynamic>) {
      if (decoded['features'] is List) return decoded;
      for (final key in ['data', 'geojson', 'result', 'venue']) {
        final inner = decoded[key];
        if (inner is List) return {'type': 'FeatureCollection', 'features': inner};
        if (inner is Map<String, dynamic> && inner['features'] is List) return inner;
      }
      return decoded;
    } else if (decoded is List) {
      return {'type': 'FeatureCollection', 'features': decoded};
    }

    return {'type': 'FeatureCollection', 'features': []};
  }

  static Future<List<dynamic>> fetchBeaconsRaw(String venueName) async {
    final url = "${AppConfig.baseUrl}/secured/venue/beacons?api_key=${AppConfig.apiKey}";
    final response = await http.post(Uri.parse(url), headers: _jsonHeaders, body: json.encode({"venueName": venueName}));

    if (response.statusCode != 200) {
      throw Exception('Failed to load beacons for $venueName (${response.statusCode})');
    }

    final decoded = json.decode(response.body);
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      return (decoded['data'] ?? decoded['beacons'] ?? decoded['result'] ?? []) as List<dynamic>;
    }
    return [];
  }
}