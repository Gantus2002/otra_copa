import 'package:supabase_flutter/supabase_flutter.dart';

class CourtsRemoteService {
  final SupabaseClient _client = Supabase.instance.client;

  String _normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  Future<List<Map<String, dynamic>>> getActiveVenues({
    String? city,
  }) async {
    final venuesResponse = await _client
        .from('venues')
        .select(
          'id, name, description, city, address, cover_image_url, whatsapp, phone, is_active',
        )
        .eq('is_active', true)
        .order('id', ascending: false);

    final allVenues = List<Map<String, dynamic>>.from(venuesResponse);

    List<Map<String, dynamic>> filteredVenues = allVenues;

    if (city != null && city.trim().isNotEmpty) {
      final normalizedCity = _normalize(city);

      filteredVenues = allVenues.where((venue) {
        final venueCity = _normalize((venue['city'] ?? '').toString());
        return venueCity == normalizedCity;
      }).toList();
    }

    if (filteredVenues.isEmpty) {
      return [];
    }

    final venueIds = filteredVenues.map((v) => v['id']).toList();

    final courtsResponse = await _client
        .from('courts')
        .select(
          'id, venue_id, name, sport_type, surface_type, description, price_per_hour, is_indoor, is_active',
        )
        .inFilter('venue_id', venueIds)
        .eq('is_active', true)
        .order('id', ascending: true);

    final courts = List<Map<String, dynamic>>.from(courtsResponse);

    return filteredVenues.map((venue) {
      final venueCourts = courts
          .where((court) => court['venue_id'] == venue['id'])
          .toList();

      final sportTypes = venueCourts
          .map((court) => (court['sport_type'] ?? '').toString().trim())
          .where((type) => type.isNotEmpty)
          .toSet()
          .toList();

      double? minPrice;

      for (final court in venueCourts) {
        final raw = court['price_per_hour'];

        if (raw is num) {
          final value = raw.toDouble();
          if (minPrice == null || value < minPrice) {
            minPrice = value;
          }
        }
      }

      return {
        ...venue,
        'courts': venueCourts,
        'sport_types': sportTypes,
        'courts_count': venueCourts.length,
        'min_price': minPrice,
      };
    }).toList();
  }
}