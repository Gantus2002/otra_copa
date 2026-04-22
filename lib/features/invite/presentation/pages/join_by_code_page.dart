import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../tournaments/data/tournament_join_service.dart';
import '../../../tournaments/data/tournament_remote_service.dart';
import '../../data/join_request_service.dart';
import '../../../tournaments/presentation/pages/team_tournament_join_page.dart';

class JoinByCodePage extends StatefulWidget {
  const JoinByCodePage({super.key});

  @override
  State<JoinByCodePage> createState() => _JoinByCodePageState();
}

class _JoinByCodePageState extends State<JoinByCodePage> {
  final TextEditingController codeController = TextEditingController();
  final TournamentRemoteService _remoteService = TournamentRemoteService();
  final JoinRequestService _requestService = JoinRequestService();
  final TournamentJoinService _joinService = TournamentJoinService();

  Map<String, dynamic>? foundTournament;
  bool isLoading = false;
  bool isJoiningPlayer = false;

  Future<String> _getCurrentUserDisplayName() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('No hay usuario logueado');
    }

    final profile = await client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .maybeSingle();

    final fullName = profile?['full_name'];

    if (fullName == null || fullName.toString().trim().isEmpty) {
      return user.email ?? 'Jugador';
    }

    return fullName.toString();
  }

  double? _parseFee(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _moneyText(dynamic value) {
    final fee = _parseFee(value);
    if (fee == null) return 'A confirmar';
    return 'Gs. ${fee.toStringAsFixed(0)}';
  }

  Future<void> _searchTournamentByCode() async {
    final code = codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un código')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      foundTournament = null;
    });

    try {
      final tournament = await _remoteService.findByInviteCode(code);

      if (!mounted) return;

      if (tournament == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código inválido')),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      setState(() {
        foundTournament = tournament;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Torneo encontrado')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error buscando torneo: $e')),
      );
    }
  }

  Future<void> _joinAsPlayer() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenés que iniciar sesión')),
      );
      return;
    }

    if (foundTournament == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero buscá un torneo')),
      );
      return;
    }

    setState(() {
      isJoiningPlayer = true;
    });

    try {
      final alreadyPending = await _joinService.hasPendingPlayerRequest(
        tournamentId: foundTournament!['id'] as int,
        userId: user.id,
      );

      if (alreadyPending) {
        throw Exception('Ya enviaste una solicitud para este torneo');
      }

      final playerName = await _getCurrentUserDisplayName();

      await _requestService.createRequest(
        tournamentId: foundTournament!['id'] as int,
        playerName: playerName,
        userId: user.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud individual enviada. Esperando aprobación'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString();

      if (message.contains('duplicate key') ||
          message.contains('join_requests_unique_user_tournament')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ya enviaste una solicitud para este torneo'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${message.replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        isJoiningPlayer = false;
      });
    }
  }

  Future<void> _joinAsTeam() async {
    if (foundTournament == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TeamTournamentJoinPage(
          tournamentId: foundTournament!['id'] as int,
          tournamentName:
              foundTournament!['name']?.toString() ?? 'Torneo',
          teamEntryFee: _parseFee(
            foundTournament!['team_entry_fee'] ??
                foundTournament!['entry_fee_team'],
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud de equipo enviada. Esperando aprobación'),
        ),
      );
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;

    final individualFee = foundTournament == null
        ? null
        : _parseFee(
            foundTournament!['entry_fee'] ??
                foundTournament!['entry_fee_individual'],
          );

    final teamFee = foundTournament == null
        ? null
        : _parseFee(
            foundTournament!['team_entry_fee'] ??
                foundTournament!['entry_fee_team'],
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirse por código'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.14),
                    theme.colorScheme.primaryContainer.withOpacity(0.28),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresá el código del torneo',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vas a unirte con tu cuenta actual: ${user?.email ?? 'sin sesión'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Código del torneo',
                      hintText: 'Ej: TOR-AB123',
                      prefixIcon: const Icon(Icons.qr_code_2),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : _searchTournamentByCode,
                      icon: const Icon(Icons.search),
                      label: Text(
                        isLoading ? 'Buscando...' : 'Buscar torneo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (foundTournament != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: theme.colorScheme.surface,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.22),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foundTournament!['name']?.toString() ?? 'Torneo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: (foundTournament!['location'] ?? '')
                              .toString(),
                        ),
                        _InfoChip(
                          icon: Icons.emoji_events_outlined,
                          label: (foundTournament!['tournament_type'] ?? '')
                              .toString(),
                        ),
                        _InfoChip(
                          icon: Icons.groups_outlined,
                          label: (foundTournament!['game_mode'] ?? '')
                              .toString(),
                        ),
                        _InfoChip(
                          icon: Icons.shield_outlined,
                          label: (foundTournament!['category'] ?? '')
                              .toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _FeeCard(
                            title: 'Costo individual',
                            value: _moneyText(individualFee),
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FeeCard(
                            title: 'Costo por equipo',
                            value: _moneyText(teamFee),
                            icon: Icons.groups_2_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '¿Cómo querés unirte?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isJoiningPlayer ? null : _joinAsPlayer,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(
                          isJoiningPlayer
                              ? 'Enviando...'
                              : 'Unirme como jugador',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _joinAsTeam,
                        icon: const Icon(Icons.groups_2_outlined),
                        label: const Text('Unirme con mi equipo'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _FeeCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}