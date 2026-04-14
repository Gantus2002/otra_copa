import '../../../core/services/supabase_service.dart';

class JoinRequestService {
  Future<void> createRequest({
    required int tournamentId,
    required String playerName,
    required String userId,
  }) async {
    await SupabaseService.client.from('join_requests').insert({
      'tournament_id': tournamentId,
      'player_name': playerName,
      'user_id': userId,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(int tournamentId) async {
    final response = await SupabaseService.client
        .from('join_requests')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateStatus(int id, String status) async {
    await SupabaseService.client
        .from('join_requests')
        .update({'status': status})
        .eq('id', id);
  }
}