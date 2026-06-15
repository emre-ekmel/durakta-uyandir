import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NominatimService {
  final http.Client _client = http.Client();

  Future<List<Map<String, dynamic>>> searchPlaces(String query, {double? lat, double? lon}) async {
    final Map<String, dynamic> params = {'q': query, 'limit': '5'};

    if (lat != null && lon != null) {
      params['lat'] = lat.toString();
      params['lon'] = lon.toString();
    }

    final uri = Uri.https('photon.komoot.io', '/api', params);

    debugPrint("[Search] Requesting: $uri");

    try {
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      debugPrint("[Search] Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'];

        return features.map((feature) {
          final properties = feature['properties'] as Map<String, dynamic>;
          final geometry = feature['geometry'] as Map<String, dynamic>;
          final coordinates = geometry['coordinates'] as List<dynamic>;

          final double longitude = (coordinates[0] as num).toDouble();
          final double latitude = (coordinates[1] as num).toDouble();

          final name = properties['name'] ?? '';
          final city = properties['city'] ?? properties['town'] ?? properties['village'] ?? '';
          final district = properties['district'] ?? '';

          final List<String> parts = [
            name.toString(),
            district.toString(),
            city.toString(),
          ].where((s) => s.isNotEmpty && s != "null").toList();

          final displayName = parts.join(', ');

          return {
            'lat': latitude.toString(),
            'lon': longitude.toString(),
            'display_name': displayName.isEmpty ? 'Bilinmeyen Konum' : displayName,
            'name': name.toString(),
          };
        }).toList();
      } else {
        debugPrint("[Search] API Error: ${response.reasonPhrase}");
        return [];
      }
    } catch (e) {
      debugPrint("[Search] Exception: $e");
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}
