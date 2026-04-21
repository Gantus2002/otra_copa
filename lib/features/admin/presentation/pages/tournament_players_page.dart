import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_bar_with_notifications.dart';
import '../../data/team_service.dart';
import '../../../player/presentation/pages/player_public_profile_page.dart';
import 'player_review_page.dart';
import 'tournament_fixture_page.dart';

class TournamentPlayersPage extends StatefulWidget {
  final int tournamentId;
  final String tournamentName;

  const TournamentPlayersPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentPlayersPage> createState() => _TournamentPlayersPageState();
}

class _TournamentPlayersPageState extends State<TournamentPlayersPage> {
  final TeamService _teamService = TeamService();

  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> teams = [];

  bool isLoading = true;
  bool isGenerating = false;

  StreamSubscription<List<Map<String, dynamic>>>? _playersSubscription;

  @override
  void initState() {
    super.initState();
    _listenPlayers();
    _loadTeams();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _listenPlayers() {
    final client = Supabase.instance.client;

    _playersSubscription?.cancel();

    _playersSubscription = client
        .from('tournament_players')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', widget.tournamentId)
        .listen(
      (data) {
        _safeSetState(() {
          players = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      },
      onError: (error) {
        _safeSetState(() {
          isLoading = false;
        });
        _showSnackBar('Error cargando jugadores');
      },
    );
  }

  Future<void> _loadTeams() async {
    try {
      final result = await _teamService.getTeamsWithPlayers(widget.tournamentId);

      _safeSetState(() {
        teams = result;
      });
    } catch (e) {
      _showSnackBar('Error cargando equipos');
    }
  }

  Future<void> _generateTeams() async {
    if (players.length < 2) {
      _showSnackBar('Se necesitan al menos 2 jugadores para generar equipos');
      return;
    }

    _safeSetState(() {
      isGenerating = true;
    });

    try {
      final names = players
          .map((player) => (player['player_name'] ?? '').toString())
          .where((name) => name.trim().isNotEmpty)
          .toList();

      await _teamService.generateTeams(
        tournamentId: widget.tournamentId,
        playerNames: names,
      );

      await _loadTeams();

      _showSnackBar('Equipos generados correctamente');
    } catch (e) {
      _showSnackBar('Error generando equipos: $e');
    } finally {
      _safeSetState(() {
        isGenerating = false;
      });
    }
  }

  void _openPlayerProfileByUserId(dynamic userId) {
    final id = (userId ?? '').toString().trim();
    if (id.isEmpty) {
      _showSnackBar('Este jugador no tiene user_id');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPublicProfilePage(userId: id),
      ),
    );
  }

  @override
  void dispose() {
    _playersSubscription?.cancel();
    _playersSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool noPlayers = players.isEmpty;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBarWithNotifications(
        title: 'Jugadores - ${widget.tournamentName}',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ElevatedButton.icon(
                  onPressed: isGenerating ? null : _generateTeams,
                  icon: const Icon(Icons.groups),
                  label: Text(
                    isGenerating
                        ? 'Generando...'
                        : 'Generar equipos automáticos',
                  ),
                ),
                const SizedBox(height: 20),
                if (noPlayers)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text('No hay jugadores aún'),
                    ),
                  )
                else ...[
                  const Text(
                    'Jugadores confirmados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...players.map(
                    (player) => Card(
                      child: ListTile(
                        onTap: () {
                          _openPlayerProfileByUserId(player['user_id']);
                        },
                        leading: const Icon(Icons.person),
                        title: Text((player['player_name'] ?? '').toString()),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Jugador confirmado'),
                            const SizedBox(height: 4),
                            Text(
                              'Ver perfil',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.star_outline),
                              onPressed: () {
                                final userId = player['user_id'];

                                if (userId == null) {
                                  _showSnackBar('Este jugador no tiene user_id');
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerReviewPage(
                                      tournamentId: widget.tournamentId,
                                      reviewedUserId: userId,
                                      playerName:
                                          (player['player_name'] ?? 'Jugador')
                                              .toString(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (teams.isNotEmpty) ...[
                  const Text(
                    'Equipos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...teams.map(
                    (team) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (team['name'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...List<Map<String, dynamic>>.from(
                              team['players'] ?? [],
                            ).map(
                              (player) {
                                final playerName =
                                    (player['player_name'] ?? '').toString();
                                final userId = player['user_id'];

                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    if (userId == null ||
                                        userId.toString().trim().isEmpty) {
                                      _showSnackBar(
                                        'Este jugador no tiene user_id',
                                      );
                                      return;
                                    }

                                    _openPlayerProfileByUserId(userId);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text('• $playerName'),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: theme.colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TournamentFixturePage(
                          tournamentId: widget.tournamentId,
                          tournamentName: widget.tournamentName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Ver fixture'),
                ),
              ],
            ),
    );
  }
}