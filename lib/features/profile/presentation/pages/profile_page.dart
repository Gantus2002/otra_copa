import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../admin/presentation/pages/admin_reservations_page.dart';
import '../../../auth/data/auth_service.dart';
import '../../../../core/widgets/app_bar_with_notifications.dart';
import '../../../player/data/player_review_service.dart';
import '../../../player/data/player_stats_service.dart';
import '../../../player/presentation/pages/player_search_page.dart';
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
  String publicCode = '';

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

  Future<void> _copyCode() async {
    if (publicCode.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: publicCode));
    _showSnackBar('Código copiado');
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
          .select('full_name, role, avatar_url, public_code')
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
        publicCode = (profile?['public_code'] ?? '').toString();
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

  int _calculateOverall() {
    final attackScore = math.min(99.0, totalGoals * 2.4 + totalMvp * 4.5);
    final activityScore = math.min(99.0, totalMatches * 1.8 + stats.length * 3);
    final reviewScore = reviews.isEmpty
        ? 50.0
        : ((avgPunctuality + avgBehavior + avgCommitment) / 3) * 20.0;

    final overall =
        (attackScore * 0.40) + (activityScore * 0.35) + (reviewScore * 0.25);

    return overall.clamp(50, 99).round();
  }

  String _countryFlag() {
    return '🇵🇾';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentReviews = reviews.take(3).toList();
    final overall = _calculateOverall();

    return Scaffold(
      appBar: const AppBarWithNotifications(title: 'Mi perfil'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _FifaStyleProfileCard(
                    fullName: fullName,
                    roleLabel: _roleLabel(),
                    flag: _countryFlag(),
                    avatarUrl: avatarUrl,
                    overall: overall,
                    totalMatches: totalMatches,
                    totalGoals: totalGoals,
                    totalMvp: totalMvp,
                    isUploadingAvatar: isUploadingAvatar,
                    onAvatarTap: isUploadingAvatar ? null : _pickAndUploadAvatar,
                    publicCode: publicCode,
                    onCopyCode: _copyCode,
                  ),
                  const SizedBox(height: 18),
                  _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
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
                                  _roleIcon(),
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Perfil competitivo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            _roleLabel(),
                                            style: TextStyle(
                                              color: theme.colorScheme.onSecondaryContainer,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(14),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const PlayerSearchPage(),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.search,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Buscar jugadores',
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
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
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

class _FifaStyleProfileCard extends StatelessWidget {
  final String fullName;
  final String roleLabel;
  final String flag;
  final String? avatarUrl;
  final int overall;
  final int totalMatches;
  final int totalGoals;
  final int totalMvp;
  final bool isUploadingAvatar;
  final VoidCallback? onAvatarTap;
  final String publicCode;
  final Future<void> Function() onCopyCode;

  const _FifaStyleProfileCard({
    required this.fullName,
    required this.roleLabel,
    required this.flag,
    required this.avatarUrl,
    required this.overall,
    required this.totalMatches,
    required this.totalGoals,
    required this.totalMvp,
    required this.isUploadingAvatar,
    required this.onAvatarTap,
    required this.publicCode,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
                    const SizedBox(height: 3),
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
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: ClipOval(
                    child: avatarUrl != null && avatarUrl!.isNotEmpty
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
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
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
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: isUploadingAvatar
                        ? const Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.black,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            roleLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          if (publicCode.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
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
                  onTap: onCopyCode,
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
                          'Copiar código',
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CardStat(label: 'PJ', value: '$totalMatches'),
                _CardStat(label: 'G', value: '$totalGoals'),
                _CardStat(label: 'MVP', value: '$totalMvp'),
              ],
            ),
          ),
        ],
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
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

class _CardStat extends StatelessWidget {
  final String label;
  final String value;

  const _CardStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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