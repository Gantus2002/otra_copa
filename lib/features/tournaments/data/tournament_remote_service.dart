import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class TournamentRemoteService {
  // 🔹 CREAR TORNEO
  Future<void> createTournament({
    required String name,
    required String location,
    required String tournamentType,
    required String gameMode,
    required String category,
    required bool isOfficial,
    required String startDate,
    required int teamsCount,
    required String prizes,
    required String joinMode,
    required bool hasReferees,
    required bool hasOffside,
    required bool hasCardSanctions,
    required String duration,
    required String tieBreaker,
    double? entryFeeIndividual,
    double? entryFeeTeam,
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
      'start_date': startDate,
      'teams_count': teamsCount,
      'entry_fee_individual': entryFeeIndividual,
      'entry_fee_team': entryFeeTeam,
      'prizes': prizes,
      'join_mode': joinMode,
      'has_referees': hasReferees,
      'has_offside': hasOffside,
      'has_card_sanctions': hasCardSanctions,
      'duration': duration,
      'tie_breaker': tieBreaker,
    });
  }

  // 🔹 BUSCAR POR CÓDIGO
  Future<Map<String, dynamic>?> findByInviteCode(String code) async {
    final response = await SupabaseService.client
        .from('tournaments')
        .select()
        .eq('invite_code', code)
        .maybeSingle();

    return response;
  }

  // 🔹 MIS TORNEOS
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

  // 🔹 (LO MISMO PERO MÁS CLARO PARA FUTURO)
  Future<List<Map<String, dynamic>>> getMyCreatedTournaments() async {
    return getMyTournaments();
  }

  // 🔹 TODOS LOS TORNEOS (BASE)
  Future<List<Map<String, dynamic>>> getAllVisibleTournaments() async {
    final response = await SupabaseService.client
        .from('tournaments')
        .select()
        .order('start_date', ascending: true)
        .order('id', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 🔥 NUEVO: TORNEOS POR CIUDAD (CLAVE)
  Future<List<Map<String, dynamic>>> getTournamentsByCity(String city) async {
    if (city.trim().isEmpty) {
      return getAllVisibleTournaments();
    }

    final response = await SupabaseService.client
        .from('tournaments')
        .select()
        .ilike('location', '%$city%')
        .order('start_date', ascending: true)
        .order('id', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}