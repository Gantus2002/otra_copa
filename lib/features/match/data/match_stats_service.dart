import '../../../core/services/supabase_service.dart';

class MatchStatsService {
  Future<void> saveMatchStats({
    required int matchId,
    required int tournamentId,
    required int homeTeamId,
    required int awayTeamId,
    required int homeScore,
    required int awayScore,
    required String? mvpUserId,
    required List<Map<String, dynamic>> goals,
    required List<Map<String, dynamic>> playersStats,
  }) async {
    final tournament = await SupabaseService.client
        .from('tournaments')
        .select('is_official')
        .eq('id', tournamentId)
        .maybeSingle();

    final bool isOfficial = tournament?['is_official'] == true;

    // Limpia datos anteriores del mismo partido para evitar duplicados
    await SupabaseService.client
        .from('match_player_stats')
        .delete()
        .eq('match_id', matchId);

    await SupabaseService.client
        .from('match_goals')
        .delete()
        .eq('match_id', matchId);

    // Guarda goles detalle por detalle
    for (final goal in goals) {
      await SupabaseService.client.from('match_goals').insert({
        'match_id': matchId,
        'team_id': goal['team_id'],
        'player_id': goal['player_id'],
        'minute': goal['minute'],
      });
    }

    // Guarda resumen por jugador
    for (final player in playersStats) {
      await SupabaseService.client.from('match_player_stats').insert({
        'match_id': matchId,
        'user_id': player['user_id'],
        'goals': player['goals'],
        'is_mvp': player['is_mvp'],
      });
    }

    // Guarda resultado del partido
    await SupabaseService.client.from('matches').update({
      'home_score': homeScore,
      'away_score': awayScore,
      'status': 'finished',
      if (mvpUserId != null) 'mvp_user_id': mvpUserId,
    }).eq('id', matchId);

    // Si NO es oficial, no toca ranking oficial
    if (!isOfficial) return;

    // Actualiza player_stats oficial
    for (final player in playersStats) {
      final String userId = player['user_id'];
      final int playerGoals = player['goals'] ?? 0;
      final bool isMvp = player['is_mvp'] == true;

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
          'goals': playerGoals,
          'mvp': isMvp ? 1 : 0,
          'matches_played': 1,
        });
      } else {
        await SupabaseService.client
            .from('player_stats')
            .update({
              'goals': (existing['goals'] ?? 0) + playerGoals,
              'mvp': (existing['mvp'] ?? 0) + (isMvp ? 1 : 0),
              'matches_played': (existing['matches_played'] ?? 0) + 1,
            })
            .eq('id', existing['id']);
      }
    }
  }
}