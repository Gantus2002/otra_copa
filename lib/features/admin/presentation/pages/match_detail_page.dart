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

  List<Map<String, dynamic>> homePlayers = [];
  List<Map<String, dynamic>> awayPlayers = [];
  List<Map<String, dynamic>> goals = [];

  String? selectedMvp;
  bool isLoading = true;
  bool isSaving = false;

  late int homeScore;
  late int awayScore;

  int? get homeTeamId => widget.match['home_team_id'] as int?;
  int? get awayTeamId => widget.match['away_team_id'] as int?;

  @override
  void initState() {
    super.initState();

    homeScore = (widget.match['home_score'] ?? 0) as int;
    awayScore = (widget.match['away_score'] ?? 0) as int;

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
      _showSnackBar('Este jugador no tiene usuario asociado');
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

      final homeMembers = await _getTeamMembersForTournamentTeam(homeTeamId);
      final awayMembers = await _getTeamMembersForTournamentTeam(awayTeamId);

      final savedGoalsResponse = await client
          .from('match_goals')
          .select()
          .eq('match_id', widget.match['id'])
          .order('id');

      final savedStatsResponse = await client
          .from('match_player_stats')
          .select()
          .eq('match_id', widget.match['id']);

      final savedGoals = List<Map<String, dynamic>>.from(savedGoalsResponse);
      final savedStats = List<Map<String, dynamic>>.from(savedStatsResponse);

      final mvpStat = savedStats.firstWhere(
        (s) => s['is_mvp'] == true,
        orElse: () => <String, dynamic>{},
      );

      _safeSetState(() {
        homePlayers = homeMembers;
        awayPlayers = awayMembers;

        goals = savedGoals.map((goal) {
          return {
            'team_id': goal['team_id'],
            'player_id': goal['player_id'],
            'minute': goal['minute'],
          };
        }).toList();

        selectedMvp = mvpStat['user_id']?.toString();

        if (goals.isNotEmpty) {
          _recalculateScore();
        } else {
          homeScore = (widget.match['home_score'] ?? 0) as int;
          awayScore = (widget.match['away_score'] ?? 0) as int;
        }

        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() => isLoading = false);
      _showSnackBar('Error cargando partido: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getTeamMembersForTournamentTeam(
    int? tournamentTeamId,
  ) async {
    if (tournamentTeamId == null) return [];

    final client = Supabase.instance.client;

    final tournamentTeam = await client
        .from('tournament_teams')
        .select('id, team_id, name')
        .eq('id', tournamentTeamId)
        .maybeSingle();

    if (tournamentTeam == null) return [];

    final realTeamId = tournamentTeam['team_id'];

    if (realTeamId == null) return [];

    final membersResponse = await client
        .from('team_members')
        .select(
          'user_id, role, status, profiles(full_name, avatar_url, public_code)',
        )
        .eq('team_id', realTeamId)
        .eq('status', 'active');

    final members = List<Map<String, dynamic>>.from(membersResponse);

    return members.map((member) {
      final profile = member['profiles'];

      return {
        'user_id': member['user_id'],
        'player_name': profile?['full_name'] ?? 'Jugador',
        'avatar_url': profile?['avatar_url'],
        'public_code': profile?['public_code'] ?? '',
        'role': member['role'] ?? 'member',
      };
    }).toList();
  }

  void _recalculateScore() {
    homeScore = goals.where((g) => g['team_id'] == homeTeamId).length;
    awayScore = goals.where((g) => g['team_id'] == awayTeamId).length;
  }

  Future<void> _addGoal() async {
    int? selectedTeamId = homeTeamId;
    String? selectedPlayerId;
    int minute = 1;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final currentPlayers =
                selectedTeamId == homeTeamId ? homePlayers : awayPlayers;

            if (selectedPlayerId == null && currentPlayers.isNotEmpty) {
              selectedPlayerId = currentPlayers.first['user_id']?.toString();
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Agregar gol',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(
                          value: homeTeamId ?? 0,
                          label: Text(
                            (widget.match['home_team_name'] ?? 'Local')
                                .toString(),
                          ),
                        ),
                        ButtonSegment(
                          value: awayTeamId ?? 0,
                          label: Text(
                            (widget.match['away_team_name'] ?? 'Visitante')
                                .toString(),
                          ),
                        ),
                      ],
                      selected: {selectedTeamId ?? 0},
                      onSelectionChanged: (value) {
                        modalSetState(() {
                          selectedTeamId = value.first;
                          final players = selectedTeamId == homeTeamId
                              ? homePlayers
                              : awayPlayers;

                          selectedPlayerId = players.isNotEmpty
                              ? players.first['user_id']?.toString()
                              : null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedPlayerId,
                      decoration: const InputDecoration(
                        labelText: 'Goleador',
                        border: OutlineInputBorder(),
                      ),
                      items: currentPlayers.map((player) {
                        final userId = player['user_id']?.toString() ?? '';
                        final name =
                            (player['player_name'] ?? 'Jugador').toString();

                        return DropdownMenuItem<String>(
                          value: userId,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        modalSetState(() {
                          selectedPlayerId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: '1',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minuto',
                        hintText: 'Ej: 12',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        minute = int.tryParse(value) ?? 1;
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selectedPlayerId == null
                            ? null
                            : () {
                                Navigator.pop(context, {
                                  'team_id': selectedTeamId,
                                  'player_id': selectedPlayerId,
                                  'minute': minute,
                                });
                              },
                        icon: const Icon(Icons.sports_soccer),
                        label: const Text('Agregar gol'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    _safeSetState(() {
      goals.add(result);
      _recalculateScore();
    });
  }

  void _removeGoal(int index) {
    _safeSetState(() {
      goals.removeAt(index);
      _recalculateScore();
    });
  }

  String _playerNameById(String userId) {
    final allPlayers = [...homePlayers, ...awayPlayers];

    final player = allPlayers.firstWhere(
      (p) => p['user_id'] == userId,
      orElse: () => <String, dynamic>{},
    );

    return (player['player_name'] ?? 'Jugador').toString();
  }

  String _teamNameById(int? teamId) {
    if (teamId == homeTeamId) {
      return (widget.match['home_team_name'] ?? 'Local').toString();
    }

    if (teamId == awayTeamId) {
      return (widget.match['away_team_name'] ?? 'Visitante').toString();
    }

    return 'Equipo';
  }

  List<Map<String, dynamic>> _buildPlayersStats() {
    final Map<String, int> goalsByUser = {};

    for (final goal in goals) {
      final userId = goal['player_id']?.toString();
      if (userId == null || userId.isEmpty) continue;

      goalsByUser[userId] = (goalsByUser[userId] ?? 0) + 1;
    }

    final allPlayers = [...homePlayers, ...awayPlayers];

    return allPlayers.map((player) {
      final userId = player['user_id']?.toString() ?? '';

      return {
        'user_id': userId,
        'goals': goalsByUser[userId] ?? 0,
        'is_mvp': selectedMvp == userId,
      };
    }).where((player) {
      return (player['user_id'] ?? '').toString().isNotEmpty;
    }).toList();
  }

  Future<void> _saveAll() async {
    if (homeTeamId == null || awayTeamId == null) {
      _showSnackBar('No se encontraron los equipos del partido');
      return;
    }

    if (homePlayers.isEmpty || awayPlayers.isEmpty) {
      _showSnackBar(
        'Uno de los equipos no tiene jugadores activos. Revisá la plantilla.',
      );
      return;
    }

    if (selectedMvp == null) {
      _showSnackBar('Elegí el MVP del partido');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar partido'),
        content: Text(
          '¿Confirmás finalizar el partido con resultado '
          '$homeScore - $awayScore?\n\n'
          'Esto guardará goles, MVP y estadísticas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _safeSetState(() => isSaving = true);

    try {
      await _statsService.saveMatchStats(
        matchId: widget.match['id'] as int,
        tournamentId: widget.match['tournament_id'] as int,
        homeTeamId: homeTeamId!,
        awayTeamId: awayTeamId!,
        homeScore: homeScore,
        awayScore: awayScore,
        mvpUserId: selectedMvp,
        goals: goals,
        playersStats: _buildPlayersStats(),
      );

      if (!mounted) return;

      _showSnackBar('Partido finalizado correctamente');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Error guardando partido: $e');
    } finally {
      _safeSetState(() => isSaving = false);
    }
  }

  Widget _avatar(Map<String, dynamic> player) {
    final url = player['avatar_url']?.toString();
    final name = (player['player_name'] ?? 'Jugador').toString();

    if (url != null && url.trim().isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(url),
      );
    }

    return CircleAvatar(
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'J'),
    );
  }

  Widget _playerTile(Map<String, dynamic> player) {
    final userId = player['user_id']?.toString() ?? '';
    final name = (player['player_name'] ?? 'Jugador').toString();

    final goalsCount = goals.where((goal) {
      return goal['player_id'] == userId;
    }).length;

    return Card(
      child: ListTile(
        leading: _avatar(player),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('Goles: $goalsCount'),
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
  }

  @override
  Widget build(BuildContext context) {
    final home = (widget.match['home_team_name'] ?? 'Local').toString();
    final away = (widget.match['away_team_name'] ?? 'Visitante').toString();
    final status = (widget.match['status'] ?? 'scheduled').toString();

    return Scaffold(
      appBar: const AppBarWithNotifications(title: 'Cargar partido'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F3144),
                        Color(0xFF174B61),
                        Color(0xFF1D6A77),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        status == 'finished'
                            ? 'Partido finalizado'
                            : 'Cargar resultado',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              home,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '$homeScore - $awayScore',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 30,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              away,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : _addGoal,
                    icon: const Icon(Icons.sports_soccer),
                    label: const Text('Agregar gol'),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Goles cargados',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                if (goals.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Todavía no cargaste goles.'),
                    ),
                  )
                else
                  ...List.generate(goals.length, (index) {
                    final goal = goals[index];
                    final playerId = goal['player_id']?.toString() ?? '';
                    final minute = goal['minute'] ?? '-';
                    final teamId = goal['team_id'] as int?;

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.sports_soccer),
                        title: Text(_playerNameById(playerId)),
                        subtitle: Text(
                          '${_teamNameById(teamId)} • Minuto $minute',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeGoal(index),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 18),
                Text(
                  'MVP del partido',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                const Text('Seleccioná el jugador más valioso.'),
                const SizedBox(height: 12),
                Text(
                  home,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                if (homePlayers.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay jugadores activos en este equipo.'),
                    ),
                  )
                else
                  ...homePlayers.map(_playerTile),
                const SizedBox(height: 14),
                Text(
                  away,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                if (awayPlayers.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay jugadores activos en este equipo.'),
                    ),
                  )
                else
                  ...awayPlayers.map(_playerTile),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : _saveAll,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.flag_circle_outlined),
                    label: Text(
                      isSaving ? 'Guardando...' : 'Finalizar partido',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}