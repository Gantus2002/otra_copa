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

  final PageController _bannerController =
      PageController(viewportFraction: 0.92);

  List<Map<String, dynamic>> banners = [];
  Map<String, dynamic>? ad;

  bool loading = true;
  int currentBanner = 0;

  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
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
                onRefresh: _load,
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
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LocationPage(
                                    selectedCity: widget.selectedCity,
                                    onCitySelected: widget.onCityChanged,
                                  ),
                                ),
                              );
                            },
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
                    const SizedBox(height: 24),

                    if (banners.isNotEmpty) ...[
                      _sectionTitle(
                        context,
                        'Destacados',
                        subtitle:
                            'Torneos, anuncios y novedades importantes',
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
                                        color:
                                            Colors.black.withOpacity(0.12),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(28),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          banner['image_url']
                                                  ?.toString() ??
                                              '',
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (_, __, ___) => Container(
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
                                              begin:
                                                  Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                Colors.black.withOpacity(
                                                    0.72),
                                                Colors.black.withOpacity(
                                                    0.10),
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
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration:
                                                    BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                              30),
                                                ),
                                                child: Text(
                                                  (banner['target_type']
                                                              ?.toString() ==
                                                          'tournament')
                                                      ? 'Torneo'
                                                      : 'Destacado',
                                                  style:
                                                      const TextStyle(
                                                    color:
                                                        Colors.white,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                  height: 10),
                                              Text(
                                                banner['title']
                                                        ?.toString() ??
                                                    '',
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style:
                                                    const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  height: 1.1,
                                                ),
                                              ),
                                              const SizedBox(
                                                  height: 6),
                                              Text(
                                                banner['subtitle']
                                                        ?.toString() ??
                                                    '',
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style:
                                                    const TextStyle(
                                                  color:
                                                      Colors.white70,
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
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: List.generate(
                          banners.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(
                                milliseconds: 220),
                            margin:
                                const EdgeInsets.symmetric(
                                    horizontal: 3),
                            width:
                                currentBanner == i ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: currentBanner == i
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme
                                      .outlineVariant,
                              borderRadius:
                                  BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    _sectionTitle(
                      context,
                      'Accesos rápidos',
                      subtitle:
                          'Entrá rápido a las funciones principales',
                    ),
                    const SizedBox(height: 14),

                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      childAspectRatio: 1.05,
                      physics:
                          const NeverScrollableScrollPhysics(),
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
                                builder: (_) =>
                                    const CreateTournamentPage(),
                              ),
                            );
                          },
                        ),
                        _premiumQuickCard(
                          context: context,
                          icon:
                              Icons.travel_explore_outlined,
                          title: 'Buscar torneo',
                          subtitle:
                              'Explorá torneos disponibles en tu ciudad',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TournamentsPage(
                                  selectedCity:
                                      widget.selectedCity,
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
                                builder: (_) =>
                                    const JoinByCodePage(),
                              ),
                            );
                          },
                        ),
                        _premiumQuickCard(
                          context: context,
                          icon:
                              Icons.pending_actions_outlined,
                          title: 'Solicitudes',
                          subtitle:
                              'Revisá accesos y solicitudes pendientes',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SelectTournamentPage(),
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
                          borderRadius:
                              BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(26),
                          child: Image.network(
                            ad!['image_url']
                                    ?.toString() ??
                                '',
                            height: 135,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Container(
                              height: 135,
                              alignment: Alignment.center,
                              color: theme
                                  .colorScheme
                                  .surfaceContainerHighest,
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
                      subtitle:
                          'Gestioná tu experiencia dentro de la app',
                    ),
                    const SizedBox(height: 14),

                    _secondaryActionTile(
                      context: context,
                      icon: Icons.list_alt_outlined,
                      title: 'Mis torneos',
                      subtitle:
                          'Revisá tus torneos activos y tu historial',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const MyTournamentsPage(),
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationPage(
                              selectedCity:
                                  widget.selectedCity,
                              onCitySelected:
                                  widget.onCityChanged,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}