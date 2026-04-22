import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class TeamService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  String _generateTeamCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();

    return 'TEAM-${List.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join()}';
  }

  Future<int> createTeam({
    required String name,
    required String city,
    required String country,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final code = _generateTeamCode();

    final inserted = await _client
        .from('teams')
        .insert({
          'name': name,
          'city': city,
          'country': country,
          'code': code,
          'owner_user_id': user.id,
        })
        .select()
        .single();

    final teamId = inserted['id'] as int;

    await _client.from('team_members').insert({
      'team_id': teamId,
      'user_id': user.id,
      'role': 'owner',
    });

    return teamId;
  }

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
      final match = membershipList.firstWhere(
        (m) => m['team_id'] == team['id'],
        orElse: () => {},
      );
      team['my_role'] = match['role'];
    }

    return teamsList;
  }

  Future<Map<String, dynamic>?> getTeamById(int teamId) async {
    final data = await _client
        .from('teams')
        .select()
        .eq('id', teamId)
        .maybeSingle();

    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(int teamId) async {
    final memberships = await _client
        .from('team_members')
        .select('user_id, role, joined_at')
        .eq('team_id', teamId)
        .order('joined_at', ascending: true);

    final membershipList = List<Map<String, dynamic>>.from(memberships);

    if (membershipList.isEmpty) return [];

    final userIds = membershipList
        .map((m) => m['user_id'])
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
        'joined_at': member['joined_at'],
        'full_name': profile['full_name'] ?? 'Jugador',
        'avatar_url': profile['avatar_url'],
        'public_code': profile['public_code'],
      };
    }).toList();
  }

  Future<void> invitePlayer({
    required int teamId,
    required String invitedUserId,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    if (invitedUserId == user.id) {
      throw Exception('No podés invitarte a vos mismo');
    }

    final existingMember = await _client
        .from('team_members')
        .select('id')
        .eq('team_id', teamId)
        .eq('user_id', invitedUserId)
        .maybeSingle();

    if (existingMember != null) {
      throw Exception('Ese jugador ya forma parte del equipo');
    }

    await _client.from('team_invitations').insert({
      'team_id': teamId,
      'invited_user_id': invitedUserId,
      'invited_by_user_id': user.id,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    final user = currentUser;
    if (user == null) return [];

    final invitations = await _client
        .from('team_invitations')
        .select()
        .eq('invited_user_id', user.id)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final invitationList = List<Map<String, dynamic>>.from(invitations);

    if (invitationList.isEmpty) return [];

    final teamIds = invitationList
        .map((e) => e['team_id'])
        .whereType<int>()
        .toList();

    final inviterIds = invitationList
        .map((e) => e['invited_by_user_id'])
        .whereType<String>()
        .toList();

    final teams = await _client
        .from('teams')
        .select('id, name, city, country, code')
        .inFilter('id', teamIds);

    final profiles = await _client
        .from('profiles')
        .select('id, full_name, avatar_url, public_code')
        .inFilter('id', inviterIds);

    final teamsList = List<Map<String, dynamic>>.from(teams);
    final profilesList = List<Map<String, dynamic>>.from(profiles);

    return invitationList.map((inv) {
      final team = teamsList.firstWhere(
        (t) => t['id'] == inv['team_id'],
        orElse: () => {},
      );

      final inviter = profilesList.firstWhere(
        (p) => p['id'] == inv['invited_by_user_id'],
        orElse: () => {},
      );

      return {
        ...inv,
        'team_name': team['name'] ?? 'Equipo',
        'team_code': team['code'] ?? '',
        'team_city': team['city'] ?? '',
        'team_country': team['country'] ?? '',
        'invited_by_name': inviter['full_name'] ?? 'Jugador',
        'invited_by_avatar': inviter['avatar_url'],
      };
    }).toList();
  }

  Future<void> respondToInvitation({
    required int invitationId,
    required int teamId,
    required bool accept,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    if (accept) {
      await _client.from('team_members').insert({
        'team_id': teamId,
        'user_id': user.id,
        'role': 'member',
      });
    }

    await _client
        .from('team_invitations')
        .update({
          'status': accept ? 'accepted' : 'rejected',
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', invitationId);
  }
}