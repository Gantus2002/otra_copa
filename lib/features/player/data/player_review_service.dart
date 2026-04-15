import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class PlayerReviewService {
  Future<void> saveReview({
    required int tournamentId,
    required String reviewedUserId,
    required int punctuality,
    required int behavior,
    required int commitment,
    required String comment,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario logueado');
    }

    await SupabaseService.client.from('player_reviews').insert({
      'tournament_id': tournamentId,
      'reviewed_user_id': reviewedUserId,
      'reviewer_user_id': user.id,
      'punctuality': punctuality,
      'behavior': behavior,
      'commitment': commitment,
      'comment': comment,
    });
  }

  Future<List<Map<String, dynamic>>> getReviewsForUser(String userId) async {
    final response = await SupabaseService.client
        .from('player_reviews')
        .select()
        .eq('reviewed_user_id', userId)
        .order('id', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}