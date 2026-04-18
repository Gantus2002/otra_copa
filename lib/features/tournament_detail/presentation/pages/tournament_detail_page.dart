import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TournamentDetailPage extends StatefulWidget {
  final int tournamentId;

  const TournamentDetailPage({
    super.key,
    required this.tournamentId,
  });

  @override
  State<TournamentDetailPage> createState() => _TournamentDetailPageState();
}

class _TournamentDetailPageState extends State<TournamentDetailPage> {
  Map<String, dynamic>? tournament;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadTournament();
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

  Future<void> _loadTournament() async {
    try {
      final data = await Supabase.instance.client
          .from('tournaments')
          .select()
          .eq('id', widget.tournamentId)
          .single();

      _safeSetState(() {
        tournament = Map<String, dynamic>.from(data);
        loading = false;
      });
    } catch (e) {
      _safeSetState(() {
        loading = false;
      });
      _showSnackBar('No se pudo cargar el torneo');
    }
  }

  String _textValue(String key, {String fallback = '-'}) {
    final value = tournament?[key];
    if (value == null) return fallback;

    final text = value.toString().trim();
    if (text.isEmpty) return fallback;

    return text;
  }

  bool _boolValue(String key) {
    return tournament?[key] == true;
  }

  bool _hasValue(String key) {
    final value = tournament?[key];
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (tournament == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Torneo no encontrado'),
        ),
      );
    }

    final name = _textValue('name');
    final date = _textValue('date');
    final location = _textValue('location');
    final type = _textValue('type');
    final mode = _textValue('mode');
    final category = _textValue('category');
    final prizes = _textValue('prizes', fallback: '');
    final inviteCode = _textValue('invite_code', fallback: '');
    final duration = _textValue('duration', fallback: '');
    final tieBreaker = _textValue('tie_breaker', fallback: '');
    final teamsCount = _textValue('teams_count', fallback: '');
    final cost = _textValue('cost', fallback: '');
    final hasReferees = _boolValue('has_referees');
    final hasOffside = _boolValue('has_offside');
    final hasCardSanctions = _boolValue('has_card_sanctions');
    final isOfficial = _boolValue('is_official');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del torneo'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTournament,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOfficial)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'Torneo oficial',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isOfficial) const SizedBox(height: 12),
                  Text(
                    name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          date,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.emoji_events_outlined, label: type),
                _InfoChip(icon: Icons.groups_outlined, label: mode),
                _InfoChip(icon: Icons.category_outlined, label: category),
                if (teamsCount.isNotEmpty)
                  _InfoChip(
                    icon: Icons.format_list_numbered,
                    label: '$teamsCount equipos',
                  ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Información general',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      title: 'Fecha de inicio',
                      value: date,
                    ),
                    const Divider(),
                    _DetailRow(
                      icon: Icons.place_outlined,
                      title: 'Ubicación',
                      value: location,
                    ),
                    const Divider(),
                    _DetailRow(
                      icon: Icons.sports_soccer_outlined,
                      title: 'Modalidad',
                      value: mode,
                    ),
                    const Divider(),
                    _DetailRow(
                      icon: Icons.shield_outlined,
                      title: 'Categoría',
                      value: category,
                    ),
                    if (cost.isNotEmpty) ...[
                      const Divider(),
                      _DetailRow(
                        icon: Icons.payments_outlined,
                        title: 'Costo de inscripción',
                        value: cost,
                      ),
                    ],
                    if (inviteCode.isNotEmpty) ...[
                      const Divider(),
                      _DetailRow(
                        icon: Icons.vpn_key_outlined,
                        title: 'Código de invitación',
                        value: inviteCode,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Reglas y configuración',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _RuleRow(
                      label: 'Con árbitros',
                      value: _hasValue('has_referees')
                          ? (hasReferees ? 'Sí' : 'No')
                          : '-',
                    ),
                    const Divider(),
                    _RuleRow(
                      label: 'Offside',
                      value: _hasValue('has_offside')
                          ? (hasOffside ? 'Sí' : 'No')
                          : '-',
                    ),
                    const Divider(),
                    _RuleRow(
                      label: 'Sanciones por tarjetas',
                      value: _hasValue('has_card_sanctions')
                          ? (hasCardSanctions ? 'Sí' : 'No')
                          : '-',
                    ),
                    if (duration.isNotEmpty) ...[
                      const Divider(),
                      _RuleRow(
                        label: 'Duración del partido',
                        value: duration,
                      ),
                    ],
                    if (tieBreaker.isNotEmpty) ...[
                      const Divider(),
                      _RuleRow(
                        label: 'Desempate',
                        value: tieBreaker,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (prizes.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Premios',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.workspace_premium_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          prizes,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showSnackBar('La inscripción la conectamos en el siguiente paso');
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text('Inscribirme'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showSnackBar('La función compartir la conectamos después');
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartir torneo'),
                  ),
                ),
              ],
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
    if (label.trim().isEmpty || label.trim() == '-') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  final String label;
  final String value;

  const _RuleRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}