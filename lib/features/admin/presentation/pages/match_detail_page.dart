// IMPORTS IGUAL (no los cambio)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_bar_with_notifications.dart';
import '../../../match/data/match_stats_service.dart';
import '../../../player/presentation/pages/player_public_profile_page.dart';

class MatchDetailPage extends StatefulWidget {
  final Map<String, dynamic> match;

  const MatchDetailPage({
    super.key,
    required this.match,
  });

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  final MatchStatsService _statsService = MatchStatsService();

  List<Map<String, dynamic>> players = [];
  final Map<String, int> goals = {};

  String? selectedMvp;
  bool isLoading = true;
  bool isSaving = false;

  int homeScore = 0;
  int awayScore = 0;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _openPlayerProfile(String userId) {
    if (userId.trim().isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPublicProfilePage(userId: userId),
      ),
    );
  }

  Future<void> _loadPlayers() async {
    final client = Supabase.instance.client;

    final data = await client
        .from('tournament_players')
        .select()
        .eq('tournament_id', widget.match['tournament_id']);

    final list = List<Map<String, dynamic>>.from(data);

    _safeSetState(() {
      players = list;
      goals.clear();

      for (final p in players) {
        final userId = (p['user_id'] ?? '').toString();
        goals[userId] = 0;
      }

      isLoading = false;
    });
  }

  // 🔥 CALCULAR MARCADOR
  void _calculateScore() {
    int totalGoals = goals.values.fold(0, (a, b) => a + b);

    // SIMPLE: dividir goles (más adelante lo mejoramos por equipo)
    homeScore = (totalGoals / 2).floor();
    awayScore = totalGoals - homeScore;
  }

  Future<void> _saveAll() async {
    _safeSetState(() => isSaving = true);

    try {
      final client = Supabase.instance.client;

      _calculateScore();

      final playersStats = players.map((p) {
        final userId = (p['user_id'] ?? '').toString();

        return {
          'user_id': userId,
          'goals': goals[userId] ?? 0,
          'is_mvp': selectedMvp == userId,
        };
      }).toList();

      await _statsService.saveMatchStats(
        matchId: widget.match['id'],
        tournamentId: widget.match['tournament_id'],
        playersStats: playersStats,
      );

      // 🔥 GUARDAR RESULTADO
      await client.from('matches').update({
        'home_score': homeScore,
        'away_score': awayScore,
        'status': 'finished',
      }).eq('id', widget.match['id']);

      _showSnackBar('Partido guardado correctamente');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      _safeSetState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.match['home_team_name'];
    final away = widget.match['away_team_name'];

    return Scaffold(
      appBar: const AppBarWithNotifications(title: 'Cargar partido'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 🔥 HEADER CON MARCADOR
                Column(
                  children: [
                    Text(
                      '$home vs $away',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$homeScore - $awayScore',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const Text(
                  'Jugadores',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                ...players.map((player) {
                  final name = player['player_name'];
                  final userId = player['user_id'];

                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              _safeSetState(() {
                                final current = goals[userId] ?? 0;
                                goals[userId] =
                                    current > 0 ? current - 1 : 0;
                                _calculateScore();
                              });
                            },
                          ),
                          Text('${goals[userId] ?? 0}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              _safeSetState(() {
                                goals[userId] =
                                    (goals[userId] ?? 0) + 1;
                                _calculateScore();
                              });
                            },
                          ),
                        ],
                      ),
                      trailing: Radio<String>(
                        value: userId,
                        groupValue: selectedMvp,
                        onChanged: (value) {
                          _safeSetState(() {
                            selectedMvp = value;
                          });
                        },
                      ),
                      onTap: () => _openPlayerProfile(userId),
                    ),
                  );
                }),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: isSaving ? null : _saveAll,
                  child: Text(
                    isSaving ? 'Guardando...' : 'Finalizar partido',
                  ),
                ),
              ],
            ),
    );
  }
}