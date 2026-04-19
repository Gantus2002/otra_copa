import 'package:flutter/material.dart';

import '../../data/courts_remote_service.dart';
import 'venue_detail_page.dart';

class CourtsPage extends StatefulWidget {
  final String selectedCity;

  const CourtsPage({
    super.key,
    required this.selectedCity,
  });

  @override
  State<CourtsPage> createState() => _CourtsPageState();
}

class _CourtsPageState extends State<CourtsPage> {
  final CourtsRemoteService _service = CourtsRemoteService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> venues = [];
  List<Map<String, dynamic>> filteredVenues = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVenues();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
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

  Future<void> _loadVenues() async {
    _safeSetState(() {
      isLoading = true;
    });

    try {
      final result = await _service.getActiveVenues(
        city: widget.selectedCity,
      );

      _safeSetState(() {
        venues = result;
        filteredVenues = result;
        isLoading = false;
      });

      _applyFilter();
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando canchas');
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      _safeSetState(() {
        filteredVenues = venues;
      });
      return;
    }

    final result = venues.where((venue) {
      final name = (venue['name'] ?? '').toString().toLowerCase();
      final description = (venue['description'] ?? '').toString().toLowerCase();
      final address = (venue['address'] ?? '').toString().toLowerCase();
      final sportTypes = List<String>.from(venue['sport_types'] ?? []);

      return name.contains(query) ||
          description.contains(query) ||
          address.contains(query) ||
          sportTypes.any((type) => type.toLowerCase().contains(query));
    }).toList();

    _safeSetState(() {
      filteredVenues = result;
    });
  }

  String _priceText(Map<String, dynamic> venue) {
    final minPrice = venue['min_price'];

    if (minPrice == null) return 'Precio a confirmar';

    if (minPrice is num) {
      return 'Desde Gs. ${minPrice.toStringAsFixed(0)} / hora';
    }

    return 'Precio a confirmar';
  }

  void _openVenue(Map<String, dynamic> venue) {
    final venueId = venue['id'];

    if (venueId is! int) {
      _showSnackBar('ID de cancha inválido');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueDetailPage(
          venueId: venueId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canchas'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadVenues,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Text(
                    'Reservá tu cancha',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Explorá complejos y canchas disponibles en ${widget.selectedCity}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar cancha, complejo o deporte',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (filteredVenues.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.25),
                        ),
                      ),
                      child: const Text(
                        'Todavía no hay canchas cargadas para esta ciudad.',
                      ),
                    )
                  else
                    ...filteredVenues.map(
                      (venue) => _VenueCard(
                        venue: venue,
                        priceText: _priceText(venue),
                        onTap: () => _openVenue(venue),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  final Map<String, dynamic> venue;
  final String priceText;
  final VoidCallback onTap;

  const _VenueCard({
    required this.venue,
    required this.priceText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sportTypes = List<String>.from(venue['sport_types'] ?? []);
    final courtsCount = venue['courts_count'] ?? 0;

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
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 8,
                child: (venue['cover_image_url'] != null &&
                        venue['cover_image_url'].toString().trim().isNotEmpty)
                    ? Image.network(
                        venue['cover_image_url'].toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _FallbackCover(
                          title: venue['name']?.toString() ?? 'Cancha',
                        ),
                      )
                    : _FallbackCover(
                        title: venue['name']?.toString() ?? 'Cancha',
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue['name']?.toString() ?? 'Cancha',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    venue['address']?.toString().trim().isNotEmpty == true
                        ? venue['address'].toString()
                        : venue['city']?.toString() ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...sportTypes.take(3).map(
                            (type) => _SportChip(label: type),
                          ),
                      _SportChip(
                        label: '$courtsCount cancha${courtsCount == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          priceText,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Ver'),
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

class _FallbackCover extends StatelessWidget {
  final String title;

  const _FallbackCover({
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
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  final String label;

  const _SportChip({
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
        ),
      ),
    );
  }
}