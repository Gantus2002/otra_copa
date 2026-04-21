import 'package:supabase_flutter/supabase_flutter.dart';

class VenueReviewService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getTopReviews(int venueId) async {
    final data = await _client
        .from('venue_reviews')
        .select('id, venue_id, user_id, rating, comment, likes_count, created_at')
        .eq('venue_id', venueId)
        .order('likes_count', ascending: false)
        .order('created_at', ascending: false)
        .limit(3);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getAllReviews(int venueId) async {
    final data = await _client
        .from('venue_reviews')
        .select('id, venue_id, user_id, rating, comment, likes_count, created_at')
        .eq('venue_id', venueId)
        .order('likes_count', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> getStats(int venueId) async {
    final data = await _client
        .from('venue_reviews')
        .select('rating')
        .eq('venue_id', venueId);

    final rows = List<Map<String, dynamic>>.from(data);

    if (rows.isEmpty) {
      return {
        'avg': 0.0,
        'count': 0,
      };
    }

    double total = 0;

    for (final row in rows) {
      total += (row['rating'] as num).toDouble();
    }

    return {
      'avg': total / rows.length,
      'count': rows.length,
    };
  }

  Future<Map<int, Map<String, dynamic>>> getStatsForVenueIds(
    List<int> venueIds,
  ) async {
    if (venueIds.isEmpty) return {};

    final data = await _client
        .from('venue_reviews')
        .select('venue_id, rating')
        .inFilter('venue_id', venueIds);

    final rows = List<Map<String, dynamic>>.from(data);
    final Map<int, List<double>> grouped = {};

    for (final row in rows) {
      final venueId = row['venue_id'];
      final rating = row['rating'];

      if (venueId is! int || rating == null) continue;

      grouped.putIfAbsent(venueId, () => []);
      grouped[venueId]!.add((rating as num).toDouble());
    }

    final Map<int, Map<String, dynamic>> result = {};

    for (final id in venueIds) {
      final ratings = grouped[id] ?? [];
      if (ratings.isEmpty) {
        result[id] = {
          'avg': 0.0,
          'count': 0,
        };
      } else {
        final total = ratings.fold<double>(0, (sum, item) => sum + item);
        result[id] = {
          'avg': total / ratings.length,
          'count': ratings.length,
        };
      }
    }

    return result;
  }

  Future<bool> hasUserReviewed(int venueId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final data = await _client
        .from('venue_reviews')
        .select('id')
        .eq('venue_id', venueId)
        .eq('user_id', user.id)
        .maybeSingle();

    return data != null;
  }

  Future<void> createReview({
    required int venueId,
    required int rating,
    required String comment,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    await _client.from('venue_reviews').insert({
      'venue_id': venueId,
      'user_id': user.id,
      'rating': rating,
      'comment': comment,
    });
  }

  Future<void> likeReview(int reviewId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    await _client.from('venue_review_likes').insert({
      'review_id': reviewId,
      'user_id': user.id,
    });

    await _client.rpc(
      'increment_review_likes',
      params: {
        'review_id': reviewId,
      },
    );
  }
}