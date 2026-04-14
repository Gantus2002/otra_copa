import 'package:flutter/material.dart';
import '../../../my_tournaments/presentation/pages/my_tournaments_page.dart';
import '../../../tournaments/presentation/pages/tournaments_page.dart';
import '../../../admin/presentation/pages/admin_page.dart';
import '../../../admin/presentation/pages/create_tournament_page.dart';
import '../../../admin/presentation/pages/select_tournament_page.dart';
import '../../../location/presentation/pages/location_page.dart';
import '../../../invite/presentation/pages/join_by_code_page.dart';

class HomePage extends StatelessWidget {
  final String selectedCity;
  final ValueChanged<String> onCityChanged;

  const HomePage({
    super.key,
    required this.selectedCity,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Otra Copa'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.location_on_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationPage(
                      selectedCity: selectedCity,
                      onCitySelected: onCityChanged,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hola, Santino',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$selectedCity, Paraguay',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _QuickAccessCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'Mis torneos',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MyTournamentsPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAccessCard(
                    icon: Icons.search,
                    title: 'Buscar torneo',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TournamentsPage(
                            selectedCity: selectedCity,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAccessCard(
                    icon: Icons.add_circle_outline,
                    title: 'Crear torneo',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateTournamentPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              icon: Icons.vpn_key_outlined,
              title: 'Ingresar código',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const JoinByCodePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _QuickAccessCard(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Solicitudes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SelectTournamentPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Próximo partido',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Copa Universidad - Semifinal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Fecha: 20/04/2026'),
                    const Text('Hora: 21:00'),
                    Text('Lugar: $selectedCity'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Ver partido'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Destacados',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: const [
                  _BannerCard(
                    title: 'Torneo Apertura 2026',
                    subtitle: 'Inscripciones abiertas',
                  ),
                  SizedBox(width: 12),
                  _BannerCard(
                    title: 'Copa Facultades',
                    subtitle: 'Solo por invitación',
                  ),
                  SizedBox(width: 12),
                  _BannerCard(
                    title: 'Relámpago F5',
                    subtitle: 'Este fin de semana',
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

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _BannerCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}