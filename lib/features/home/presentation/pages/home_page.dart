import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../admin/presentation/pages/create_tournament_page.dart';
import '../../../admin/presentation/pages/select_tournament_page.dart';
import '../../../invite/presentation/pages/join_by_code_page.dart';
import '../../../location/presentation/pages/location_page.dart';
import '../../../my_tournaments/presentation/pages/my_tournaments_page.dart';
import '../../../tournament_detail/presentation/pages/tournament_detail_page.dart';
import '../../../tournaments/presentation/pages/tournaments_page.dart';
import '../../data/home_content_service.dart';
import '../../data/upcoming_service.dart';
import 'select_sport_page.dart';

class HomePage extends StatefulWidget {
  final String selectedCity;
  final ValueChanged<String> onCityChanged;

  const HomePage({
    super.key,
    required this.selectedCity,
    required this.onCityChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeContentService _service = HomeContentService();
  final UpcomingService _upcomingService = UpcomingService();

  final PageController _bannerController =
      PageController(viewportFraction: 0.92);

  List<Map<String, dynamic>> banners = [];
  Map<String, dynamic>? ad;
  List<Map<String, dynamic>> upcomingTournaments = [];

  bool loading = true;
  bool loadingUpcoming = true;
  int currentBanner = 0;
  String selectedSport = 'Fútbol';

  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _loadHomeContent();
    _loadUpcoming();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
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

  Future<void> _loadHomeContent() async {
    try {
      final b = await _service.getActiveBanners();
      final a = await _service.getActiveAd();

      _safeSetState(() {
        banners = b;
        ad = a;
        loading = false;

        if (currentBanner >= banners.length) {
          currentBanner = 0;
        }
      });

      _startBannerAutoScroll();
    } catch (_) {
      _safeSetState(() {
        loading = false;
      });

      _showSnackBar('Error cargando contenido del inicio');
    }
  }

  Future<void> _loadUpcoming() async {
    _safeSetState(() {
      loadingUpcoming = true;
    });

    try {
      final upcoming = await _upcomingService
          .getUpcomingTournaments()
          .timeout(const Duration(seconds: 8));

      _safeSetState(() {
        upcomingTournaments = upcoming;
        loadingUpcoming = false;
      });
    } catch (_) {
      _safeSetState(() {
        upcomingTournaments = [];
        loadingUpcoming = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadHomeContent(),
      _loadUpcoming(),
    ]);
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();

    if (banners.length <= 1) return;

    _bannerTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!mounted) return;
        if (!_bannerController.hasClients) return;
        if (banners.isEmpty) return;

        final nextPage = (currentBanner + 1) % banners.length;

        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final url = rawUrl.trim();

    if (url.isEmpty) {
      _showSnackBar('La URL está vacía');
      return;
    }

    Uri? uri = Uri.tryParse(url);

    if (uri == null) {
      _showSnackBar('La URL no es válida');
      return;
    }

    if (!uri.hasScheme) {
      uri = Uri.tryParse('https://$url');
    }

    if (uri == null) {
      _showSnackBar('La URL no es válida');
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      _showSnackBar('No se pudo abrir el link');
    }
  }

  Future<void> _handleBannerTap(Map<String, dynamic> banner) async {
    final type = banner['target_type']?.toString();
    final value = banner['target_value']?.toString();

    if (type == null || type.isEmpty || value == null || value.isEmpty) {
      _showSnackBar('Este banner no tiene destino configurado');
      return;
    }

    if (type == 'tournament') {
      final tournamentId = int.tryParse(value);

      if (tournamentId == null) {
        _showSnackBar('ID de torneo inválido');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDetailPage(
            tournamentId: tournamentId,
          ),
        ),
      );
      return;
    }

    if (type == 'external') {
      await _openExternalUrl(value);
      return;
    }

    _showSnackBar('Tipo de destino no soportado');
  }

  Future<void> _pickCity() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPage(
          selectedCity: widget.selectedCity,
        ),
      ),
    );

    if (result != null && result is String) {
      widget.onCityChanged(result);
    }
  }

  Future<void> _pickSport() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectSportPage(
          selectedSport: selectedSport,
        ),
      ),
    );

    if (result != null && result is String) {
      _safeSetState(() {
        selectedSport = result;
      });
    }
  }

  Widget _sectionTitle(
    BuildContext context,
    String title, {
    String? subtitle,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _premiumQuickCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _secondaryActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    final parts = text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  String _countdownText(DateTime? date) {
    if (date == null) return 'Fecha a confirmar';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) return 'Ya pasó';
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    return 'En $diff días';
  }

  String _formatDate(dynamic raw) {
    final date = _parseDate(raw);
    if (date == null) return 'Fecha a confirmar';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _upcomingSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          'Tus próximos torneos',
          subtitle: 'Recordatorios visibles de lo que se viene',
        ),
        const SizedBox(height: 14),
        if (loadingUpcoming)
          const Center(child: CircularProgressIndicator())
        else if (upcomingTournaments.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.event_busy_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Todavía no tenés torneos próximos o solicitudes activas.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          ...upcomingTournaments.map(
            (tournament) => _UpcomingTournamentCard(
              tournament: tournament,
              countdownText: _countdownText(_parseDate(tournament['start_date'])),
              formattedDate: _formatDate(tournament['start_date']),
              onTap: () {
                final tournamentId = tournament['id'];
                if (tournamentId is! int) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TournamentDetailPage(
                      tournamentId: tournamentId,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    28,
                  ),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.emoji_events,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _pickSport,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.sports_soccer,
                                color: selectedSport == 'Fútbol'
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Material(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _pickCity,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.location_on_outlined,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${widget.selectedCity}, Paraguay',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deporte: $selectedSport',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _upcomingSection(context),
                    const SizedBox(height: 28),

                    if (banners.isNotEmpty) ...[
                      _sectionTitle(
                        context,
                        'Destacados',
                        subtitle: 'Torneos, anuncios y novedades importantes',
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 210,
                        child: PageView.builder(
                          controller: _bannerController,
                          itemCount: banners.length,
                          onPageChanged: (i) {
                            _safeSetState(() {
                              currentBanner = i;
                            });
                          },
                          itemBuilder: (_, i) {
                            final banner = banners[i];

                            return Padding(
                              padding: EdgeInsets.only(
                                right: i == banners.length - 1 ? 0 : 10,
                              ),
                              child: GestureDetector(
                                onTap: () => _handleBannerTap(banner),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          banner['image_url']?.toString() ?? '',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: theme.colorScheme
                                                .surfaceContainerHighest,
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'No se pudo cargar la imagen',
                                            ),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                Colors.black.withOpacity(0.72),
                                                Colors.black.withOpacity(0.10),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 18,
                                          right: 18,
                                          bottom: 18,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.white.withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                ),
                                                child: Text(
                                                  (banner['target_type']
                                                              ?.toString() ==
                                                          'tournament')
                                                      ? 'Torneo'
                                                      : 'Destacado',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                banner['title']?.toString() ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                banner['subtitle']?.toString() ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                  height: 1.3,
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
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          banners.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: currentBanner == i ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: currentBanner == i
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    _sectionTitle(
                      context,
                      'Accesos rápidos',
                      subtitle: 'Entrá rápido a las funciones principales',
                    ),
                    const SizedBox(height: 14),

                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      childAspectRatio: 1.05,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _premiumQuickCard(
                          context: context,
                          icon: Icons.add_circle_outline,
                          title: 'Crear torneo',
                          subtitle:
                              'Publicá un torneo con tus reglas y modalidad',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateTournamentPage(),
                              ),
                            );
                          },
                        ),
                        _premiumQuickCard(
                          context: context,
                          icon: Icons.travel_explore_outlined,
                          title: 'Buscar torneo',
                          subtitle:
                              'Explorá torneos disponibles en tu ciudad',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TournamentsPage(
                                  selectedCity: widget.selectedCity,
                                ),
                              ),
                            );
                          },
                        ),
                        _premiumQuickCard(
                          context: context,
                          icon: Icons.vpn_key_outlined,
                          title: 'Ingresar código',
                          subtitle:
                              'Sumate rápido a un torneo por invitación',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const JoinByCodePage(),
                              ),
                            );
                          },
                        ),
                        _premiumQuickCard(
                          context: context,
                          icon: Icons.pending_actions_outlined,
                          title: 'Solicitudes',
                          subtitle:
                              'Revisá accesos y solicitudes pendientes',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SelectTournamentPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    if (ad != null) ...[
                      _sectionTitle(
                        context,
                        'Anuncio destacado',
                        subtitle:
                            'Contenido promocionado o información importante',
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.network(
                            ad!['image_url']?.toString() ?? '',
                            height: 135,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 135,
                              alignment: Alignment.center,
                              color:
                                  theme.colorScheme.surfaceContainerHighest,
                              child: const Text(
                                'No se pudo cargar el anuncio',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    _sectionTitle(
                      context,
                      'Más opciones',
                      subtitle: 'Gestioná tu experiencia dentro de la app',
                    ),
                    const SizedBox(height: 14),

                    _secondaryActionTile(
                      context: context,
                      icon: Icons.list_alt_outlined,
                      title: 'Mis torneos',
                      subtitle: 'Revisá tus torneos activos y tu historial',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyTournamentsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _secondaryActionTile(
                      context: context,
                      icon: Icons.location_city,
                      title: 'Cambiar ciudad',
                      subtitle: widget.selectedCity,
                      onTap: _pickCity,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _UpcomingTournamentCard extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final String countdownText;
  final String formattedDate;
  final VoidCallback onTap;

  const _UpcomingTournamentCard({
    required this.tournament,
    required this.countdownText,
    required this.formattedDate,
    required this.onTap,
  });

  String _requestTypeLabel(String value) {
    switch (value) {
      case 'team':
        return 'Vas con equipo';
      case 'player':
      default:
        return 'Vas como jugador';
    }
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'approved':
        return 'Aprobado';
      case 'accepted':
      case 'confirmed':
        return 'Confirmado';
      case 'pending':
      default:
        return 'Pendiente';
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'approved':
        return Colors.blue;
      case 'accepted':
      case 'confirmed':
        return Colors.green;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final name = (tournament['name'] ?? 'Torneo').toString();
    final location = (tournament['location'] ?? '').toString();
    final gameMode = (tournament['game_mode'] ?? '').toString();
    final category = (tournament['category'] ?? '').toString();
    final requestStatus = (tournament['request_status'] ?? '').toString();
    final requestType = (tournament['request_type'] ?? '').toString();
    final teamName = (tournament['team_name_snapshot'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 165,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            countdownText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(requestStatus).withOpacity(0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _statusLabel(requestStatus),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (gameMode.isNotEmpty)
                        _MiniTournamentChip(label: gameMode),
                      if (category.isNotEmpty)
                        _MiniTournamentChip(label: category),
                      _MiniTournamentChip(label: formattedDate),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _requestTypeLabel(requestType),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (requestType == 'team' && teamName.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Equipo: $teamName',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Estado: ${_statusLabel(requestStatus)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Ver torneo'),
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

class _MiniTournamentChip extends StatelessWidget {
  final String label;

  const _MiniTournamentChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}