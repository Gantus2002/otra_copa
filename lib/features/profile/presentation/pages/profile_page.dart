import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../admin/presentation/pages/admin_reservations_page.dart';
import '../../../auth/data/auth_service.dart';
import '../../../player/data/player_review_service.dart';
import '../../../player/data/player_stats_service.dart';
import '../../../venue/presentation/pages/venue_dashboard_page.dart';

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
  final ImagePicker _picker = ImagePicker();

  bool isLoading = true;
  bool isUploadingAvatar = false;

  List<Map<String, dynamic>> stats = [];
  List<Map<String, dynamic>> reviews = [];

  String fullName = 'Jugador';
  String email = '';
  String role = 'player';
  String? avatarUrl;

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

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      _safeSetState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final profile = await client
          .from('profiles')
          .select('full_name, role, avatar_url')
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

      _safeSetState(() {
        fullName = (profile?['full_name'] ?? 'Jugador').toString();
        role = (profile?['role'] ?? 'player').toString();
        avatarUrl = profile?['avatar_url']?.toString();
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
      _safeSetState(() {
        email = user.email ?? '';
        isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      _safeSetState(() {
        isUploadingAvatar = true;
      });

      final file = File(picked.path);
      final fileExt = picked.path.split('.').last.toLowerCase();
      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage.from('profile-images').upload(
            fileName,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('profile-images')
          .getPublicUrl(fileName);

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': publicUrl}).eq('id', user.id);

      _safeSetState(() {
        avatarUrl = publicUrl;
      });

      _showSnackBar('Foto de perfil actualizada');
    } catch (e) {
      _showSnackBar('Error subiendo foto: $e');
    } finally {
      _safeSetState(() {
        isUploadingAvatar = false;
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

  IconData _roleIcon() {
    switch (role) {
      case 'super_admin':
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'organizer':
        return Icons.emoji_events_outlined;
      case 'venue':
        return Icons.stadium_outlined;
      case 'player':
      default:
        return Icons.sports_soccer_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentReviews = reviews.take(3).toList();
    final isDark = theme.brightness == Brightness.dark;

    final headerStart = isDark
        ? const Color(0xFF0D6D67)
        : theme.colorScheme.primary.withOpacity(0.82);
    final headerEnd = isDark
        ? const Color(0xFF2D8F87)
        : theme.colorScheme.primaryContainer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [headerStart, headerEnd],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.18 : 0.10),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap:
                                  isUploadingAvatar ? null : _pickAndUploadAvatar,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      Colors.white.withOpacity(isDark ? 0.16 : 0.20),
                                  border: Border.all(
                                    color: Colors.white
                                        .withOpacity(isDark ? 0.10 : 0.18),
                                  ),
                                ),
                                child: ClipOval(
                                  child: avatarUrl != null &&
                                          avatarUrl!.trim().isNotEmpty
                                      ? Image.network(
                                          avatarUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(
                                              fullName.isNotEmpty
                                                  ? fullName[0].toUpperCase()
                                                  : 'J',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 28,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            fullName.isNotEmpty
                                                ? fullName[0].toUpperCase()
                                                : 'J',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 28,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.05),
                                  ),
                                ),
                                child: isUploadingAvatar
                                    ? const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Colors.black87,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                email,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.82),
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _ProfileBadge(
                                    icon: _roleIcon(),
                                    label: _roleLabel(),
                                    isDarkHeader: true,
                                  ),
                                  _ProfileBadge(
                                    icon: Icons.workspace_premium_outlined,
                                    label: role == 'player'
                                        ? 'Currículum deportivo'
                                        : 'Perfil destacado',
                                    isDarkHeader: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Tocá la foto para cambiarla',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _GlassCard(
                    child: SwitchListTile(
                      value: widget.isDarkMode,
                      onChanged: widget.onThemeChanged,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      title: const Text(
                        'Modo oscuro',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        widget.isDarkMode ? 'Activado' : 'Desactivado',
                      ),
                      secondary: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.dark_mode_outlined,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _SectionHeader(
                    title: 'Resumen general',
                    subtitle: 'Tus números principales dentro de la app',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PremiumStatCard(
                          title: 'Partidos',
                          value: totalMatches.toString(),
                          icon: Icons.sports_soccer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PremiumStatCard(
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
                        child: _PremiumStatCard(
                          title: 'MVP',
                          value: totalMvp.toString(),
                          icon: Icons.emoji_events,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PremiumStatCard(
                          title: 'Torneos',
                          value: stats.length.toString(),
                          icon: Icons.shield_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _SectionHeader(
                    title: 'Reputación',
                    subtitle: 'Cómo te valoran otros jugadores y organizadores',
                  ),
                  const SizedBox(height: 14),
                  if (reviews.isEmpty)
                    const _EmptyCard(
                      text: 'Todavía no tenés valoraciones cargadas.',
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _PremiumStatCard(
                            title: 'Puntualidad',
                            value: _formatScore(avgPunctuality),
                            icon: Icons.schedule,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PremiumStatCard(
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
                          child: _PremiumStatCard(
                            title: 'Compromiso',
                            value: _formatScore(avgCommitment),
                            icon: Icons.favorite_border,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PremiumStatCard(
                            title: 'Reviews',
                            value: reviews.length.toString(),
                            icon: Icons.rate_review_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 26),
                  _SectionHeader(
                    title: 'Historial por torneo',
                    subtitle: 'Tus estadísticas desglosadas por competencia',
                  ),
                  const SizedBox(height: 14),
                  if (stats.isEmpty)
                    const _EmptyCard(
                      text: 'Todavía no tenés estadísticas cargadas en torneos.',
                    )
                  else
                    ...stats.map(
                      (stat) => _GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stat['tournament_name']?.toString() ?? 'Torneo',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
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
                  const SizedBox(height: 26),
                  _SectionHeader(
                    title: 'Comentarios recientes',
                    subtitle: 'Lo último que dejaron sobre tu desempeño',
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ReviewerAvatar(
                                name: (review['reviewer_name'] ?? 'Jugador')
                                    .toString(),
                                avatarUrl:
                                    review['reviewer_avatar_url']?.toString(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (review['reviewer_name'] ?? 'Jugador')
                                          .toString(),
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _MiniBadge(
                                          label: 'Punt.',
                                          value:
                                              '${review['punctuality'] ?? 0}',
                                        ),
                                        _MiniBadge(
                                          label: 'Cond.',
                                          value:
                                              '${review['behavior'] ?? 0}',
                                        ),
                                        _MiniBadge(
                                          label: 'Comp.',
                                          value:
                                              '${review['commitment'] ?? 0}',
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
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  if (role == 'super_admin' || role == 'admin') ...[
                    _ActionTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Panel Admin',
                      subtitle: 'Gestionar verificaciones y panel interno',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminDashboardPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _ActionTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Todas las reservas',
                      subtitle: 'Ver y controlar reservas de toda la app',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminReservationsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (role == 'venue') ...[
                    _ActionTile(
                      icon: Icons.stadium_outlined,
                      title: 'Panel de cancha',
                      subtitle: 'Gestionar complejo, canchas, horarios y reservas',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VenueDashboardPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ActionTile(
                    icon: Icons.logout,
                    title: 'Cerrar sesión',
                    subtitle: 'Salir de tu cuenta de forma segura',
                    danger: true,
                    onTap: _signOut,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReviewerAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _ReviewerAvatar({
    required this.name,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'J';

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: Colors.transparent,
        child: ClipOval(
          child: Image.network(
            avatarUrl!,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return CircleAvatar(
                radius: 22,
                child: Text(initial),
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 22,
      child: Text(initial),
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
            letterSpacing: -0.2,
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? theme.colorScheme.surface.withOpacity(0.72)
            : theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant
              .withOpacity(isDark ? 0.18 : 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.08 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PremiumStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _PremiumStatCard({
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
                letterSpacing: -0.4,
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

class _ProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDarkHeader;

  const _ProfileBadge({
    required this.icon,
    required this.label,
    required this.isDarkHeader,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkHeader
        ? Colors.white.withOpacity(0.92)
        : Theme.of(context).colorScheme.surface;

    final fgColor = isDarkHeader
        ? const Color(0xFF0B1A1A)
        : Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final iconBg = danger
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;

    final iconColor = danger
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    return _GlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
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