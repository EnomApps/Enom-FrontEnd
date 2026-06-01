import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// A single place suggestion returned by the backend's Google Places search.
/// The backend (`GET /api/places/search`) holds the Google API key and proxies
/// the request, so the app never embeds a Maps key of its own.
class PlaceSuggestion {
  PlaceSuggestion({
    required this.placeId,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  /// Human-friendly label: "Name, Address" (address omitted if empty/duplicate).
  String get label {
    if (address.isEmpty || address == name) return name;
    return '$name, $address';
  }

  factory PlaceSuggestion.fromJson(Map<String, dynamic> j) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return PlaceSuggestion(
      placeId: (j['place_id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      address: (j['address'] ?? '').toString(),
      latitude: toDouble(j['latitude']),
      longitude: toDouble(j['longitude']),
    );
  }
}

class PlacesService {
  /// Search places for location tagging via the backend Google Places proxy.
  /// [query] is the place name typed by the user. Optionally bias by [lat]/[lng].
  static Future<List<PlaceSuggestion>> search(
    String query, {
    double? lat,
    double? lng,
    int limit = 10,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    var endpoint = '/api/places/search?q=${Uri.encodeQueryComponent(q)}&limit=$limit';
    if (lat != null) endpoint += '&lat=$lat';
    if (lng != null) endpoint += '&lng=$lng';

    final result = await ApiService.get(endpoint, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    if (status == 200 && body is Map<String, dynamic>) {
      final data = body['data'] as List<dynamic>? ?? [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(PlaceSuggestion.fromJson)
          .where((p) => p.name.isNotEmpty)
          .toList();
    }

    debugPrint('[PlacesService.search] q="$q" status=$status');
    return [];
  }
}
