import 'package:flutter/material.dart';
import '../../data/team_service.dart';

class MyTeamInvitationsPage extends StatefulWidget {
  const MyTeamInvitationsPage({super.key});

  @override
  State<MyTeamInvitationsPage> createState() => _MyTeamInvitationsPageState();
}

class _MyTeamInvitationsPageState extends State<MyTeamInvitationsPage> {
  final TeamService _service = TeamService();

  List<Map<String, dynamic>> invitations = [];
  bool isLoading = true;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getMyPendingInvitations();

      if (!mounted) return;
      setState(() {
        invitations = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando invitaciones: $e')),
      );
    }
  }

  Future<void> _accept(int invitationId) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      await _service.acceptInvitation(invitationId: invitationId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación aceptada')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error aceptando invitación: $e')),
      );
    }

    if (!mounted) return;
    setState(() {
      isProcessing = false;
    });
  }

  Future<void> _reject(int invitationId) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      await _service.rejectInvitation(invitationId: invitationId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación rechazada')),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rechazando invitación: $e')),
      );
    }

    if (!mounted) return;
    setState(() {
      isProcessing = false;
    });
  }

  Widget _avatar(String name, String? avatarUrl) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'J';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitaciones de equipo'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : invitations.isEmpty
              ? const Center(
                  child: Text('No tenés invitaciones pendientes'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: invitations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final invitation = invitations[index];

                    final teamName = (invitation['team_name'] ?? 'Equipo').toString();
                    final teamCode = (invitation['team_code'] ?? '').toString();
                    final inviterName =
                        (invitation['inviter_name'] ?? 'Jugador').toString();
                    final inviterAvatar =
                        invitation['inviter_avatar_url']?.toString();
                    final city = (invitation['team_city'] ?? '').toString();
                    final country = (invitation['team_country'] ?? '').toString();

                    return Container(
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teamName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (teamCode.isNotEmpty || city.isNotEmpty || country.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (teamCode.isNotEmpty)
                                    _ChipText(label: teamCode),
                                  if (city.isNotEmpty || country.isNotEmpty)
                                    _ChipText(
                                      label: [city, country]
                                          .where((e) => e.trim().isNotEmpty)
                                          .join(', '),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _avatar(inviterName, inviterAvatar),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Invitación enviada por $inviterName',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: isProcessing
                                        ? null
                                        : () => _accept(invitation['id'] as int),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Aceptar'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isProcessing
                                        ? null
                                        : () => _reject(invitation['id'] as int),
                                    icon: const Icon(Icons.close),
                                    label: const Text('Rechazar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ChipText extends StatelessWidget {
  final String label;

  const _ChipText({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}