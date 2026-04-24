import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../invite/data/join_request_service.dart';
import 'tournament_fixture_page.dart';
import 'tournament_players_page.dart';
import 'tournament_standings_page.dart';

class AdminPage extends StatefulWidget {
  final int tournamentId;
  final String tournamentName;

  const AdminPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  final JoinRequestService _service = JoinRequestService();

  List<Map<String, dynamic>> playerRequests = [];
  List<Map<String, dynamic>> teamRequests = [];

  bool isLoading = true;
  bool isProcessing = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenPlayerRequests();
    _loadTeamRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _listenPlayerRequests() {
    Supabase.instance.client
        .from('join_requests')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', widget.tournamentId)
        .listen((data) {
      if (!mounted) return;

      setState(() {
        playerRequests = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    });
  }

  Future<void> _loadTeamRequests() async {
    try {
      final response = await Supabase.instance.client
          .from('tournament_team_requests')
          .select('*, teams(name, logo_url, code, city, country)')
          .eq('tournament_id', widget.tournamentId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        teamRequests = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnackBar('Error cargando equipos: $e');
    }
  }

  Future<void> _refreshAll() async {
    await _loadTeamRequests();
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-push-notification',
        body: {
          'userId': userId,
          'title': title,
          'body': body,
        },
      );
    } catch (e) {
      debugPrint('Error enviando notificación: $e');
    }
  }

  Future<void> _approvePlayer(Map<String, dynamic> request) async {
    if (isProcessing) return;

    final client = Supabase.instance.client;
    setState(() => isProcessing = true);

    try {
      await client.from('tournament_players').insert({
        'tournament_id': request['tournament_id'],
        'player_name': request['player_name'],
        'user_id': request['user_id'],
      });

      await _service.updateStatus(request['id'], 'approved');

      await _sendNotification(
        userId: request['user_id'],
        title: 'Solicitud aprobada ⚽',
        body: 'Fuiste aceptado en ${widget.tournamentName}',
      );

      _showSnackBar('Jugador aprobado');
    } catch (e) {
      final message = e.toString();

      if (message.contains('duplicate key') ||
          message.contains('tournament_players_unique_user_tournament')) {
        await _service.updateStatus(request['id'], 'approved');
        _showSnackBar('Ese jugador ya estaba confirmado');
      } else {
        _showSnackBar('Error aprobando jugador: $e');
      }
    } finally {
      if (!mounted) return;
      setState(() => isProcessing = false);
    }
  }

  Future<void> _rejectPlayer(Map<String, dynamic> request) async {
    if (isProcessing) return;

    setState(() => isProcessing = true);

    try {
      await _service.updateStatus(request['id'], 'rejected');

      await _sendNotification(
        userId: request['user_id'],
        title: 'Solicitud rechazada',
        body: 'Tu solicitud para ${widget.tournamentName} fue rechazada',
      );

      _showSnackBar('Solicitud rechazada');
    } catch (e) {
      _showSnackBar('Error rechazando solicitud: $e');
    } finally {
      if (!mounted) return;
      setState(() => isProcessing = false);
    }
  }

  Future<void> _approveTeam(Map<String, dynamic> request) async {
    if (isProcessing) return;

    final client = Supabase.instance.client;
    setState(() => isProcessing = true);

    try {
      final existing = await client
          .from('tournament_teams')
          .select('id')
          .eq('tournament_id', request['tournament_id'])
          .eq('team_id', request['team_id'])
          .maybeSingle();

      if (existing == null) {
        await client.from('tournament_teams').insert({
          'tournament_id': request['tournament_id'],
          'team_id': request['team_id'],
        });
      }

      await client
          .from('tournament_team_requests')
          .update({'status': 'approved'})
          .eq('id', request['id']);

      await _loadTeamRequests();
      _showSnackBar('Equipo aprobado');
    } catch (e) {
      _showSnackBar('Error aprobando equipo: $e');
    } finally {
      if (!mounted) return;
      setState(() => isProcessing = false);
    }
  }

  Future<void> _rejectTeam(Map<String, dynamic> request) async {
    if (isProcessing) return;

    setState(() => isProcessing = true);

    try {
      await Supabase.instance.client
          .from('tournament_team_requests')
          .update({'status': 'rejected'})
          .eq('id', request['id']);

      await _loadTeamRequests();
      _showSnackBar('Equipo rechazado');
    } catch (e) {
      _showSnackBar('Error rechazando equipo: $e');
    } finally {
      if (!mounted) return;
      setState(() => isProcessing = false);
    }
  }

  void _openPlayers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentPlayersPage(
          tournamentId: widget.tournamentId,
          tournamentName: widget.tournamentName,
        ),
      ),
    );
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

  void _openStandings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentStandingsPage(
          tournamentId: widget.tournamentId,
          tournamentName: widget.tournamentName,
        ),
      ),
    );
  }

  Widget _teamLogo(String? logoUrl) {
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          logoUrl,
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

    final pendingPlayers =
        playerRequests.where((r) => r['status'] == 'pending').toList();

    final pendingTeams =
        teamRequests.where((r) => r['status'] == 'pending').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournamentName),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Jugadores (${pendingPlayers.length})'),
            Tab(text: 'Equipos (${pendingTeams.length})'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Jugadores',
            icon: const Icon(Icons.group),
            onPressed: _openPlayers,
          ),
          IconButton(
            tooltip: 'Fixture',
            icon: const Icon(Icons.calendar_month),
            onPressed: _openFixture,
          ),
          IconButton(
            tooltip: 'Tabla',
            icon: const Icon(Icons.leaderboard),
            onPressed: _openStandings,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RequestsList(
                    emptyIcon: Icons.person_search,
                    emptyTitle: 'No hay solicitudes de jugadores',
                    emptySubtitle:
                        'Cuando alguien pida unirse individualmente, aparecerá acá.',
                    children: pendingPlayers.map((request) {
                      final name =
                          (request['player_name'] ?? 'Jugador').toString();

                      return _RequestCard(
                        icon: Icons.person,
                        title: name,
                        subtitle: 'Solicitud individual pendiente',
                        isProcessing: isProcessing,
                        onApprove: () => _approvePlayer(request),
                        onReject: () => _rejectPlayer(request),
                      );
                    }).toList(),
                  ),
                  _RequestsList(
                    emptyIcon: Icons.groups_2_outlined,
                    emptyTitle: 'No hay solicitudes de equipos',
                    emptySubtitle:
                        'Cuando un equipo solicite entrar al torneo, aparecerá acá.',
                    children: pendingTeams.map((request) {
                      final team =
                          Map<String, dynamic>.from(request['teams'] ?? {});
                      final name = (team['name'] ?? 'Equipo').toString();
                      final code = (team['code'] ?? '').toString();
                      final city = (team['city'] ?? '').toString();
                      final country = (team['country'] ?? '').toString();
                      final logoUrl = team['logo_url']?.toString();

                      final location = [city, country]
                          .where((e) => e.trim().isNotEmpty)
                          .join(', ');

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
                            _teamLogo(logoUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    [
                                      if (location.isNotEmpty) location,
                                      if (code.isNotEmpty) code,
                                    ].join(' • '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              onPressed:
                                  isProcessing ? null : () => _approveTeam(request),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.red,
                              ),
                              onPressed:
                                  isProcessing ? null : () => _rejectTeam(request),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final List<Widget> children;

  const _RequestsList({
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 90),
          Icon(
            emptyIcon,
            size: 54,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            emptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emptySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _RequestCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.25),
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
          CircleAvatar(
            radius: 24,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: isProcessing ? null : onApprove,
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            onPressed: isProcessing ? null : onReject,
          ),
        ],
      ),
    );
  }
}