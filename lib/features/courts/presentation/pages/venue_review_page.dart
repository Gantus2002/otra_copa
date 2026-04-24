import 'package:flutter/material.dart';

import '../../data/venue_review_service.dart';

class VenueReviewPage extends StatefulWidget {
  final int venueId;
  final String venueName;

  const VenueReviewPage({
    super.key,
    required this.venueId,
    required this.venueName,
  });

  @override
  State<VenueReviewPage> createState() => _VenueReviewPageState();
}

class _VenueReviewPageState extends State<VenueReviewPage> {
  final VenueReviewService _service = VenueReviewService();
  final TextEditingController _commentController = TextEditingController();

  int rating = 5;
  bool isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _service.createReview(
        venueId: widget.venueId,
        rating: rating,
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;

      _showSnackBar(
        'Reseña enviada correctamente',
        color: Colors.green,
      );

      Navigator.pop(context, true);
    } catch (e) {
      String message = e.toString().replaceFirst('Exception: ', '');

      if (message.toLowerCase().contains('duplicate') ||
          message.toLowerCase().contains('unique')) {
        message = 'Ya dejaste una reseña para este complejo';
      }

      _showSnackBar(message);
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildStar(int value) {
    final selected = value <= rating;

    return IconButton(
      onPressed: () {
        setState(() {
          rating = value;
        });
      },
      icon: Icon(
        selected ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 34,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Valorar complejo'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.venueName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dejá tu puntuación y un comentario opcional.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.22),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '¿Qué te pareció?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStar(1),
                      _buildStar(2),
                      _buildStar(3),
                      _buildStar(4),
                      _buildStar(5),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$rating de 5',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comentario',
                      hintText: 'Contá cómo fue tu experiencia',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isLoading ? null : _save,
                      child: Text(
                        isLoading ? 'Enviando...' : 'Enviar reseña',
                      ),
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
