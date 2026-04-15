import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class TournamentRemoteService {
  Future<void> createTournament({
    required String name,
    required String location,
    required String tournamentType,
    required String gameMode,
    required String category,
    required bool isOfficial,
    String? inviteCode,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    await SupabaseService.client.from('tournaments').insert({
      'name': name,
      'location': location,
      'tournament_type': tournamentType,
      'game_mode': gameMode,
      'category': category,
      'invite_code': inviteCode,
      'owner_id': user.id,
      'is_official': isOfficial,
    });
  }

  Future<Map<String, dynamic>?> findByInviteCode(String code) async {
    final response = await SupabaseService.client
        .from('tournaments')
        .select()
        .eq('invite_code', code)
        .maybeSingle();

    return response;
  }

  Future<List<Map<String, dynamic>>> getMyTournaments() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    final response = await SupabaseService.client
        .from('tournaments')
        .select()
        .eq('owner_id', user.id)
        .order('id', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getMyCreatedTournaments() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario autenticado');
    }

    final response = await SupabaseService.client
        .from('tournaments')
        .select()
        .eq('owner_id', user.id)
        .order('id', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getAllVisibleTournaments() async {
    final response = await SupabaseService.client
        .from('tournaments')
        .select()
        .order('id', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}