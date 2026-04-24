import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_bar_with_notifications.dart';
import '../../data/team_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _loadData() async {
    try {
      final client = Supabase.instance.client;

      final playersResponse = await client
          .from('tournament_players')
          .select()
          .eq('tournament_id', widget.tournamentId)
          .order('id');

      final teamsResponse = await client
          .from('tournament_teams')
          .select('*, teams(id, name, logo_url, code, city, country)')
          .eq('tournament_id', widget.tournamentId)
          .order('id');

      _safeSetState(() {
        players = List<Map<String, dynamic>>.from(playersResponse);
        teams = List<Map<String, dynamic>>.from(teamsResponse);
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() => isLoading = false);
      _showSnackBar('Error cargando datos: $e');
    }
  }

  Future<void> _generateAutomaticTeams() async {
    if (players.length < 2) {
      _showSnackBar('Se necesitan al menos 2 jugadores individuales');
      return;
    }

    _safeSetState(() => isGenerating = true);

    try {
      final playerNames = players
          .map((p) => (p['player_name'] ?? 'Jugador').toString())
          .toList();

      await _teamService.generateTeams(
        tournamentId: widget.tournamentId,
        playerNames: playerNames,
      );

      await _loadData();
      _showSnackBar('Equipos automáticos generados');
    } catch (e) {
      _showSnackBar('Error generando equipos: $e');
    } finally {
      _safeSetState(() => isGenerating = false);
    }
  }

  void _openFixture() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentFixturePage(
          tournamentId: widget.tournamentId,
          tournamentName: widget.tournamentName,
        ),
      ),
    );
  }

  String _teamName(Map<String, dynamic> row) {
    final realTeam = row['teams'];

    if (realTeam is Map && realTeam['name'] != null) {
      final name = realTeam['name'].toString().trim();
      if (name.isNotEmpty) return name;
    }

    final fallback = row['name']?.toString().trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;

    return 'Equipo';
  }

  String _teamSubtitle(Map<String, dynamic> row) {
    final realTeam = row['teams'];

    if (realTeam is Map) {
      final city = (realTeam['city'] ?? '').toString();
      final country = (realTeam['country'] ?? '').toString();
      final code = (realTeam['code'] ?? '').toString();

      return [
        [city, country].where((e) => e.trim().isNotEmpty).join(', '),
        code,
      ].where((e) => e.trim().isNotEmpty).join(' • ');
    }

    final teamPlayers = row['players'];

    if (teamPlayers is List) {
      return '${teamPlayers.length} jugadores';
    }

    return 'Equipo aprobado';
  }

  String? _teamLogo(Map<String, dynamic> row) {
    final realTeam = row['teams'];

    if (realTeam is Map && realTeam['logo_url'] != null) {
      final url = realTeam['logo_url'].toString().trim();
      if (url.isNotEmpty) return url;
    }

    return null;
  }

  Widget _logo(String? url) {
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const CircleAvatar(
            radius: 24,
            child: Icon(Icons.shield_outlined),
          ),
        ),
      );
    }

    return const CircleAvatar(
      radius: 24,
      child: Icon(Icons.shield_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBarWithNotifications(
        title: 'Jugadores - ${widget.tournamentName}',
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          isGenerating ? null : _generateAutomaticTeams,
                      icon: isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.groups_2),
                      label: Text(
                        isGenerating
                            ? 'Generando...'
                            : 'Generar equipos automáticos',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Jugadores',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (players.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: Text('No hay jugadores aún')),
                    )
                  else
                    ...players.map((player) {
                      final name =
                          (player['player_name'] ?? 'Jugador').toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(name),
                          subtitle: const Text('Jugador inscrito'),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  Text(
                    'Equipos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (teams.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Todavía no hay equipos aprobados.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    ...teams.map((teamRow) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withOpacity(0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _logo(_teamLogo(teamRow)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _teamName(teamRow),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _teamSubtitle(teamRow),
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle,
                                color: Colors.green),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openFixture,
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Ver fixture'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}