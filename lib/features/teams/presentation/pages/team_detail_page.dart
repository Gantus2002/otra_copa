import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  String? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = Supabase.instance.client.auth.currentUser?.id;
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

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando equipo: $e')),
      );
    }
  }

  bool get isOwner {
    return members.any(
      (m) => m['user_id'] == currentUserId && m['role'] == 'owner',
    );
  }

  Future<void> _copyTeamCode(String code) async {
    if (code.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código del equipo copiado')),
    );
  }

  Future<void> _makeCaptain(String userId) async {
    try {
      await _service.updateMemberRole(
        teamId: widget.teamId,
        userId: userId,
        role: 'captain',
      );

      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jugador marcado como capitán')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _removeCaptain(String userId) async {
    try {
      await _service.updateMemberRole(
        teamId: widget.teamId,
        userId: userId,
        role: 'member',
      );

      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capitán quitado')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _removeMember(String userId) async {
    try {
      await _service.removeMember(
        teamId: widget.teamId,
        userId: userId,
      );

      await _load();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jugador eliminado del equipo')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _confirmRemove(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar jugador'),
        content: Text('¿Eliminar a $name del equipo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeMember(userId);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;

    final message = e.toString().replaceFirst('Exception: ', '');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  IconData _roleIcon(String role) {
    switch (role) {
      case 'owner':
        return Icons.workspace_premium;
      case 'captain':
        return Icons.star;
      default:
        return Icons.person;
    }
  }

  Color _roleColor(BuildContext context, String role) {
    final theme = Theme.of(context);

    switch (role) {
      case 'owner':
        return Colors.amber.shade700;
      case 'captain':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  Widget _avatar(String name, String? url) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'J';

    if (url != null && url.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(url),
      );
    }

    return CircleAvatar(
      radius: 24,
      child: Text(initial),
    );
  }

  Widget _teamLogo(BuildContext context, String? logoUrl) {
    final theme = Theme.of(context);

    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      return ClipOval(
        child: Image.network(
          logoUrl,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackTeamLogo(theme),
        ),
      );
    }

    return _fallbackTeamLogo(theme);
  }

  Widget _fallbackTeamLogo(ThemeData theme) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primaryContainer,
      ),
      child: Icon(
        Icons.shield_outlined,
        color: theme.colorScheme.onPrimaryContainer,
        size: 34,
      ),
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
      return const Scaffold(
        body: Center(child: Text('Equipo no encontrado')),
      );
    }

    final teamName = (team!['name'] ?? 'Equipo').toString();
    final code = (team!['code'] ?? '').toString();
    final city = (team!['city'] ?? '').toString();
    final country = (team!['country'] ?? '').toString();
    final logoUrl = team!['logo_url']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(teamName),
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamInvitePlayerPage(
                      teamId: widget.teamId,
                      teamName: teamName,
                    ),
                  ),
                );
                await _load();
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Invitar'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0F3144),
                    Color(0xFF174B61),
                    Color(0xFF1D6A77),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _teamLogo(context, logoUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [city, country]
                              .where((e) => e.trim().isNotEmpty)
                              .join(', '),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => _copyTeamCode(code),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.copy,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      code.isEmpty ? 'Sin código' : code,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${members.length} miembro${members.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Miembros',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (isOwner)
                  Text(
                    'Gestionar roles',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (members.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Todavía no hay miembros.'),
                ),
              )
            else
              ...members.map((member) {
                final profile = member['profiles'];
                final name = (profile?['full_name'] ?? 'Jugador').toString();
                final avatar = profile?['avatar_url']?.toString();
                final publicCode = (profile?['public_code'] ?? '').toString();
                final role = (member['role'] ?? 'member').toString();
                final userId = (member['user_id'] ?? '').toString();
                final isSelf = userId == currentUserId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: theme.colorScheme.surface,
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
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: _avatar(name, avatar),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _roleIcon(role),
                                  size: 14,
                                  color: _roleColor(context, role),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _roleLabel(role),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (publicCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: theme.colorScheme.primaryContainer
                                    .withOpacity(0.45),
                              ),
                              child: Text(
                                publicCode,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    trailing: isOwner && !isSelf && role != 'owner'
                        ? PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'captain') {
                                await _makeCaptain(userId);
                              } else if (value == 'member') {
                                await _removeCaptain(userId);
                              } else if (value == 'remove') {
                                await _confirmRemove(userId, name);
                              }
                            },
                            itemBuilder: (_) => [
                              if (role != 'captain')
                                const PopupMenuItem(
                                  value: 'captain',
                                  child: Text('Hacer capitán'),
                                ),
                              if (role == 'captain')
                                const PopupMenuItem(
                                  value: 'member',
                                  child: Text('Quitar capitán'),
                                ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Eliminar del equipo'),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}