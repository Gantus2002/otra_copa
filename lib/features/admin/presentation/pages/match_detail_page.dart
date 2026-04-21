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
    if (userId.trim().isEmpty) {
      _showSnackBar('Este jugador no tiene user_id');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPublicProfilePage(userId: userId),
      ),
    );
  }

  Future<void> _loadPlayers() async {
    try {
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
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando jugadores: $e');
    }
  }

  Future<void> _saveAll() async {
    _safeSetState(() => isSaving = true);

    try {
      final client = Supabase.instance.client;

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

      await client.from('matches').update({
        'status': 'finished',
      }).eq('id', widget.match['id']);

      if (!mounted) return;

      _showSnackBar('Partido cargado completo');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      _safeSetState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = (widget.match['home_team_name'] ?? '').toString();
    final away = (widget.match['away_team_name'] ?? '').toString();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppBarWithNotifications(title: 'Cargar stats'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '$home vs $away',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Jugadores',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...players.map((player) {
                  final name = (player['player_name'] ?? 'Jugador').toString();
                  final userId = (player['user_id'] ?? '').toString();

                  return Card(
                    child: ListTile(
                      onTap: () => _openPlayerProfile(userId),
                      leading: const Icon(Icons.person),
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text('Goles: '),
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  _safeSetState(() {
                                    final current = goals[userId] ?? 0;
                                    goals[userId] = current > 0 ? current - 1 : 0;
                                  });
                                },
                              ),
                              Text('${goals[userId] ?? 0}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  _safeSetState(() {
                                    goals[userId] = (goals[userId] ?? 0) + 1;
                                  });
                                },
                              ),
                            ],
                          ),
                          Text(
                            'Ver perfil',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
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
                    ),
                  );
                }),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isSaving ? null : _saveAll,
                  child: Text(isSaving ? 'Guardando...' : 'Guardar todo'),
                ),
              ],
            ),
    );
  }
}