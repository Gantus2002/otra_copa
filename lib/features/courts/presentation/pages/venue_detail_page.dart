import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'court_reservation_page.dart';

class VenueDetailPage extends StatefulWidget {
  final int venueId;

  const VenueDetailPage({
    super.key,
    required this.venueId,
  });

  @override
  State<VenueDetailPage> createState() => _VenueDetailPageState();
}

class _VenueDetailPageState extends State<VenueDetailPage> {
  Map<String, dynamic>? venue;
  List<Map<String, dynamic>> courts = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVenue();
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

  Future<void> _loadVenue() async {
    try {
      final venueResponse = await Supabase.instance.client
          .from('venues')
          .select()
          .eq('id', widget.venueId)
          .single();

      final courtsResponse = await Supabase.instance.client
          .from('courts')
          .select()
          .eq('venue_id', widget.venueId)
          .eq('is_active', true)
          .order('id', ascending: true);

      _safeSetState(() {
        venue = Map<String, dynamic>.from(venueResponse);
        courts = List<Map<String, dynamic>>.from(courtsResponse);
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando cancha');
    }
  }

  void _openCourtReservation(Map<String, dynamic> court) {
    if (venue == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourtReservationPage(
          venue: venue!,
          court: court,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (venue == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Cancha no encontrada'),
        ),
      );
    }

    final venueName = (venue!['name'] ?? 'Cancha').toString();
    final venueAddress = (venue!['address'] ?? '').toString();
    final venueCity = (venue!['city'] ?? '').toString();
    final venueDescription = (venue!['description'] ?? '').toString();
    final coverImage = (venue!['cover_image_url'] ?? '').toString();
    final whatsapp = (venue!['whatsapp'] ?? '').toString();
    final phone = (venue!['phone'] ?? '').toString();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadVenue,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: coverImage.isNotEmpty
                      ? Image.network(
                          coverImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _HeaderFallback(
                            title: venueName,
                          ),
                        )
                      : _HeaderFallback(title: venueName),
                ),
                Container(
                  height: 280,
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
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        _TopIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _TopIconButton(
                          icon: Icons.share_outlined,
                          onTap: () {
                            _showSnackBar('La opción compartir la conectamos después');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venueName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              venueAddress.isNotEmpty
                                  ? '$venueAddress, $venueCity'
                                  : venueCity,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (venueDescription.isNotEmpty) ...[
                    Text(
                      'Sobre el complejo',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                        ),
                      ),
                      child: Text(
                        venueDescription,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                  Text(
                    'Canchas disponibles',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elegí una cancha para ver horarios y reservar.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (courts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                        ),
                      ),
                      child: const Text('Todavía no hay canchas cargadas.'),
                    )
                  else
                    ...courts.map(
                      (court) => _CourtCard(
                        court: court,
                        onReserve: () => _openCourtReservation(court),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Contacto',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (whatsapp.isNotEmpty)
                    _ContactTile(
                      icon: Icons.chat_bubble_outline,
                      title: 'WhatsApp',
                      subtitle: whatsapp,
                    ),
                  if (phone.isNotEmpty) ...[
                    if (whatsapp.isNotEmpty) const SizedBox(height: 12),
                    _ContactTile(
                      icon: Icons.phone_outlined,
                      title: 'Teléfono',
                      subtitle: phone,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourtCard extends StatelessWidget {
  final Map<String, dynamic> court;
  final VoidCallback onReserve;

  const _CourtCard({
    required this.court,
    required this.onReserve,
  });

  String _priceText(dynamic value) {
    if (value is num) {
      return 'Gs. ${value.toStringAsFixed(0)} / hora';
    }
    return 'Precio a confirmar';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final name = (court['name'] ?? 'Cancha').toString();
    final sportType = (court['sport_type'] ?? '').toString();
    final surfaceType = (court['surface_type'] ?? '').toString();
    final description = (court['description'] ?? '').toString();
    final isIndoor = court['is_indoor'] == true;
    final price = _priceText(court['price_per_hour']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (sportType.isNotEmpty) _VenueChip(label: sportType),
              if (surfaceType.isNotEmpty) _VenueChip(label: surfaceType),
              _VenueChip(label: isIndoor ? 'Indoor' : 'Outdoor'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            price,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onReserve,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Ver horarios'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VenueChip extends StatelessWidget {
  final String label;

  const _VenueChip({
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
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
        ),
      ),
      child: Row(
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.26),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _HeaderFallback extends StatelessWidget {
  final String title;

  const _HeaderFallback({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}