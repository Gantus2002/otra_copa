import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../admin/presentation/pages/create_tournament_page.dart';
import '../../../admin/presentation/pages/select_tournament_page.dart';
import '../../../invite/presentation/pages/join_by_code_page.dart';
import '../../../location/presentation/pages/location_page.dart';
import '../../../my_tournaments/presentation/pages/my_tournaments_page.dart';
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

  List<Map<String, dynamic>> banners = [];
  Map<String, dynamic>? ad;

  bool loading = true;
  int currentBanner = 0;

  @override
  void initState() {
    super.initState();
    _load();
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
    } catch (e) {
      _safeSetState(() {
        loading = false;
      });
      _showSnackBar('Error cargando contenido del inicio');
    }
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
          builder: (_) => TournamentsPage(
            selectedCity: widget.selectedCity,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Otra Copa'),
        actions: [
          IconButton(
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
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Bienvenido',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.selectedCity}, Paraguay',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (banners.isNotEmpty) ...[
                    SizedBox(
                      height: 160,
                      child: PageView.builder(
                        itemCount: banners.length,
                        onPageChanged: (i) {
                          _safeSetState(() {
                            currentBanner = i;
                          });
                        },
                        itemBuilder: (_, i) {
                          final banner = banners[i];

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _handleBannerTap(banner),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      banner['image_url']?.toString() ?? '',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.black12,
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'No se pudo cargar la imagen',
                                        ),
                                      ),
                                    ),
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black54,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      bottom: 12,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            banner['title']?.toString() ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            banner['subtitle']?.toString() ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        banners.length,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: currentBanner == i ? 10 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: currentBanner == i
                                ? theme.colorScheme.primary
                                : Colors.grey,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
                    children: [
                      _card(Icons.add, 'Crear torneo', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateTournamentPage(),
                          ),
                        );
                      }),
                      _card(Icons.search, 'Buscar torneo', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TournamentsPage(
                              selectedCity: widget.selectedCity,
                            ),
                          ),
                        );
                      }),
                      _card(Icons.vpn_key, 'Ingresar código', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JoinByCodePage(),
                          ),
                        );
                      }),
                      _card(Icons.admin_panel_settings, 'Solicitudes', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SelectTournamentPage(),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (ad != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        ad!['image_url']?.toString() ?? '',
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          alignment: Alignment.center,
                          color: Colors.black12,
                          child: const Text('No se pudo cargar el anuncio'),
                        ),
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
                          leading: const Icon(Icons.list),
                          title: const Text('Mis torneos'),
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
                          leading: const Icon(Icons.location_city),
                          title: const Text('Cambiar ciudad'),
                          subtitle: Text(widget.selectedCity),
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
    );
  }

  Widget _card(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 8),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}