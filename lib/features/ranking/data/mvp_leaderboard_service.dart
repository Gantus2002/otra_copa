import '../../../core/services/supabase_service.dart';

class MvpLeaderboardService {
  Future<List<Map<String, dynamic>>> getMvpLeaderboard(int tournamentId) async {
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
                .select('id, full_name, avatar_url, public_code')
                .inFilter('id', userIds),
          );

    final ranking = stats.map((stat) {
      final profile = profiles.firstWhere(
        (p) => p['id'] == stat['user_id'],
        orElse: () => <String, dynamic>{},
      );

      return {
        'user_id': stat['user_id'],
        'name': profile['full_name'] ?? 'Jugador',
        'avatar_url': profile['avatar_url'],
        'public_code': profile['public_code'] ?? '',
        'mvp': stat['mvp'] ?? 0,
        'goals': stat['goals'] ?? 0,
        'matches_played': stat['matches_played'] ?? 0,
      };
    }).toList();

    ranking.sort((a, b) {
      final mvpCompare = (b['mvp'] as int).compareTo(a['mvp'] as int);
      if (mvpCompare != 0) return mvpCompare;

      return (b['goals'] as int).compareTo(a['goals'] as int);
    });

    return ranking;
  }
}