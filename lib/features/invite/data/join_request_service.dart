import '../../../core/services/supabase_service.dart';

class JoinRequestService {
  // 🔹 COMPATIBILIDAD (para código viejo)
  Future<void> createRequest({
    required int tournamentId,
    required String playerName,
    required String userId,
  }) async {
    await createPlayerRequest(
      tournamentId: tournamentId,
      playerName: playerName,
      userId: userId,
    );
  }

  // 🔹 INSCRIPCIÓN INDIVIDUAL
  Future<void> createPlayerRequest({
    required int tournamentId,
    required String playerName,
    required String userId,
  }) async {
    final existing = await SupabaseService.client
        .from('join_requests')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Ya enviaste una solicitud para este torneo');
    }

    await SupabaseService.client.from('join_requests').insert({
      'tournament_id': tournamentId,
      'player_name': playerName,
      'user_id': userId,
      'status': 'pending',
      'type': 'player',
    });
  }

  // 🔥 INSCRIPCIÓN DE EQUIPO
  Future<void> createTeamRequest({
    required int tournamentId,
    required int teamId,
    required String userId,
  }) async {
    final existing = await SupabaseService.client
        .from('tournament_team_requests')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('team_id', teamId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Ese equipo ya está inscrito o pendiente');
    }

    await SupabaseService.client.from('tournament_team_requests').insert({
      'tournament_id': tournamentId,
      'team_id': teamId,
      'requested_by': userId,
      'status': 'pending',
    });
  }

  // 🔹 VER SOLICITUDES INDIVIDUALES
  Future<List<Map<String, dynamic>>> getPendingRequests(
      int tournamentId) async {
    final response = await SupabaseService.client
        .from('join_requests')
        .select()
        .eq('tournament_id', tournamentId)
        .eq('status', 'pending');

    return List<Map<String, dynamic>>.from(response);
  }

  // 🔹 ACTUALIZAR ESTADO
  Future<void> updateStatus(int id, String status) async {
    await SupabaseService.client
        .from('join_requests')
        .update({'status': status})
        .eq('id', id);
  }
}