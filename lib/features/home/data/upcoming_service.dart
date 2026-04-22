import 'package:supabase_flutter/supabase_flutter.dart';

class UpcomingService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUpcomingTournaments() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final data = await _client
        .from('join_requests')
        .select('''
          id,
          status,
          request_type,
          team_name_snapshot,
          tournaments:tournament_id (
            id,
            name,
            location,
            start_date,
            game_mode,
            category,
            tournament_type,
            invite_code,
            entry_fee_individual,
            entry_fee_team
          )
        ''')
        .eq('user_id', user.id)
        .inFilter('status', ['pending', 'approved', 'accepted', 'confirmed']);

    final rows = List<Map<String, dynamic>>.from(data);

    final mapped = rows
        .map((row) {
          final tournament = row['tournaments'];
          if (tournament is! Map) return null;

          return {
            'request_id': row['id'],
            'request_status': row['status'],
            'request_type': row['request_type'],
            'team_name_snapshot': row['team_name_snapshot'],
            ...Map<String, dynamic>.from(tournament),
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    mapped.sort((a, b) {
      final aDate = _parseDate(a['start_date']) ?? DateTime(2100);
      final bDate = _parseDate(b['start_date']) ?? DateTime(2100);
      return aDate.compareTo(bDate);
    });

    return mapped.take(3).toList();
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    final parts = text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }
}