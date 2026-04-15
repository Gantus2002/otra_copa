import 'package:flutter/material.dart';
import '../../../my_tournaments/presentation/pages/my_tournaments_page.dart';
import '../../../tournaments/presentation/pages/tournaments_page.dart';
import '../../../admin/presentation/pages/create_tournament_page.dart';
import '../../../admin/presentation/pages/select_tournament_page.dart';
import '../../../location/presentation/pages/location_page.dart';
import '../../../invite/presentation/pages/join_by_code_page.dart';
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
  final HomeContentService _homeContentService = HomeContentService();

  List<Map<String, dynamic>> banners = [];
  Map<String, dynamic>? ad;
  bool loadingContent = true;

  @override
  void initState() {
    super.initState();
    _loadHomeContent();
  }

  Future<void> _loadHomeContent() async {
    try {
      final bannersData = await _homeContentService.getActiveBanners();
      final adData = await _homeContentService.getActiveAd();

      setState(() {
        banners = bannersData;
        ad = adData;
      });
    } finally {
      setState(() {
        loadingContent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Otra Copa'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.location_on_outlined),
              onPressed: () {
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
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHomeContent,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Hola',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.selectedCity}, Paraguay',
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 20),

              if (loadingContent)
                const Center(child: CircularProgressIndicator())
              else if (banners.isNotEmpty) ...[
                SizedBox(
                  height: 155,
                  child: PageView.builder(
                    itemCount: banners.length,
                    controller: PageController(viewportFraction: 0.94),
                    itemBuilder: (context, index) {
                      final banner = banners[index];

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                banner['image_url']?.toString() ?? '',
                                fit: BoxFit.cover,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.65),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 14,
                                right: 14,
                                bottom: 14,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      banner['title']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if ((banner['subtitle'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                      Text(
                                        banner['subtitle'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Text(
                'Accesos rápidos',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.35,
                children: [
                  _QuickAccessCard(
                    icon: Icons.add_circle_outline,
                    title: 'Crear torneo',
                    subtitle: 'Armá un torneo nuevo',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateTournamentPage(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessCard(
                    icon: Icons.search,
                    title: 'Buscar torneo',
                    subtitle: 'Explorá torneos',
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
                  _QuickAccessCard(
                    icon: Icons.vpn_key_outlined,
                    title: 'Ingresar código',
                    subtitle: 'Unite a un torneo',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const JoinByCodePage(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Solicitudes',
                    subtitle: 'Gestioná tus torneos',
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

              const SizedBox(height: 24),

              Text(
                'Tu actividad',
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
                      const Icon(
                        Icons.sports_soccer,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Todavía no mostramos resumen automático en Inicio.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Por ahora usá Mis torneos, Solicitudes y tu Perfil para ver tu información real.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (!loadingContent && ad != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    ad!['image_url']?.toString() ?? '',
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Text(
                'Más opciones',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.list_alt_outlined),
                      title: const Text('Mis torneos'),
                      subtitle: const Text('Ver torneos en los que participás'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyTournamentsPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.location_city_outlined),
                      title: const Text('Cambiar ciudad'),
                      subtitle: Text(widget.selectedCity),
                      trailing: const Icon(Icons.chevron_right),
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}