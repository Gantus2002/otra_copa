import '../../../core/services/supabase_service.dart';

class PlayerStatsService {
  Future<void> addMatchStats({
    required String userId,
    required int tournamentId,
    required int goals,
    required bool isMvp,
  }) async {
    final existing = await SupabaseService.client
        .from('player_stats')
        .select()
        .eq('user_id', userId)
        .eq('tournament_id', tournamentId)
        .maybeSingle();

    if (existing == null) {
      await SupabaseService.client.from('player_stats').insert({
        'user_id': userId,
        'tournament_id': tournamentId,
        'goals': goals,
        'mvp': isMvp ? 1 : 0,
        'matches_played': 1,
      });
    } else {
      await SupabaseService.client
          .from('player_stats')
          .update({
            'goals': (existing['goals'] ?? 0) + goals,
            'mvp': (existing['mvp'] ?? 0) + (isMvp ? 1 : 0),
            'matches_played': (existing['matches_played'] ?? 0) + 1,
          })
          .eq('id', existing['id']);
    }
  }

  Future<List<Map<String, dynamic>>> getPlayerStatsWithTournamentNames(
    String userId,
  ) async {
    final statsResponse = await SupabaseService.client
        .from('player_stats')
        .select()
        .eq('user_id', userId);

    final stats = List<Map<String, dynamic>>.from(statsResponse);

    final tournamentsResponse = await SupabaseService.client
        .from('tournaments')
        .select('id, name');

    final tournaments = List<Map<String, dynamic>>.from(tournamentsResponse);

    for (final stat in stats) {
      final tournament = tournaments.firstWhere(
        (t) => t['id'] == stat['tournament_id'],
        orElse: () => {'name': 'Torneo'},
      );

      stat['tournament_name'] = tournament['name'];
    }

    return stats;
  }
}