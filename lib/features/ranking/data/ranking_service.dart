import '../../../core/services/supabase_service.dart';

class RankingService {
  Future<List<Map<String, dynamic>>> getTournamentPlayerRanking(
    int tournamentId,
  ) async {
    final statsResponse = await SupabaseService.client
        .from('player_stats')
        .select()
        .eq('tournament_id', tournamentId);

    final stats = List<Map<String, dynamic>>.from(statsResponse);

    if (stats.isEmpty) return [];

    final userIds = stats
        .map((e) => e['user_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final profiles = userIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await SupabaseService.client
                .from('profiles')
                .select('id, full_name, avatar_url, public_code, city')
                .inFilter('id', userIds),
          );

    final ranking = stats.map((stat) {
      final profile = profiles.firstWhere(
        (p) => p['id'] == stat['user_id'],
        orElse: () => <String, dynamic>{},
      );

      final goals = (stat['goals'] ?? 0) as int;
      final mvp = (stat['mvp'] ?? 0) as int;
      final matches = (stat['matches_played'] ?? 0) as int;

      final score = (goals * 4) + (mvp * 6) + (matches * 2);

      return {
        'user_id': stat['user_id'],
        'full_name': profile['full_name'] ?? 'Jugador',
        'avatar_url': profile['avatar_url'],
        'public_code': profile['public_code'] ?? '',
        'city': profile['city'] ?? '',
        'goals': goals,
        'mvp': mvp,
        'matches_played': matches,
        'score': score,
      };
    }).toList();

    ranking.sort((a, b) {
      final scoreCompare = (b['score'] as int).compareTo(a['score'] as int);
      if (scoreCompare != 0) return scoreCompare;

      final goalsCompare = (b['goals'] as int).compareTo(a['goals'] as int);
      if (goalsCompare != 0) return goalsCompare;

      return (b['mvp'] as int).compareTo(a['mvp'] as int);
    });

    return ranking;
  }

  Future<List<Map<String, dynamic>>> getLocalPlayerRanking(String city) async {
    final profiles = List<Map<String, dynamic>>.from(
      await SupabaseService.client
          .from('profiles')
          .select('id, full_name, avatar_url, public_code, city')
          .eq('city', city),
    );

    if (profiles.isEmpty) return [];

    final userIds = profiles
        .map((e) => e['id'])
        .whereType<String>()
        .toSet()
        .toList();

    final stats = userIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await SupabaseService.client
                .from('player_stats')
                .select()
                .inFilter('user_id', userIds),
          );

    final ranking = profiles.map((profile) {
      final userStats =
          stats.where((s) => s['user_id'] == profile['id']).toList();

      int goals = 0;
      int mvp = 0;
      int matches = 0;

      for (final stat in userStats) {
        goals += (stat['goals'] ?? 0) as int;
        mvp += (stat['mvp'] ?? 0) as int;
        matches += (stat['matches_played'] ?? 0) as int;
      }

      final score = (goals * 4) + (mvp * 6) + (matches * 2);

      return {
        'user_id': profile['id'],
        'full_name': profile['full_name'] ?? 'Jugador',
        'avatar_url': profile['avatar_url'],
        'public_code': profile['public_code'] ?? '',
        'city': profile['city'] ?? city,
        'goals': goals,
        'mvp': mvp,
        'matches_played': matches,
        'score': score,
      };
    }).toList();

    ranking.sort((a, b) {
      final scoreCompare = (b['score'] as int).compareTo(a['score'] as int);
      if (scoreCompare != 0) return scoreCompare;

      final goalsCompare = (b['goals'] as int).compareTo(a['goals'] as int);
      if (goalsCompare != 0) return goalsCompare;

      return (b['mvp'] as int).compareTo(a['mvp'] as int);
    });

    return ranking;
  }
}