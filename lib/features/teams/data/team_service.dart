import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/push_sender_service.dart';
import '../../../core/services/supabase_service.dart';

class TeamService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> _generateTeamCode(String name) async {
    final cleanName = name
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase()
        .padRight(3, 'X');

    final prefix = cleanName.substring(0, 3);
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();

    return '$prefix-${suffix.substring(suffix.length - 6)}';
  }

  Future<int> createTeam({
    required String name,
    required String city,
    required String country,
    String? logoUrl,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    final cleanName = name.trim();
    final code = await _generateTeamCode(cleanName);

    final team = await _client
        .from('teams')
        .insert({
          'name': cleanName,
          'city': city,
          'country': country,
          'code': code,
          'logo_url': logoUrl,
          'owner_id': user.id,
          'status': 'active',
        })
        .select()
        .single();

    final int teamId = team['id'] as int;

    await _client.from('team_members').insert({
      'team_id': teamId,
      'user_id': user.id,
      'role': 'owner',
      'status': 'active',
    });

    return teamId;
  }

  Future<void> updateTeam({
    required int teamId,
    required String name,
    required String city,
    required String country,
    String? logoUrl,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    final updated = await _client
        .from('teams')
        .update({
          'name': name.trim(),
          'city': city,
          'country': country,
          if (logoUrl != null) 'logo_url': logoUrl,
        })
        .eq('id', teamId)
        .eq('owner_id', user.id)
        .select();

    if (updated.isEmpty) {
      throw Exception('No se pudo editar el equipo. Solo el dueño puede editarlo.');
    }
  }

  Future<void> deleteTeam(int teamId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    final deleted = await _client
        .from('teams')
        .update({'status': 'archived'})
        .eq('id', teamId)
        .eq('owner_id', user.id)
        .select();

    if (deleted.isEmpty) {
      throw Exception('No se pudo archivar el equipo. Solo el dueño puede hacerlo.');
    }
  }

  Future<List<Map<String, dynamic>>> getMyTeams() async {
    final user = _client.auth.currentUser;

    if (user == null) return [];

    final response = await _client
        .from('team_members')
        .select('team_id, role, status, teams(*)')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .where((item) => item['teams'] != null)
        .where((item) {
          final team = Map<String, dynamic>.from(item['teams']);
          return (team['status'] ?? 'active') == 'active';
        })
        .map((item) {
          final team = Map<String, dynamic>.from(item['teams']);
          team['my_role'] = item['role'];
          return team;
        })
        .toList();
  }

  Future<Map<String, dynamic>?> getTeamById(int teamId) async {
    return await _client
        .from('teams')
        .select()
        .eq('id', teamId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(int teamId) async {
    final response = await _client
        .from('team_members')
        .select(
          'id, team_id, user_id, role, status, created_at, profiles(full_name, avatar_url, public_code)',
        )
        .eq('team_id', teamId)
        .eq('status', 'active')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<bool> _currentUserIsOwner(int teamId) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    final owner = await _client
        .from('team_members')
        .select('id')
        .eq('team_id', teamId)
        .eq('user_id', user.id)
        .eq('role', 'owner')
        .eq('status', 'active')
        .maybeSingle();

    return owner != null;
  }

  Future<void> updateMemberRole({
    required int teamId,
    required String userId,
    required String role,
  }) async {
    final isOwner = await _currentUserIsOwner(teamId);

    if (!isOwner) {
      throw Exception('Solo el dueño puede cambiar roles');
    }

    if (role != 'captain' && role != 'member') {
      throw Exception('Rol inválido');
    }

    await _client
        .from('team_members')
        .update({'role': role})
        .eq('team_id', teamId)
        .eq('user_id', userId)
        .neq('role', 'owner');
  }

  Future<void> removeMember({
    required int teamId,
    required String userId,
  }) async {
    final isOwner = await _currentUserIsOwner(teamId);

    if (!isOwner) {
      throw Exception('Solo el dueño puede eliminar miembros');
    }

    await _client
        .from('team_members')
        .update({'status': 'removed'})
        .eq('team_id', teamId)
        .eq('user_id', userId)
        .neq('role', 'owner');
  }

  Future<void> invitePlayer({
    required int teamId,
    required String invitedUserId,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    final team = await _client
        .from('teams')
        .select('id, name')
        .eq('id', teamId)
        .maybeSingle();

    if (team == null) {
      throw Exception('Equipo no encontrado');
    }

    final existingInvitation = await _client
        .from('team_invitations')
        .select('id, status')
        .eq('team_id', teamId)
        .eq('invited_user_id', invitedUserId)
        .maybeSingle();

    if (existingInvitation != null &&
        (existingInvitation['status'] ?? '').toString() == 'pending') {
      throw Exception('Ese jugador ya tiene una invitación pendiente');
    }

    final existingMember = await _client
        .from('team_members')
        .select('id, status')
        .eq('team_id', teamId)
        .eq('user_id', invitedUserId)
        .maybeSingle();

    if (existingMember != null &&
        (existingMember['status'] ?? '').toString() == 'active') {
      throw Exception('Ese jugador ya forma parte del equipo');
    }

    await _client.from('team_invitations').insert({
      'team_id': teamId,
      'invited_user_id': invitedUserId,
      'invited_by_user_id': user.id,
      'status': 'pending',
    });

    await PushSenderService.instance.send(
      userId: invitedUserId,
      title: 'Invitación a equipo ⚽',
      body: 'Te invitaron a unirte a ${team['name'] ?? 'un equipo'}',
      data: {
        'type': 'team_invitation',
        'teamId': teamId.toString(),
      },
    );
  }

  Future<void> inviteByCode({
    required int teamId,
    required String publicCode,
  }) async {
    final profile = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('public_code', publicCode.trim().toUpperCase())
        .maybeSingle();

    if (profile == null) {
      throw Exception('Jugador no encontrado');
    }

    await invitePlayer(
      teamId: teamId,
      invitedUserId: profile['id'] as String,
    );
  }

  Future<List<Map<String, dynamic>>> getMyPendingInvitations() async {
    final user = _client.auth.currentUser;

    if (user == null) return [];

    final invitations = await _client
        .from('team_invitations')
        .select(
          'id, team_id, invited_by_user_id, invited_user_id, status, created_at',
        )
        .eq('invited_user_id', user.id)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final invitationList = List<Map<String, dynamic>>.from(invitations);
    if (invitationList.isEmpty) return [];

    final teamIds = invitationList
        .map((e) => e['team_id'])
        .whereType<int>()
        .toSet()
        .toList();

    final inviterIds = invitationList
        .map((e) => e['invited_by_user_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final teams = teamIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('teams')
                .select('id, name, code, city, country, logo_url')
                .inFilter('id', teamIds),
          );

    final inviters = inviterIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _client
                .from('profiles')
                .select('id, full_name, avatar_url, public_code')
                .inFilter('id', inviterIds),
          );

    return invitationList.map((invitation) {
      final team = teams.firstWhere(
        (t) => t['id'] == invitation['team_id'],
        orElse: () => <String, dynamic>{},
      );

      final inviter = inviters.firstWhere(
        (p) => p['id'] == invitation['invited_by_user_id'],
        orElse: () => <String, dynamic>{},
      );

      return {
        ...invitation,
        'team_name': team['name'] ?? 'Equipo',
        'team_code': team['code'] ?? '',
        'team_city': team['city'] ?? '',
        'team_country': team['country'] ?? '',
        'team_logo_url': team['logo_url'],
        'inviter_name': inviter['full_name'] ?? 'Jugador',
        'invited_by_name': inviter['full_name'] ?? 'Jugador',
        'inviter_avatar_url': inviter['avatar_url'],
        'inviter_public_code': inviter['public_code'] ?? '',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getPendingInvitations() {
    return getMyPendingInvitations();
  }

  Future<void> acceptInvitation({
    required int invitationId,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    final invitation = await _client
        .from('team_invitations')
        .select('id, team_id, invited_by_user_id, invited_user_id, status')
        .eq('id', invitationId)
        .eq('invited_user_id', user.id)
        .maybeSingle();

    if (invitation == null) {
      throw Exception('Invitación no encontrada');
    }

    if ((invitation['status'] ?? '').toString() != 'pending') {
      throw Exception('La invitación ya no está pendiente');
    }

    final int teamId = invitation['team_id'] as int;
    final invitedByUserId = (invitation['invited_by_user_id'] ?? '').toString();

    final alreadyMember = await _client
        .from('team_members')
        .select('id, status')
        .eq('team_id', teamId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (alreadyMember == null) {
      await _client.from('team_members').insert({
        'team_id': teamId,
        'user_id': user.id,
        'role': 'member',
        'status': 'active',
      });
    } else {
      await _client
          .from('team_members')
          .update({
            'role': 'member',
            'status': 'active',
          })
          .eq('id', alreadyMember['id']);
    }

    await _client
        .from('team_invitations')
        .update({'status': 'accepted'})
        .eq('id', invitationId);

    if (invitedByUserId.isNotEmpty) {
      await PushSenderService.instance.send(
        userId: invitedByUserId,
        title: 'Invitación aceptada ✅',
        body: 'Un jugador aceptó tu invitación al equipo',
        data: {
          'type': 'team_invitation_accepted',
          'teamId': teamId.toString(),
        },
      );
    }
  }

  Future<void> rejectInvitation({
    required int invitationId,
  }) async {
    await _client
        .from('team_invitations')
        .update({'status': 'rejected'})
        .eq('id', invitationId);
  }

  Future<void> respondToInvitation({
    required int invitationId,
    String? status,
    bool? accept,
  }) async {
    final finalStatus = status ?? (accept == true ? 'accepted' : 'rejected');

    if (finalStatus == 'accepted') {
      await acceptInvitation(invitationId: invitationId);
      return;
    }

    if (finalStatus == 'rejected') {
      await rejectInvitation(invitationId: invitationId);
      return;
    }

    throw Exception('Estado de invitación inválido');
  }

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
      await SupabaseService.client.from('team_players').insert({
        'team_id': i.isEven ? teamAId : teamBId,
        'tournament_id': tournamentId,
        'player_name': shuffled[i],
      });
    }
  }

  Future<List<Map<String, dynamic>>> getTeamsWithPlayers(
    int tournamentId,
  ) async {
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
      team['players'] =
          players.where((player) => player['team_id'] == team['id']).toList();
    }

    return teams;
  }
}