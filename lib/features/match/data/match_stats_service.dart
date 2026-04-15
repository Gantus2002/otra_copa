import '../../../core/services/supabase_service.dart';

class MatchStatsService {
  Future<void> saveMatchStats({
    required int matchId,
    required int tournamentId,
    required List<Map<String, dynamic>> playersStats,
  }) async {
    final tournament = await SupabaseService.client
        .from('tournaments')
        .select('is_official')
        .eq('id', tournamentId)
        .maybeSingle();

    final bool isOfficial = tournament?['is_official'] == true;

    for (final player in playersStats) {
      await SupabaseService.client.from('match_player_stats').insert({
        'match_id': matchId,
        'user_id': player['user_id'],
        'goals': player['goals'],
        'is_mvp': player['is_mvp'],
      });

      if (!isOfficial) {
        continue;
      }

      final existing = await SupabaseService.client
          .from('player_stats')
          .select()
          .eq('user_id', player['user_id'])
          .eq('tournament_id', tournamentId)
          .maybeSingle();

      if (existing == null) {
        await SupabaseService.client.from('player_stats').insert({
          'user_id': player['user_id'],
          'tournament_id': tournamentId,
          'goals': player['goals'],
          'mvp': player['is_mvp'] ? 1 : 0,
          'matches_played': 1,
        });
      } else {
        await SupabaseService.client
            .from('player_stats')
            .update({
              'goals': (existing['goals'] ?? 0) + player['goals'],
              'mvp': (existing['mvp'] ?? 0) + (player['is_mvp'] ? 1 : 0),
              'matches_played': (existing['matches_played'] ?? 0) + 1,
            })
            .eq('id', existing['id']);
      }
    }
  }
}