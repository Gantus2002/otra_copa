import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/venue_review_service.dart';
import 'court_reservation_page.dart';
import 'venue_review_page.dart';
import 'venue_reviews_page.dart';

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
  final VenueReviewService _reviewService = VenueReviewService();

  Map<String, dynamic>? venue;
  List<Map<String, dynamic>> courts = [];
  List<Map<String, dynamic>> reviews = [];

  bool isLoading = true;
  bool hasUserReview = false;
  double avgRating = 0;
  int totalReviews = 0;

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
    _safeSetState(() {
      isLoading = true;
    });

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
      });

      await _loadReviewsData(showError: false);

      _safeSetState(() {
        isLoading = false;
      });
    } catch (e) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('Error cargando cancha');
    }
  }

  Future<void> _loadReviewsData({bool showError = true}) async {
    try {
      final topReviews = await _reviewService.getTopReviews(widget.venueId);
      final stats = await _reviewService.getStats(widget.venueId);
      final reviewed = await _reviewService.hasUserReviewed(widget.venueId);

      _safeSetState(() {
        reviews = topReviews;
        avgRating = (stats['avg'] as num).toDouble();
        totalReviews = stats['count'] as int;
        hasUserReview = reviewed;
      });
    } catch (e) {
      _safeSetState(() {
        reviews = [];
        avgRating = 0;
        totalReviews = 0;
        hasUserReview = false;
      });

      if (showError) {
        _showSnackBar('No se pudieron cargar las reseñas');
      }
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

  Future<void> _openReviewPage() async {
    if (venue == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VenueReviewPage(
          venueId: widget.venueId,
          venueName: (venue!['name'] ?? 'Complejo').toString(),
        ),
      ),
    );

    if (result == true) {
      await _loadReviewsData();
    }
  }

  Future<void> _openAllReviewsPage() async {
    if (venue == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueReviewsPage(
          venueId: widget.venueId,
          venueName: (venue!['name'] ?? 'Complejo').toString(),
        ),
      ),
    );

    await _loadReviewsData(showError: false);
  }

  void _shareVenue({
    required String venueName,
    required String venueCity,
    required String venueAddress,
  }) {
    Share.share(
      '⚽ Mirá este complejo en la app:\n\n'
      '$venueName\n'
      '${venueCity.isNotEmpty ? '$venueCity\n' : ''}'
      '${venueAddress.isNotEmpty ? '$venueAddress\n' : ''}',
    );
  }

  String _normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<void> _openWhatsApp(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) {
      _showSnackBar('Número de WhatsApp inválido');
      return;
    }

    final uri = Uri.parse('https://wa.me/$normalized');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showSnackBar('No se pudo abrir WhatsApp');
      }
    } catch (_) {
      _showSnackBar('No se pudo abrir WhatsApp');
    }
  }

  Future<void> _callPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) {
      _showSnackBar('Número de teléfono inválido');
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: normalized,
    );

    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        _showSnackBar('No se pudo abrir el teléfono');
      }
    } catch (_) {
      _showSnackBar('No se pudo abrir el teléfono');
    }
  }

  Future<void> _likeReview(int reviewId) async {
    try {
      await _reviewService.likeReview(reviewId);
      await _loadReviewsData();
      _showSnackBar('Like agregado');
    } catch (e) {
      _showSnackBar('No se pudo dar like');
    }
  }

  String _dateText(dynamic raw) {
    if (raw == null) return '';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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
                            _shareVenue(
                              venueName: venueName,
                              venueCity: venueCity,
                              venueAddress: venueAddress,
                            );
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
                          color:
                              theme.colorScheme.outlineVariant.withOpacity(0.22),
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
                    'Reseñas',
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
                        color:
                            theme.colorScheme.outlineVariant.withOpacity(0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($totalReviews reseña${totalReviews == 1 ? '' : 's'})',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!hasUserReview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openReviewPage,
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Valorar complejo'),
                        ),
                      ),
                    ),
                  if (hasUserReview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        child: const Text(
                          'Ya dejaste una reseña para este complejo.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  if (reviews.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color:
                              theme.colorScheme.outlineVariant.withOpacity(0.22),
                        ),
                      ),
                      child: const Text('Todavía no hay reseñas'),
                    )
                  else
                    ...reviews.map(
                      (review) => _FeaturedReviewCard(
                        review: review,
                        dateText: _dateText(review['created_at']),
                        onLike: () => _likeReview(review['id'] as int),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _openAllReviewsPage,
                      child: const Text('Ver todas las reseñas'),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                          color:
                              theme.colorScheme.outlineVariant.withOpacity(0.22),
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
                      onTap: () => _openWhatsApp(whatsapp),
                    ),
                  if (phone.isNotEmpty) ...[
                    if (whatsapp.isNotEmpty) const SizedBox(height: 12),
                    _ContactTile(
                      icon: Icons.phone_outlined,
                      title: 'Teléfono',
                      subtitle: phone,
                      onTap: () => _callPhone(phone),
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

class _FeaturedReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final String dateText;
  final VoidCallback onLike;

  const _FeaturedReviewCard({
    required this.review,
    required this.dateText,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final comment = (review['comment'] ?? '').toString().trim();
    final rating = review['rating'] ?? 0;
    final likesCount = review['likes_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Usuario',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _RatingBadge(rating: rating),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment.isEmpty ? 'Sin comentario' : comment,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onLike,
              icon: const Icon(
                Icons.favorite_border,
                size: 18,
              ),
              label: Text('$likesCount'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final dynamic rating;

  const _RatingBadge({
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star,
            size: 16,
            color: Colors.amber,
          ),
          const SizedBox(width: 4),
          Text(
            '$rating',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
    final imageUrl = (court['image_url'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: SizedBox(
                height: 170,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
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
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
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
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
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