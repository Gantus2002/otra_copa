import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/tournament_join_service.dart';

class TeamTournamentJoinPage extends StatefulWidget {
  final int tournamentId;
  final String tournamentName;
  final double? teamEntryFee;

  const TeamTournamentJoinPage({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    this.teamEntryFee,
  });

  @override
  State<TeamTournamentJoinPage> createState() =>
      _TeamTournamentJoinPageState();
}

class _TeamTournamentJoinPageState extends State<TeamTournamentJoinPage> {
  final TournamentJoinService _service = TournamentJoinService();

  bool isLoading = true;
  bool isSending = false;

  List<Map<String, dynamic>> teams = [];
  int? selectedTeamId;
  List<Map<String, dynamic>> selectedTeamMembers = [];

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final myTeams = await _service.getMyTeams();

      if (!mounted) return;
      setState(() {
        teams = myTeams;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando equipos: $e')),
      );
    }
  }

  Future<void> _selectTeam(int teamId) async {
    setState(() {
      selectedTeamId = teamId;
      selectedTeamMembers = [];
    });

    try {
      final members = await _service.getTeamMembers(teamId);

      if (!mounted) return;
      setState(() {
        selectedTeamMembers = members;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando miembros: $e')),
      );
    }
  }

  Future<void> _submit() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (selectedTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná un equipo')),
      );
      return;
    }

    final selectedTeam = teams.firstWhere(
      (t) => t['id'] == selectedTeamId,
      orElse: () => {},
    );

    final teamName = (selectedTeam['name'] ?? 'Equipo').toString();

    setState(() {
      isSending = true;
    });

    try {
      final alreadyPending = await _service.hasPendingTeamRequest(
        tournamentId: widget.tournamentId,
        teamId: selectedTeamId!,
      );

      if (alreadyPending) {
        throw Exception('Ese equipo ya tiene una solicitud pendiente');
      }

      await _service.createTeamJoinRequest(
        tournamentId: widget.tournamentId,
        teamId: selectedTeamId!,
        teamName: teamName,
        requestedByUserId: user.id,
        entryFee: widget.teamEntryFee,
        playersCount: selectedTeamMembers.length,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $message')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isSending = false;
      });
    }
  }

  String _moneyText(double? value) {
    if (value == null) return 'A confirmar';
    return 'Gs. ${value.toStringAsFixed(0)}';
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
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 20,
      child: Text(initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirse con equipo'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.tournamentName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elegí uno de tus equipos para enviar la solicitud al torneo.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: theme.colorScheme.surface,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Costo por equipo: ${_moneyText(widget.teamEntryFee)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Mis equipos',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (teams.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                      ),
                    ),
                    child: const Text(
                      'Todavía no formás parte de ningún equipo.',
                    ),
                  )
                else
                  ...teams.map(
                    (team) {
                      final teamId = team['id'] as int;
                      final isSelected = selectedTeamId == teamId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: theme.colorScheme.surface,
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant
                                    .withOpacity(0.22),
                            width: isSelected ? 1.6 : 1,
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            (team['name'] ?? 'Equipo').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${(team['code'] ?? '').toString()} • ${(team['my_role'] ?? '').toString()}',
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: theme.colorScheme.primary,
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () => _selectTeam(teamId),
                        ),
                      );
                    },
                  ),
                if (selectedTeamId != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Jugadores del equipo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedTeamMembers.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    ...selectedTeamMembers.map(
                      (member) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: theme.colorScheme.surface,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withOpacity(0.22),
                          ),
                        ),
                        child: ListTile(
                          leading: _buildAvatar(
                            (member['full_name'] ?? 'Jugador').toString(),
                            member['avatar_url']?.toString(),
                          ),
                          title: Text(
                            (member['full_name'] ?? 'Jugador').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            _roleLabel((member['role'] ?? '').toString()),
                          ),
                          trailing: (member['public_code'] ?? '')
                                  .toString()
                                  .isEmpty
                              ? null
                              : Text(
                                  member['public_code'].toString(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isSending ? null : _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(
                        isSending ? 'Enviando...' : 'Enviar solicitud con equipo',
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}