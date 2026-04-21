import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/player_review_service.dart';
import '../../data/player_stats_service.dart';

class PlayerPublicProfilePage extends StatefulWidget {
  final String userId;

  const PlayerPublicProfilePage({
    super.key,
    required this.userId,
  });

  @override
  State<PlayerPublicProfilePage> createState() =>
      _PlayerPublicProfilePageState();
}

class _PlayerPublicProfilePageState extends State<PlayerPublicProfilePage> {
  final PlayerStatsService _statsService = PlayerStatsService();
  final PlayerReviewService _reviewService = PlayerReviewService();

  bool isLoading = true;

  String fullName = 'Jugador';
  String role = 'player';
  String? avatarUrl;
  String publicCode = '';

  int totalGoals = 0;
  int totalMatches = 0;
  int totalMvp = 0;

  double avgPunctuality = 0;
  double avgBehavior = 0;
  double avgCommitment = 0;

  List<Map<String, dynamic>> stats = [];
  List<Map<String, dynamic>> reviews = [];

  @override
  void initState() {
    super.initState();
    _loadPlayer();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _loadPlayer() async {
    try {
      final client = Supabase.instance.client;

      final profile = await client
          .from('profiles')
          .select('full_name, role, avatar_url, public_code')
          .eq('id', widget.userId)
          .maybeSingle();

      final statsData =
          await _statsService.getPlayerStatsWithTournamentNames(widget.userId);
      final reviewsData = await _reviewService.getReviewsForUser(widget.userId);

      int goals = 0;
      int matches = 0;
      int mvp = 0;

      for (final stat in statsData) {
        goals += (stat['goals'] ?? 0) as int;
        matches += (stat['matches_played'] ?? 0) as int;
        mvp += (stat['mvp'] ?? 0) as int;
      }

      double punctuality = 0;
      double behavior = 0;
      double commitment = 0;

      if (reviewsData.isNotEmpty) {
        for (final review in reviewsData) {
          punctuality += ((review['punctuality'] ?? 0) as num).toDouble();
          behavior += ((review['behavior'] ?? 0) as num).toDouble();
          commitment += ((review['commitment'] ?? 0) as num).toDouble();
        }

        punctuality /= reviewsData.length;
        behavior /= reviewsData.length;
        commitment /= reviewsData.length;
      }

      _safeSetState(() {
        fullName = (profile?['full_name'] ?? 'Jugador').toString();
        role = (profile?['role'] ?? 'player').toString();
        avatarUrl = profile?['avatar_url']?.toString();
        publicCode = (profile?['public_code'] ?? '').toString();

        stats = statsData;
        reviews = reviewsData;

        totalGoals = goals;
        totalMatches = matches;
        totalMvp = mvp;

        avgPunctuality = punctuality;
        avgBehavior = behavior;
        avgCommitment = commitment;

        isLoading = false;
      });
    } catch (_) {
      _safeSetState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _copyCode() async {
    if (publicCode.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: publicCode));
    _showSnackBar('Código copiado');
  }

  int _calculateOverall() {
    final attackScore = (totalGoals * 2.4) + (totalMvp * 4.5);
    final activityScore = (totalMatches * 1.8) + (stats.length * 3);
    final reviewScore = reviews.isEmpty
        ? 50.0
        : ((avgPunctuality + avgBehavior + avgCommitment) / 3) * 20.0;

    final overall =
        (attackScore * 0.40) + (activityScore * 0.35) + (reviewScore * 0.25);

    return overall.clamp(50, 99).round();
  }

  String _roleLabel() {
    switch (role) {
      case 'super_admin':
        return 'Super administrador';
      case 'admin':
        return 'Administrador';
      case 'organizer':
        return 'Organizador';
      case 'venue':
        return 'Cancha';
      case 'player':
      default:
        return 'Jugador';
    }
  }

  String _formatScore(double value) {
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overall = _calculateOverall();
    final recentReviews = reviews.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del jugador'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF183A4F),
                        Color(0xFF224B63),
                        Color(0xFF2C5C73),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC52E),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$overall',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    color: Colors.black,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'GRL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (publicCode.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    publicCode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: _copyCode,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.copy,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Copiar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white10,
                        backgroundImage:
                            avatarUrl != null && avatarUrl!.trim().isNotEmpty
                                ? NetworkImage(avatarUrl!)
                                : null,
                        child: avatarUrl == null || avatarUrl!.trim().isEmpty
                            ? Text(
                                fullName.isNotEmpty
                                    ? fullName[0].toUpperCase()
                                    : 'J',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        fullName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _roleLabel(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _HeaderStat(label: 'PJ', value: '$totalMatches'),
                            _HeaderStat(label: 'G', value: '$totalGoals'),
                            _HeaderStat(label: 'MVP', value: '$totalMvp'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _SectionHeader(
                  title: 'Resumen general',
                  subtitle: 'Sus números principales dentro de la app',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Partidos',
                        value: '$totalMatches',
                        icon: Icons.sports_soccer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Goles',
                        value: '$totalGoals',
                        icon: Icons.ads_click,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'MVP',
                        value: '$totalMvp',
                        icon: Icons.emoji_events,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Torneos',
                        value: '${stats.length}',
                        icon: Icons.shield_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Reputación',
                  subtitle: 'Cómo lo valoran otros jugadores y organizadores',
                ),
                const SizedBox(height: 14),
                if (reviews.isEmpty)
                  const _EmptyCard(
                    text: 'Todavía no tiene valoraciones cargadas.',
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Puntualidad',
                          value: _formatScore(avgPunctuality),
                          icon: Icons.schedule,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Conducta',
                          value: _formatScore(avgBehavior),
                          icon: Icons.handshake_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Compromiso',
                          value: _formatScore(avgCommitment),
                          icon: Icons.favorite_border,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Reviews',
                          value: '${reviews.length}',
                          icon: Icons.rate_review_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Comentarios recientes',
                  subtitle: 'Lo último que dejaron sobre su desempeño',
                ),
                const SizedBox(height: 14),
                if (recentReviews.isEmpty)
                  const _EmptyCard(
                    text: 'Todavía no hay comentarios.',
                  )
                else
                  ...recentReviews.map(
                    (review) => _GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (review['reviewer_name'] ?? 'Jugador').toString(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MiniBadge(
                                  label: 'Punt.',
                                  value: '${review['punctuality'] ?? 0}',
                                ),
                                _MiniBadge(
                                  label: 'Cond.',
                                  value: '${review['behavior'] ?? 0}',
                                ),
                                _MiniBadge(
                                  label: 'Comp.',
                                  value: '${review['commitment'] ?? 0}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              (review['comment'] == null ||
                                      review['comment']
                                          .toString()
                                          .trim()
                                          .isEmpty)
                                  ? 'Sin comentario'
                                  : review['comment'].toString(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const _GlassCard({
    required this.child,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final String value;

  const _MiniBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }
}