import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_bar_with_notifications.dart';
import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../admin/presentation/pages/admin_reservations_page.dart';
import '../../../auth/data/auth_service.dart';
import '../../../player/data/player_review_service.dart';
import '../../../player/data/player_stats_service.dart';
import '../../../player/presentation/pages/player_search_page.dart';
import '../../../teams/presentation/pages/my_team_invitations_page.dart';
import '../../../teams/presentation/pages/my_teams_page.dart';
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
      _safeSetState(() => isLoading = false);
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
        imageQuality: 95,
      );

      if (picked == null) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar foto de perfil',
            toolbarColor: const Color(0xFF103B52),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFF1EC8B0),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Ajustar foto de perfil',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (cropped == null) return;

      _safeSetState(() => isUploadingAvatar = true);

      final file = File(cropped.path);
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

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

      _safeSetState(() => avatarUrl = publicUrl);
      _showSnackBar('Foto de perfil actualizada');
    } catch (e) {
      _showSnackBar('Error subiendo foto: $e');
    } finally {
      _safeSetState(() => isUploadingAvatar = false);
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  String _formatScore(double value) => value.toStringAsFixed(1);

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
    final hasStats = totalGoals > 0 || totalMatches > 0 || totalMvp > 0;
    final hasReviews = reviews.isNotEmpty;

    if (!hasStats && !hasReviews) return 0;

    final attackScore = math.min(99.0, totalGoals * 2.4 + totalMvp * 4.5);
    final activityScore = math.min(99.0, totalMatches * 1.8 + stats.length * 3);
    final reviewScore = hasReviews
        ? ((avgPunctuality + avgBehavior + avgCommitment) / 3) * 20.0
        : 0.0;

    final overall =
        (attackScore * 0.40) + (activityScore * 0.35) + (reviewScore * 0.25);

    return overall.clamp(0, 99).round();
  }

  String _countryFlag() {
    final text = '${email.toLowerCase()} ${publicCode.toLowerCase()}';

    if (text.contains('arg')) return '🇦🇷';
    if (text.contains('bra')) return '🇧🇷';
    if (text.contains('uru')) return '🇺🇾';
    if (text.contains('chi')) return '🇨🇱';
    return '🇵🇾';
  }

  double _reputationAverage() {
    if (reviews.isEmpty) return 0;
    return (avgPunctuality + avgBehavior + avgCommitment) / 3;
  }

  @override
  Widget build(BuildContext context) {
    final recentReviews = reviews.take(3).toList();
    final overall = _calculateOverall();
    final reputationAvg = _reputationAverage();

    return Scaffold(
      appBar: const AppBarWithNotifications(title: 'Mi perfil'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _ModernProfileHeader(
                    fullName: fullName,
                    roleLabel: _roleLabel(),
                    email: email,
                    flag: _countryFlag(),
                    overall: overall,
                    avatarUrl: avatarUrl,
                    publicCode: publicCode,
                    isUploadingAvatar: isUploadingAvatar,
                    onAvatarTap: isUploadingAvatar ? null : _pickAndUploadAvatar,
                    onCopyCode: _copyCode,
                    roleIcon: _roleIcon(),
                  ),
                  const SizedBox(height: 18),
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
                      secondary: const _SmallIconBox(
                        icon: Icons.dark_mode_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SectionHeader(
                    title: 'Accesos de perfil',
                    subtitle: 'Tu parte social, competitiva y de equipos',
                  ),
                  const SizedBox(height: 14),
                  _ProfileAccessGrid(
                    onSearchPlayers: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PlayerSearchPage(),
                        ),
                      );
                    },
                    onMyTeams: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyTeamsPage(),
                        ),
                      );
                    },
                    onInvitations: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyTeamInvitationsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  const _SectionHeader(
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
                  const _SectionHeader(
                    title: 'Perfil competitivo',
                    subtitle: 'Tu nivel general y rendimiento deportivo',
                  ),
                  const SizedBox(height: 14),
                  _GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _CompetitiveMetricRow(
                            label: 'Nivel general',
                            valueText:
                                overall == 0 ? 'Sin ranking' : '$overall GRL',
                            progress: overall == 0 ? 0 : overall / 100,
                          ),
                          const SizedBox(height: 14),
                          _CompetitiveMetricRow(
                            label: 'Promedio reputación',
                            valueText: reviews.isEmpty
                                ? 'Sin datos'
                                : '${reputationAvg.toStringAsFixed(1)}/5',
                            progress: reviews.isEmpty ? 0 : reputationAvg / 5,
                          ),
                          const SizedBox(height: 14),
                          _CompetitiveMetricRow(
                            label: 'Impacto ofensivo',
                            valueText: '$totalGoals goles',
                            progress: totalGoals == 0
                                ? 0
                                : (math.min(totalGoals.toDouble(), 20) / 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _SectionHeader(
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
                    const SizedBox(height: 16),
                    _GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _RatingBarRow(
                              label: 'Puntualidad',
                              value: avgPunctuality,
                            ),
                            const SizedBox(height: 12),
                            _RatingBarRow(
                              label: 'Conducta',
                              value: avgBehavior,
                            ),
                            const SizedBox(height: 12),
                            _RatingBarRow(
                              label: 'Compromiso',
                              value: avgCommitment,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  const _SectionHeader(
                    title: 'Estado por torneo',
                    subtitle: 'Tus estadísticas desglosadas por competencia',
                  ),
                  const SizedBox(height: 14),
                  if (stats.isEmpty)
                    const _EmptyCard(
                      text: 'Todavía no tenés estadísticas cargadas en torneos.',
                    )
                  else
                    ...stats.map(
                      (stat) => _TournamentStatusCard(stat: stat),
                    ),
                  const SizedBox(height: 26),
                  const _SectionHeader(
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
                      (review) => _CommentCard(review: review),
                    ),
                  const SizedBox(height: 22),
                  _ActionTile(
                    icon: Icons.groups_2_outlined,
                    title: 'Mis equipos',
                    subtitle:
                        'Creá tu equipo, invitá jugadores y administrá tus miembros',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyTeamsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Invitaciones de equipo',
                    subtitle:
                        'Aceptá o rechazá invitaciones a equipos persistentes',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyTeamInvitationsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
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
                      subtitle:
                          'Gestionar complejo, canchas, horarios y reservas',
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

class _ModernProfileHeader extends StatelessWidget {
  final String fullName;
  final String roleLabel;
  final String email;
  final String flag;
  final int overall;
  final String? avatarUrl;
  final String publicCode;
  final bool isUploadingAvatar;
  final VoidCallback? onAvatarTap;
  final Future<void> Function() onCopyCode;
  final IconData roleIcon;

  const _ModernProfileHeader({
    required this.fullName,
    required this.roleLabel,
    required this.email,
    required this.flag,
    required this.overall,
    required this.avatarUrl,
    required this.publicCode,
    required this.isUploadingAvatar,
    required this.onAvatarTap,
    required this.onCopyCode,
    required this.roleIcon,
  });

  @override
  Widget build(BuildContext context) {
    final overallText = overall == 0 ? '--' : '$overall';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F3144),
            Color(0xFF174B61),
            Color(0xFF1D6A77),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC930),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Text(
                      overallText,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'GRL',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                        color: Colors.white.withOpacity(0.08),
                      ),
                      child: ClipOval(
                        child: avatarUrl != null && avatarUrl!.isNotEmpty
                            ? Image.network(
                                avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _InitialAvatarText(value: fullName),
                              )
                            : _InitialAvatarText(value: fullName),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
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
                                Icons.photo_camera_outlined,
                                size: 15,
                                color: Colors.black,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.84),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileBadge(
                      icon: roleIcon,
                      label: roleLabel,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (publicCode.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            publicCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: onCopyCode,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileAccessGrid extends StatelessWidget {
  final VoidCallback onSearchPlayers;
  final VoidCallback onMyTeams;
  final VoidCallback onInvitations;

  const _ProfileAccessGrid({
    required this.onSearchPlayers,
    required this.onMyTeams,
    required this.onInvitations,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProfileAccessCard(
          icon: Icons.search,
          title: 'Buscar jugadores',
          subtitle: 'Encontrá jugadores por nombre o código',
          color: const Color(0xFF246BFD),
          large: true,
          onTap: onSearchPlayers,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 6,
              child: _ProfileAccessCard(
                icon: Icons.groups_2_outlined,
                title: 'Mis equipos',
                subtitle: 'Equipos',
                color: const Color(0xFF14B8A6),
                onTap: onMyTeams,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: _ProfileAccessCard(
                icon: Icons.mark_email_unread_outlined,
                title: 'Invitaciones',
                subtitle: 'Pendientes',
                color: const Color(0xFFF59E0B),
                compact: true,
                onTap: onInvitations,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool large;
  final bool compact;
  final VoidCallback onTap;

  const _ProfileAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.large = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = large ? 94.0 : 104.0;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.all(compact ? 13 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: compact ? 38 : 46,
              height: compact ? 38 : 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: compact ? 19 : 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 13 : 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 11 : 12,
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

class _InitialAvatarText extends StatelessWidget {
  final String value;

  const _InitialAvatarText({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final initial = value.trim().isNotEmpty ? value.trim()[0].toUpperCase() : 'J';

    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetitiveMetricRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double progress;

  const _CompetitiveMetricRow({
    required this.label,
    required this.valueText,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              valueText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: safeProgress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _RatingBarRow extends StatelessWidget {
  final String label;
  final double value;

  const _RatingBarRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 5.0);

    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: safeValue / 5,
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            safeValue.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _TournamentStatusCard extends StatelessWidget {
  final Map<String, dynamic> stat;

  const _TournamentStatusCard({
    required this.stat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SmallIconBox(icon: Icons.emoji_events_outlined),
            const SizedBox(width: 14),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _CommentCard({
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewerAvatar(
              name: (review['reviewer_name'] ?? 'Jugador').toString(),
              avatarUrl: review['reviewer_avatar_url']?.toString(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (review['reviewer_name'] ?? 'Jugador').toString(),
                    style: theme.textTheme.titleSmall?.copyWith(
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.8),
                    ),
                    child: Text(
                      (review['comment'] == null ||
                              review['comment'].toString().trim().isEmpty)
                          ? 'Sin comentario'
                          : review['comment'].toString(),
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
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
            _SmallIconBox(icon: icon),
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

class _SmallIconBox extends StatelessWidget {
  final IconData icon;

  const _SmallIconBox({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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