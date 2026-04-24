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
        .select()
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

          // Guardamos el ID de tournament_teams
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
        .select()
        .eq('tournament_id', tournamentId);

    final tournamentTeams =
        List<Map<String, dynamic>>.from(tournamentTeamsResponse);

    final persistentTeamIds = tournamentTeams
        .map((team) => team['team_id'])
        .whereType<int>()
        .toSet()
        .toList();

    final persistentTeams = persistentTeamIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await SupabaseService.client
                .from('teams')
                .select('id, name, logo_url, code')
                .inFilter('id', persistentTeamIds),
          );

    Map<String, dynamic> getTournamentTeamById(dynamic id) {
      return tournamentTeams.firstWhere(
        (team) => team['id'] == id,
        orElse: () => <String, dynamic>{},
      );
    }

    Map<String, dynamic> getPersistentTeamById(dynamic id) {
      return persistentTeams.firstWhere(
        (team) => team['id'] == id,
        orElse: () => <String, dynamic>{},
      );
    }

    String getTeamName(Map<String, dynamic> tournamentTeam) {
      final teamId = tournamentTeam['team_id'];

      if (teamId != null) {
        final realTeam = getPersistentTeamById(teamId);
        final realName = realTeam['name']?.toString();

        if (realName != null && realName.trim().isNotEmpty) {
          return realName;
        }
      }

      final fallbackName = tournamentTeam['name']?.toString();

      if (fallbackName != null && fallbackName.trim().isNotEmpty) {
        return fallbackName;
      }

      return 'Equipo';
    }

    String? getTeamLogo(Map<String, dynamic> tournamentTeam) {
      final teamId = tournamentTeam['team_id'];

      if (teamId == null) return null;

      final realTeam = getPersistentTeamById(teamId);
      return realTeam['logo_url']?.toString();
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