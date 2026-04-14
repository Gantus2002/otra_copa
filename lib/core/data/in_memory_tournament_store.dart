class InMemoryTournamentStore {
  static final List<Map<String, String>> invitedTournaments = [];
  static final List<Map<String, String>> joinRequests = [];

  static void addTournament({
    required String code,
    required String name,
    required String location,
    required String type,
    required String mode,
    required String category,
  }) {
    invitedTournaments.add({
      'code': code,
      'name': name,
      'location': location,
      'type': type,
      'mode': mode,
      'category': category,
    });
  }

  static Map<String, String>? findByCode(String code) {
    try {
      return invitedTournaments.firstWhere(
        (tournament) => tournament['code'] == code,
      );
    } catch (_) {
      return null;
    }
  }

  static void addJoinRequest({
    required String code,
    required String playerName,
    required String tournamentName,
  }) {
    joinRequests.add({
      'code': code,
      'playerName': playerName,
      'tournamentName': tournamentName,
      'status': 'Pendiente',
    });
  }

  static void updateJoinRequestStatus(int index, String status) {
    joinRequests[index]['status'] = status;
  }
}