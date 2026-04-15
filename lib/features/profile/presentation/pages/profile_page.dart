import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/data/auth_service.dart';
import '../../../player/data/player_stats_service.dart';
import '../../../player/data/player_review_service.dart';
import '../../../admin/presentation/pages/admin_verification_page.dart';

class ProfilePage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const ProfilePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final PlayerStatsService _statsService = PlayerStatsService();
  final PlayerReviewService _reviewService = PlayerReviewService();

  bool isLoading = true;
  List<Map<String, dynamic>> stats = [];
  List<Map<String, dynamic>> reviews = [];

  String fullName = 'Jugador';
  String email = '';
  String role = 'player';

  int totalGoals = 0;
  int totalMatches = 0;
  int totalMvp = 0;

  double avgPunctuality = 0;
  double avgBehavior = 0;
  double avgCommitment = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final profile = await client
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .maybeSingle();

      final statsData =
          await _statsService.getPlayerStatsWithTournamentNames(user.id);
      final reviewsData = await _reviewService.getReviewsForUser(user.id);

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

      setState(() {
        fullName = (profile?['full_name'] ?? 'Jugador').toString();
        role = (profile?['role'] ?? 'player').toString();
        email = user.email ?? '';
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
      setState(() {
        email = user.email ?? '';
        isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  String _formatScore(double value) {
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentReviews = reviews.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: theme.colorScheme.primaryContainer,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            fullName.isNotEmpty
                                ? fullName[0].toUpperCase()
                                : 'J',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(email),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: theme.colorScheme.surface,
                                ),
                                child: Text(
                                  role == 'super_admin'
                                      ? 'Administrador'
                                      : 'Currículum deportivo',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Card(
                    child: SwitchListTile(
                      value: widget.isDarkMode,
                      onChanged: widget.onThemeChanged,
                      title: const Text('Modo oscuro'),
                      subtitle: Text(
                        widget.isDarkMode ? 'Activado' : 'Desactivado',
                      ),
                      secondary: const Icon(Icons.dark_mode_outlined),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Resumen general',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Partidos',
                          value: totalMatches.toString(),
                          icon: Icons.sports_soccer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Goles',
                          value: totalGoals.toString(),
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
                          value: totalMvp.toString(),
                          icon: Icons.emoji_events,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Torneos',
                          value: stats.length.toString(),
                          icon: Icons.shield_outlined,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Reputación',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (reviews.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Todavía no tenés valoraciones cargadas.'),
                      ),
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
                            value: reviews.length.toString(),
                            icon: Icons.rate_review_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  Text(
                    'Historial por torneo',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (stats.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Todavía no tenés estadísticas cargadas en torneos.',
                        ),
                      ),
                    )
                  else
                    ...stats.map(
                      (stat) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat['tournament_name']?.toString() ?? 'Torneo',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _MiniBadge(
                                    label: 'Partidos',
                                    value: '${stat['matches_played'] ?? 0}',
                                  ),
                                  _MiniBadge(
                                    label: 'Goles',
                                    value: '${stat['goals'] ?? 0}',
                                  ),
                                  _MiniBadge(
                                    label: 'MVP',
                                    value: '${stat['mvp'] ?? 0}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  Text(
                    'Comentarios recientes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (recentReviews.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Todavía no hay comentarios.'),
                      ),
                    )
                  else
                    ...recentReviews.map(
                      (review) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            (review['comment'] == null ||
                                    review['comment']
                                        .toString()
                                        .trim()
                                        .isEmpty)
                                ? 'Sin comentario'
                                : review['comment'].toString(),
                          ),
                        ),
                      ),
                    ),

                  if (role == 'super_admin') ...[
                    const SizedBox(height: 20),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: const Text('Panel Admin'),
                        subtitle: const Text('Gestionar verificaciones'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminVerificationPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Cerrar sesión'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _signOut,
                    ),
                  ),
                ],
              ),
            ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text('$label: $value'),
    );
  }
}