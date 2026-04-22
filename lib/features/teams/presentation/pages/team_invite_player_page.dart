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
  bool isLoading = false;
  Timer? _debounce;
  String? invitingUserId;

  @override
  void initState() {
    super.initState();
    _searchPlayers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
      const SnackBar(
        content: Text('Código copiado'),
      ),
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _invitePlayer(Map<String, dynamic> player) async {
    final invitedUserId = player['id']?.toString() ?? '';
    if (invitedUserId.isEmpty) return;

    setState(() {
      invitingUserId = invitedUserId;
    });

    try {
      await _teamService.invitePlayer(
        teamId: widget.teamId,
        invitedUserId: invitedUserId,
      );

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
      String message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo invitar: $message'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        invitingUserId = null;
      });
    }
  }

  Widget _buildAvatar({
    required String fullName,
    required String? avatarUrl,
  }) {
    final initial =
        fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : 'J';

    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 24,
      child: Text(initial),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Buscá jugadores por nombre o código único y mandales invitación al equipo.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = results[index];
                          final fullName =
                              (item['full_name'] ?? 'Jugador').toString();
                          final avatarUrl = item['avatar_url']?.toString();
                          final publicCode =
                              (item['public_code'] ?? '').toString();
                          final isInviting =
                              invitingUserId == item['id']?.toString();

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
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
                                  _buildAvatar(
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (publicCode.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(999),
                                                  color: theme
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                ),
                                                child: Text(
                                                  publicCode,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                onTap: () =>
                                                    _copyCode(publicCode),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                    color: theme.colorScheme
                                                        .primaryContainer,
                                                  ),
                                                  child: Text(
                                                    'Copiar código',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                      color: theme.colorScheme
                                                          .onPrimaryContainer,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton(
                                    onPressed: isInviting
                                        ? null
                                        : () => _invitePlayer(item),
                                    child: Text(
                                      isInviting ? 'Enviando...' : 'Invitar',
                                    ),
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