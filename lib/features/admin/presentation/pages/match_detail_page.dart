import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../match/data/match_stats_service.dart';

class MatchDetailPage extends StatefulWidget {
  final Map<String, dynamic> match;

  const MatchDetailPage({super.key, required this.match});

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  final MatchStatsService _statsService = MatchStatsService();

  List<Map<String, dynamic>> players = [];
  Map<String, int> goals = {};
  String? selectedMvp;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final client = Supabase.instance.client;

    final data = await client
        .from('tournament_players')
        .select()
        .eq('tournament_id', widget.match['tournament_id']);

    final list = List<Map<String, dynamic>>.from(data);

    setState(() {
      players = list;
      for (var p in players) {
        goals[p['user_id']] = 0;
      }
      isLoading = false;
    });
  }

  Future<void> _saveAll() async {
    setState(() => isSaving = true);

    try {
      final client = Supabase.instance.client;

      final playersStats = players.map((p) {
        return {
          'user_id': p['user_id'],
          'goals': goals[p['user_id']] ?? 0,
          'is_mvp': selectedMvp == p['user_id'],
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partido cargado completo')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.match['home_team_name'];
    final away = widget.match['away_team_name'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargar stats'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '$home vs $away',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Jugadores',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                ...players.map((player) {
                  return Card(
                    child: ListTile(
                      title: Text(player['player_name']),
                      subtitle: Row(
                        children: [
                          const Text('Goles: '),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                goals[player['user_id']] =
                                    (goals[player['user_id']] ?? 0) - 1;
                              });
                            },
                          ),
                          Text('${goals[player['user_id']]}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                goals[player['user_id']] =
                                    (goals[player['user_id']] ?? 0) + 1;
                              });
                            },
                          ),
                        ],
                      ),
                      trailing: Radio<String>(
                        value: player['user_id'],
                        groupValue: selectedMvp,
                        onChanged: (value) {
                          setState(() {
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