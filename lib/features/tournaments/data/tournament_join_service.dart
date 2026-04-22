import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentJoinService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Future<List<Map<String, dynamic>>> getMyTeams() async {
    final user = currentUser;
    if (user == null) return [];

    final memberships = await _client
        .from('team_members')
        .select('team_id, role')
        .eq('user_id', user.id);

    final membershipList = List<Map<String, dynamic>>.from(memberships);

    if (membershipList.isEmpty) return [];

    final teamIds = membershipList
        .map((e) => e['team_id'])
        .whereType<int>()
        .toList();

    final teams = await _client
        .from('teams')
        .select()
        .inFilter('id', teamIds)
        .order('created_at', ascending: false);

    final teamsList = List<Map<String, dynamic>>.from(teams);

    for (final team in teamsList) {
      final membership = membershipList.firstWhere(
        (m) => m['team_id'] == team['id'],
        orElse: () => {},
      );
      team['my_role'] = membership['role'];
    }

    return teamsList;
  }

  Future<void> createPlayerJoinRequest({
    required int tournamentId,
    required String playerName,
    required String userId,
    double? entryFee,
  }) async {
    await _client.from('join_requests').insert({
      'tournament_id': tournamentId,
      'player_name': playerName,
      'user_id': userId,
      'requested_by_user_id': userId,
      'request_type': 'player',
      'entry_fee_snapshot': entryFee,
      'players_count_snapshot': 1,
    });
  }

  Future<void> createTeamJoinRequest({
    required int tournamentId,
    required int teamId,
    required String teamName,
    required String requestedByUserId,
    double? entryFee,
    int playersCount = 0,
  }) async {
    await _client.from('join_requests').insert({
      'tournament_id': tournamentId,
      'player_name': teamName,
      'user_id': requestedByUserId,
      'requested_by_user_id': requestedByUserId,
      'request_type': 'team',
      'team_id': teamId,
      'team_name_snapshot': teamName,
      'entry_fee_snapshot': entryFee,
      'players_count_snapshot': playersCount,
    });
  }

  Future<bool> hasPendingPlayerRequest({
    required int tournamentId,
    required String userId,
  }) async {
    final data = await _client
        .from('join_requests')
        .select('id')
        .eq('tournament_id', tournamentId)
        .eq('request_type', 'player')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .maybeSingle();

    return data != null;
  }

  Future<bool> hasPendingTeamRequest({
    required int tournamentId,
    required int teamId,
  }) async {
    final data = await _client
        .from('join_requests')
        .select('id')
        .eq('tournament_id', tournamentId)
        .eq('request_type', 'team')
        .eq('team_id', teamId)
        .eq('status', 'pending')
        .maybeSingle();

    return data != null;
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(int teamId) async {
    final memberships = await _client
        .from('team_members')
        .select('user_id, role')
        .eq('team_id', teamId);

    final membershipList = List<Map<String, dynamic>>.from(memberships);

    if (membershipList.isEmpty) return [];

    final userIds = membershipList
        .map((e) => e['user_id'])
        .whereType<String>()
        .toList();

    final profiles = await _client
        .from('profiles')
        .select('id, full_name, avatar_url, public_code')
        .inFilter('id', userIds);

    final profileList = List<Map<String, dynamic>>.from(profiles);

    return membershipList.map((member) {
      final profile = profileList.firstWhere(
        (p) => p['id'] == member['user_id'],
        orElse: () => {},
      );

      return {
        'user_id': member['user_id'],
        'role': member['role'],
        'full_name': profile['full_name'] ?? 'Jugador',
        'avatar_url': profile['avatar_url'],
        'public_code': profile['public_code'],
      };
    }).toList();
  }
}