import 'package:flutter/material.dart';

import '../../data/team_service.dart';
import 'team_invite_player_page.dart';

class TeamDetailPage extends StatefulWidget {
  final int teamId;

  const TeamDetailPage({
    super.key,
    required this.teamId,
  });

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final TeamService _service = TeamService();

  Map<String, dynamic>? team;
  List<Map<String, dynamic>> members = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final teamData = await _service.getTeamById(widget.teamId);
      final membersData = await _service.getTeamMembers(widget.teamId);

      if (!mounted) return;
      setState(() {
        team = teamData;
        members = membersData;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando equipo: $e')),
      );
    }
  }

  Future<void> _openInvitePlayers() async {
    if (team == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamInvitePlayerPage(
          teamId: widget.teamId,
          teamName: (team!['name'] ?? 'Equipo').toString(),
        ),
      ),
    );

    await _load();
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

  Widget _buildAvatar(String name, String? avatarUrl) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'J';

    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 22,
      child: Text(initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (team == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Equipo no encontrado'),
        ),
      );
    }

    final teamName = (team!['name'] ?? 'Equipo').toString();
    final teamCode = (team!['code'] ?? '').toString();
    final city = (team!['city'] ?? '').toString();
    final country = (team!['country'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(teamName),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openInvitePlayers,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invitar'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: theme.colorScheme.surface,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (city.isNotEmpty || country.isNotEmpty)
                    Text(
                      [city, country]
                          .where((e) => e.trim().isNotEmpty)
                          .join(', '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: Text(
                          teamCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: theme.colorScheme.primaryContainer,
                        ),
                        child: Text(
                          '${members.length} miembro${members.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Miembros',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (members.isEmpty)
              const Text('Todavía no hay miembros.')
            else
              ...members.map(
                (member) {
                  final name = (member['full_name'] ?? 'Jugador').toString();
                  final avatarUrl = member['avatar_url']?.toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                      ),
                    ),
                    child: ListTile(
                      leading: _buildAvatar(name, avatarUrl),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(_roleLabel((member['role'] ?? '').toString())),
                      trailing: (member['public_code'] ?? '').toString().isEmpty
                          ? null
                          : Text(
                              member['public_code'].toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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