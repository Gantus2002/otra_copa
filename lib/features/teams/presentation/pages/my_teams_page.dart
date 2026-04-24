import 'package:flutter/material.dart';

import '../../data/team_service.dart';
import 'create_team_page.dart';
import 'team_detail_page.dart';

class MyTeamsPage extends StatefulWidget {
  const MyTeamsPage({super.key});

  @override
  State<MyTeamsPage> createState() => _MyTeamsPageState();
}

class _MyTeamsPageState extends State<MyTeamsPage> {
  final TeamService _service = TeamService();

  bool isLoading = true;
  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> invitations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final myTeams = await _service.getMyTeams();
      final pendingInvitations = await _service.getPendingInvitations();

      if (!mounted) return;
      setState(() {
        teams = myTeams;
        invitations = pendingInvitations;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando equipos: $e')),
      );
    }
  }

  Future<void> _openCreateTeam() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateTeamPage(),
      ),
    );

    if (result != null) {
      await _load();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamDetailPage(teamId: result),
        ),
      );
    }
  }

  Future<void> _editTeam(Map<String, dynamic> team) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTeamPage(team: team),
      ),
    );

    if (changed == true) {
      await _load();
    }
  }

  Future<void> _deleteTeam(Map<String, dynamic> team) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar equipo'),
        content: Text(
          '¿Seguro que querés borrar ${(team['name'] ?? 'este equipo').toString()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deleteTeam(team['id'] as int);
      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipo borrado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error borrando equipo: $e')),
      );
    }
  }

  Future<void> _respondInvitation({
    required int invitationId,
    required bool accept,
  }) async {
    try {
      await _service.respondToInvitation(
        invitationId: invitationId,
        accept: accept,
      );

      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Invitación aceptada' : 'Invitación rechazada'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error respondiendo invitación: $e')),
      );
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Dueño';
      case 'captain':
        return 'Capitán';
      default:
        return 'Miembro';
    }
  }

  Widget _teamLogo(Map<String, dynamic> team) {
    final logoUrl = team['logo_url']?.toString();

    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          logoUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const CircleAvatar(
            child: Icon(Icons.shield_outlined),
          ),
        ),
      );
    }

    return const CircleAvatar(
      child: Icon(Icons.shield_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis equipos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTeam,
        icon: const Icon(Icons.add),
        label: const Text('Crear equipo'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (invitations.isNotEmpty) ...[
                    Text(
                      'Invitaciones pendientes',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...invitations.map(
                      (inv) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (inv['team_name'] ?? 'Equipo').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Te invitó ${(inv['invited_by_name'] ?? 'Jugador').toString()}',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _respondInvitation(
                                        invitationId: inv['id'] as int,
                                        accept: false,
                                      ),
                                      child: const Text('Rechazar'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => _respondInvitation(
                                        invitationId: inv['id'] as int,
                                        accept: true,
                                      ),
                                      child: const Text('Aceptar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    'Mis equipos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (teams.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Todavía no formás parte de ningún equipo.'),
                      ),
                    )
                  else
                    ...teams.map(
                      (team) {
                        final isOwner = (team['my_role'] ?? '') == 'owner';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: _teamLogo(team),
                            title: Text(
                              (team['name'] ?? 'Equipo').toString(),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              '${_roleLabel((team['my_role'] ?? '').toString())} • ${(team['code'] ?? 'Sin código').toString()}\n'
                              '${(team['city'] ?? '').toString()}, ${(team['country'] ?? '').toString()}',
                            ),
                            isThreeLine: true,
                            trailing: isOwner
                                ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editTeam(team);
                                      } else if (value == 'delete') {
                                        _deleteTeam(team);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Editar'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Borrar'),
                                      ),
                                    ],
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeamDetailPage(
                                    teamId: team['id'] as int,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}