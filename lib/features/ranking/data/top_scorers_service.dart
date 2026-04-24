import '../../../core/services/supabase_service.dart';

class TopScorersService {
  Future<List<Map<String, dynamic>>> getTopScorers(int tournamentId) async {
    final statsResponse = await SupabaseService.client
        .from('player_stats')
        .select()
        .eq('tournament_id', tournamentId);

    final stats = List<Map<String, dynamic>>.from(statsResponse);

    if (stats.isEmpty) return [];

    final userIds = stats.map((e) => e['user_id']).toList();

    final profiles = List<Map<String, dynamic>>.from(
      await SupabaseService.client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', userIds),
    );

    final scorers = stats.map((stat) {
      final profile = profiles.firstWhere(
        (p) => p['id'] == stat['user_id'],
        orElse: () => {},
      );

      return {
        'user_id': stat['user_id'],
        'name': profile['full_name'] ?? 'Jugador',
        'avatar': profile['avatar_url'],
        'goals': stat['goals'] ?? 0,
      };
    }).toList();

    scorers.sort((a, b) => (b['goals'] as int).compareTo(a['goals'] as int));

    return scorers;
  }
}