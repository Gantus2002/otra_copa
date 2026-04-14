import '../../../core/services/supabase_service.dart';

class FixtureService {
  Future<void> clearTournamentMatches(int tournamentId) async {
    await SupabaseService.client
        .from('matches')
        .delete()
        .eq('tournament_id', tournamentId);
  }

  Future<void> generateFixture(int tournamentId) async {
    final teamsResponse = await SupabaseService.client
        .from('tournament_teams')
        .select()
        .eq('tournament_id', tournamentId)
        .order('id');

    final teams = List<Map<String, dynamic>>.from(teamsResponse);

    if (teams.length < 2) {
      throw Exception('Se necesitan al menos 2 equipos para generar fixture');
    }

    await clearTournamentMatches(tournamentId);

    int round = 1;

    for (int i = 0; i < teams.length; i++) {
      for (int j = i + 1; j < teams.length; j++) {
        await SupabaseService.client.from('matches').insert({
          'tournament_id': tournamentId,
          'home_team_id': teams[i]['id'],
          'away_team_id': teams[j]['id'],
          'round_number': round,
          'status': 'scheduled',
        });

        round++;
      }
    }
  }

  Future<List<Map<String, dynamic>>> getMatchesWithTeams(int tournamentId) async {
    final matchesResponse = await SupabaseService.client
        .from('matches')
        .select()
        .eq('tournament_id', tournamentId)
        .order('round_number');

    final matches = List<Map<String, dynamic>>.from(matchesResponse);

    final teamsResponse = await SupabaseService.client
        .from('tournament_teams')
        .select()
        .eq('tournament_id', tournamentId);

    final teams = List<Map<String, dynamic>>.from(teamsResponse);

    for (final match in matches) {
      final homeTeam = teams.firstWhere(
        (team) => team['id'] == match['home_team_id'],
      );
      final awayTeam = teams.firstWhere(
        (team) => team['id'] == match['away_team_id'],
      );

      match['home_team_name'] = homeTeam['name'];
      match['away_team_name'] = awayTeam['name'];
    }

    return matches;
  }
}