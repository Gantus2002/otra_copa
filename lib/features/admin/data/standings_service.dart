import '../../../core/services/supabase_service.dart';

class StandingsService {
  Future<List<Map<String, dynamic>>> getStandings(int tournamentId) async {
    final matchesResponse = await SupabaseService.client
        .from('matches')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('status', 'finished');

    final matches = List<Map<String, dynamic>>.from(matchesResponse);

    final tournamentTeamsResponse = await SupabaseService.client
        .from('tournament_teams')
        .select('*, teams(id, name, logo_url, code, city, country)')
        .eq('tournament_id', tournamentId)
        .order('id');

    final tournamentTeams =
        List<Map<String, dynamic>>.from(tournamentTeamsResponse);

    final Map<int, Map<String, dynamic>> table = {};

    for (final tournamentTeam in tournamentTeams) {
      final tournamentTeamId = tournamentTeam['id'] as int;
      final realTeam = tournamentTeam['teams'];

      String name = 'Equipo';
      String? logoUrl;
      String code = '';
      String city = '';
      String country = '';

      if (realTeam is Map) {
        name = (realTeam['name'] ?? 'Equipo').toString();
        logoUrl = realTeam['logo_url']?.toString();
        code = (realTeam['code'] ?? '').toString();
        city = (realTeam['city'] ?? '').toString();
        country = (realTeam['country'] ?? '').toString();
      } else {
        name = (tournamentTeam['name'] ?? 'Equipo').toString();
      }

      table[tournamentTeamId] = {
        'tournament_team_id': tournamentTeamId,
        'team_id': tournamentTeam['team_id'],
        'name': name,
        'logo_url': logoUrl,
        'code': code,
        'city': city,
        'country': country,
        'pj': 0,
        'pg': 0,
        'pe': 0,
        'pp': 0,
        'gf': 0,
        'gc': 0,
        'dg': 0,
        'pts': 0,
      };
    }

    for (final match in matches) {
      final homeId = match['home_team_id'];
      final awayId = match['away_team_id'];

      if (!table.containsKey(homeId) || !table.containsKey(awayId)) {
        continue;
      }

      final homeScore = (match['home_score'] ?? 0) as int;
      final awayScore = (match['away_score'] ?? 0) as int;

      final home = table[homeId]!;
      final away = table[awayId]!;

      home['pj'] += 1;
      away['pj'] += 1;

      home['gf'] += homeScore;
      home['gc'] += awayScore;

      away['gf'] += awayScore;
      away['gc'] += homeScore;

      if (homeScore > awayScore) {
        home['pg'] += 1;
        home['pts'] += 3;
        away['pp'] += 1;
      } else if (homeScore < awayScore) {
        away['pg'] += 1;
        away['pts'] += 3;
        home['pp'] += 1;
      } else {
        home['pe'] += 1;
        away['pe'] += 1;
        home['pts'] += 1;
        away['pts'] += 1;
      }
    }

    final standings = table.values.map((team) {
      team['dg'] = team['gf'] - team['gc'];
      return team;
    }).toList();

    standings.sort((a, b) {
      final ptsCompare = (b['pts'] as int).compareTo(a['pts'] as int);
      if (ptsCompare != 0) return ptsCompare;

      final dgCompare = (b['dg'] as int).compareTo(a['dg'] as int);
      if (dgCompare != 0) return dgCompare;

      final gfCompare = (b['gf'] as int).compareTo(a['gf'] as int);
      if (gfCompare != 0) return gfCompare;

      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return standings;
  }
}