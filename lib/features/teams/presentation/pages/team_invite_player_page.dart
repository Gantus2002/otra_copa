import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/team_service.dart';

class TeamInvitePlayerPage extends StatefulWidget {
  final int teamId;
  final String teamName;

  const TeamInvitePlayerPage({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TeamInvitePlayerPage> createState() => _TeamInvitePlayerPageState();
}

class _TeamInvitePlayerPageState extends State<TeamInvitePlayerPage> {
  final TeamService _teamService = TeamService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> results = [];
  Set<String> memberIds = {};
  Set<String> invitedIds = {};

  bool isLoading = false;
  Timer? _debounce;
  String? invitingUserId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadTeamStatus();
    await _searchPlayers();
  }

  Future<void> _loadTeamStatus() async {
    final client = Supabase.instance.client;

    final members = await client
        .from('team_members')
        .select('user_id')
        .eq('team_id', widget.teamId);

    final invitations = await client
        .from('team_invitations')
        .select('invited_user_id')
        .eq('team_id', widget.teamId)
        .eq('status', 'pending');

    if (!mounted) return;

    setState(() {
      memberIds = List<Map<String, dynamic>>.from(members)
          .map((e) => e['user_id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();

      invitedIds = List<Map<String, dynamic>>.from(invitations)
          .map((e) => e['invited_user_id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchPlayers();
    });
  }

  Future<void> _copyCode(String code) async {
    if (code.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código copiado')),
    );
  }

  Future<void> _searchPlayers() async {
    final query = _searchController.text.trim();

    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;

      List<dynamic> response;

      if (query.isEmpty) {
        response = await client
            .from('profiles')
            .select('id, full_name, role, avatar_url, public_code')
            .eq('role', 'player')
            .order('full_name')
            .limit(30);
      } else {
        response = await client
            .from('profiles')
            .select('id, full_name, role, avatar_url, public_code')
            .eq('role', 'player')
            .or('full_name.ilike.%$query%,public_code.ilike.%$query%')
            .order('full_name')
            .limit(50);
      }

      final mapped = List<Map<String, dynamic>>.from(response)
          .where((p) => p['id']?.toString() != currentUser?.id)
          .toList();

      if (!mounted) return;

      setState(() {
        results = mapped;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error buscando jugadores: $e')),
      );
    }
  }

  Future<void> _invitePlayer(Map<String, dynamic> player) async {
    final invitedUserId = player['id']?.toString() ?? '';
    if (invitedUserId.isEmpty) return;

    if (memberIds.contains(invitedUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese jugador ya está en el equipo')),
      );
      return;
    }

    if (invitedIds.contains(invitedUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese jugador ya fue invitado')),
      );
      return;
    }

    setState(() {
      invitingUserId = invitedUserId;
    });

    try {
      await _teamService.invitePlayer(
        teamId: widget.teamId,
        invitedUserId: invitedUserId,
      );

      await _loadTeamStatus();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invitación enviada a ${(player['full_name'] ?? 'Jugador').toString()}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo invitar: $message')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        invitingUserId = null;
      });
    }
  }

  Widget _avatar({
    required String fullName,
    required String? avatarUrl,
  }) {
    final initial =
        fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : 'J';

    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 25,
      child: Text(initial),
    );
  }

  Widget _statusChip({
    required BuildContext context,
    required String text,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteButton({
    required Map<String, dynamic> player,
    required bool isInviting,
    required bool isMember,
    required bool isInvited,
  }) {
    if (isMember) {
      return const Chip(
        avatar: Icon(Icons.check_circle, size: 16),
        label: Text('En equipo'),
      );
    }

    if (isInvited) {
      return const Chip(
        avatar: Icon(Icons.schedule, size: 16),
        label: Text('Invitado'),
      );
    }

    return FilledButton.icon(
      onPressed: isInviting ? null : () => _invitePlayer(player),
      icon: isInviting
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.person_add_alt_1, size: 18),
      label: Text(isInviting ? 'Enviando...' : 'Invitar'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text('Invitar a ${widget.teamName}'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              _searchPlayers();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Buscá jugadores por nombre o por código único. Si ya están invitados o dentro del equipo, lo vas a ver acá.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            query.isEmpty
                                ? 'Todavía no hay jugadores para mostrar.'
                                : 'No se encontraron jugadores.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = results[index];
                          final id = item['id']?.toString() ?? '';
                          final fullName =
                              (item['full_name'] ?? 'Jugador').toString();
                          final avatarUrl = item['avatar_url']?.toString();
                          final publicCode =
                              (item['public_code'] ?? '').toString();

                          final isInviting = invitingUserId == id;
                          final isMember = memberIds.contains(id);
                          final isInvited = invitedIds.contains(id);

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: theme.colorScheme.surface,
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
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  _avatar(
                                    fullName: fullName,
                                    avatarUrl: avatarUrl,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (publicCode.isNotEmpty)
                                              InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                onTap: () =>
                                                    _copyCode(publicCode),
                                                child: _statusChip(
                                                  context: context,
                                                  text: publicCode,
                                                  icon: Icons.copy,
                                                ),
                                              ),
                                            if (isMember)
                                              _statusChip(
                                                context: context,
                                                text: 'En equipo',
                                                icon: Icons.check_circle,
                                              ),
                                            if (isInvited)
                                              _statusChip(
                                                context: context,
                                                text: 'Invitado',
                                                icon: Icons.schedule,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _inviteButton(
                                    player: item,
                                    isInviting: isInviting,
                                    isMember: isMember,
                                    isInvited: isInvited,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}