import '../../../core/services/supabase_service.dart';

class FixtureService {
  Future<void> clearTournamentMatches(int tournamentId) async {
    await SupabaseService.client
        .from('matches')
        .delete()
        .eq('tournament_id', tournamentId);
  }

  Future<void> generateFixture(int tournamentId) async {
    final tournamentTeamsResponse = await SupabaseService.client
        .from('tournament_teams')
        .select('id, team_id, name')
        .eq('tournament_id', tournamentId)
        .order('id');

    final tournamentTeams =
        List<Map<String, dynamic>>.from(tournamentTeamsResponse);

    if (tournamentTeams.length < 2) {
      throw Exception('Se necesitan al menos 2 equipos aprobados');
    }

    await clearTournamentMatches(tournamentId);

    int round = 1;

    for (int i = 0; i < tournamentTeams.length; i++) {
      for (int j = i + 1; j < tournamentTeams.length; j++) {
        await SupabaseService.client.from('matches').insert({
          'tournament_id': tournamentId,
          'home_team_id': tournamentTeams[i]['id'],
          'away_team_id': tournamentTeams[j]['id'],
          'round_number': round,
          'status': 'scheduled',
          'home_score': 0,
          'away_score': 0,
        });

        round++;
      }
    }
  }

  Future<List<Map<String, dynamic>>> getMatchesWithTeams(
    int tournamentId,
  ) async {
    final matchesResponse = await SupabaseService.client
        .from('matches')
        .select()
        .eq('tournament_id', tournamentId)
        .order('round_number');

    final matches = List<Map<String, dynamic>>.from(matchesResponse);

    final tournamentTeamsResponse = await SupabaseService.client
        .from('tournament_teams')
        .select('*, teams(id, name, logo_url, code)')
        .eq('tournament_id', tournamentId);

    final tournamentTeams =
        List<Map<String, dynamic>>.from(tournamentTeamsResponse);

    Map<String, dynamic> getTournamentTeamById(dynamic id) {
      return tournamentTeams.firstWhere(
        (team) => team['id'] == id,
        orElse: () => <String, dynamic>{},
      );
    }

    String getTeamName(Map<String, dynamic> tournamentTeam) {
      final realTeam = tournamentTeam['teams'];

      if (realTeam is Map && realTeam['name'] != null) {
        final name = realTeam['name'].toString().trim();
        if (name.isNotEmpty) return name;
      }

      final fallback = tournamentTeam['name']?.toString().trim();

      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }

      return 'Equipo';
    }

    String? getTeamLogo(Map<String, dynamic> tournamentTeam) {
      final realTeam = tournamentTeam['teams'];

      if (realTeam is Map && realTeam['logo_url'] != null) {
        final url = realTeam['logo_url'].toString().trim();
        if (url.isNotEmpty) return url;
      }

      return null;
    }

    for (final match in matches) {
      final homeTournamentTeam = getTournamentTeamById(match['home_team_id']);
      final awayTournamentTeam = getTournamentTeamById(match['away_team_id']);

      match['home_team_name'] = getTeamName(homeTournamentTeam);
      match['away_team_name'] = getTeamName(awayTournamentTeam);

      match['home_team_logo_url'] = getTeamLogo(homeTournamentTeam);
      match['away_team_logo_url'] = getTeamLogo(awayTournamentTeam);
    }

    return matches;
  }
}