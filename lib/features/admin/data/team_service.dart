import '../../../core/services/supabase_service.dart';

class TeamService {
  Future<void> clearTournamentTeams(int tournamentId) async {
    final teams = await SupabaseService.client
        .from('tournament_teams')
        .select('id')
        .eq('tournament_id', tournamentId);

    final teamIds = List<Map<String, dynamic>>.from(teams)
        .map((team) => team['id'] as int)
        .toList();

    if (teamIds.isNotEmpty) {
      await SupabaseService.client
          .from('team_players')
          .delete()
          .inFilter('team_id', teamIds);
    }

    await SupabaseService.client
        .from('tournament_teams')
        .delete()
        .eq('tournament_id', tournamentId);
  }

  Future<void> generateTeams({
    required int tournamentId,
    required List<String> playerNames,
  }) async {
    if (playerNames.length < 2) {
      throw Exception('Se necesitan al menos 2 jugadores');
    }

    await clearTournamentTeams(tournamentId);

    final shuffled = List<String>.from(playerNames)..shuffle();

    final firstTeamResponse = await SupabaseService.client
        .from('tournament_teams')
        .insert({
          'tournament_id': tournamentId,
          'name': 'Equipo A',
        })
        .select()
        .single();

    final secondTeamResponse = await SupabaseService.client
        .from('tournament_teams')
        .insert({
          'tournament_id': tournamentId,
          'name': 'Equipo B',
        })
        .select()
        .single();

    final int teamAId = firstTeamResponse['id'];
    final int teamBId = secondTeamResponse['id'];

    for (int i = 0; i < shuffled.length; i++) {
      final bool goesToA = i.isEven;

      await SupabaseService.client.from('team_players').insert({
        'team_id': goesToA ? teamAId : teamBId,
        'tournament_id': tournamentId,
        'player_name': shuffled[i],
      });
    }
  }

  Future<List<Map<String, dynamic>>> getTeamsWithPlayers(int tournamentId) async {
    final teamsResponse = await SupabaseService.client
        .from('tournament_teams')
        .select()
        .eq('tournament_id', tournamentId)
        .order('id');

    final teams = List<Map<String, dynamic>>.from(teamsResponse);

    final playersResponse = await SupabaseService.client
        .from('team_players')
        .select()
        .eq('tournament_id', tournamentId)
        .order('id');

    final players = List<Map<String, dynamic>>.from(playersResponse);

    for (final team in teams) {
      team['players'] = players
          .where((player) => player['team_id'] == team['id'])
          .toList();
    }

    return teams;
  }
}