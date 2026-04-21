import 'package:flutter/material.dart';

import '../../data/venue_review_service.dart';

class VenueReviewsPage extends StatefulWidget {
  final int venueId;
  final String venueName;

  const VenueReviewsPage({
    super.key,
    required this.venueId,
    required this.venueName,
  });

  @override
  State<VenueReviewsPage> createState() => _VenueReviewsPageState();
}

class _VenueReviewsPageState extends State<VenueReviewsPage> {
  final VenueReviewService _reviewService = VenueReviewService();

  bool isLoading = true;
  List<Map<String, dynamic>> reviews = [];
  double avgRating = 0;
  int totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _loadReviews();
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

  Future<void> _loadReviews() async {
    _safeSetState(() {
      isLoading = true;
    });

    try {
      final allReviews = await _reviewService.getAllReviews(widget.venueId);
      final stats = await _reviewService.getStats(widget.venueId);

      _safeSetState(() {
        reviews = allReviews;
        avgRating = (stats['avg'] as num).toDouble();
        totalReviews = stats['count'] as int;
        isLoading = false;
      });
    } catch (_) {
      _safeSetState(() {
        isLoading = false;
      });
      _showSnackBar('No se pudieron cargar las reseñas');
    }
  }

  Future<void> _likeReview(int reviewId) async {
    try {
      await _reviewService.likeReview(reviewId);
      await _loadReviews();
      _showSnackBar('Like agregado');
    } catch (_) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todas las reseñas'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReviews,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  Text(
                    widget.venueName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.22),
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
                  const SizedBox(height: 16),
                  if (reviews.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                        ),
                      ),
                      child: const Text('Todavía no hay reseñas.'),
                    )
                  else
                    ...reviews.map(
                      (review) => _ReviewCard(
                        review: review,
                        dateText: _dateText(review['created_at']),
                        onLike: () => _likeReview(review['id'] as int),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final String dateText;
  final VoidCallback onLike;

  const _ReviewCard({
    required this.review,
    required this.dateText,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final profile = review['profiles'] as Map<String, dynamic>?;
    final fullName = (profile?['full_name'] ?? 'Jugador').toString().trim();
    final avatarUrl = (profile?['avatar_url'] ?? '').toString().trim();
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
              _ReviewerAvatar(
                fullName: fullName,
                avatarUrl: avatarUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isEmpty ? 'Jugador' : fullName,
                      style: const TextStyle(
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

class _ReviewerAvatar extends StatelessWidget {
  final String fullName;
  final String avatarUrl;

  const _ReviewerAvatar({
    required this.fullName,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'J';

    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: Colors.transparent,
        child: ClipOval(
          child: Image.network(
            avatarUrl,
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