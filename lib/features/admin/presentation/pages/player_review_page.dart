import 'package:flutter/material.dart';
import '../../../player/data/player_review_service.dart';

class PlayerReviewPage extends StatefulWidget {
  final int tournamentId;
  final String reviewedUserId;
  final String playerName;

  const PlayerReviewPage({
    super.key,
    required this.tournamentId,
    required this.reviewedUserId,
    required this.playerName,
  });

  @override
  State<PlayerReviewPage> createState() => _PlayerReviewPageState();
}

class _PlayerReviewPageState extends State<PlayerReviewPage> {
  final PlayerReviewService _service = PlayerReviewService();
  final TextEditingController commentController = TextEditingController();

  int punctuality = 5;
  int behavior = 5;
  int commitment = 5;
  bool isSaving = false;

  Future<void> _save() async {
    setState(() {
      isSaving = true;
    });

    try {
      await _service.saveReview(
        tournamentId: widget.tournamentId,
        reviewedUserId: widget.reviewedUserId,
        punctuality: punctuality,
        behavior: behavior,
        commitment: commitment,
        comment: commentController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valoración guardada'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando valoración: $e'),
        ),
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Widget _scoreSelector({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: Text(title)),
            DropdownButton<int>(
              value: value,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1')),
                DropdownMenuItem(value: 2, child: Text('2')),
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 4, child: Text('4')),
                DropdownMenuItem(value: 5, child: Text('5')),
              ],
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Valorar a ${widget.playerName}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _scoreSelector(
              title: 'Puntualidad',
              value: punctuality,
              onChanged: (v) => setState(() => punctuality = v),
            ),
            _scoreSelector(
              title: 'Conducta',
              value: behavior,
              onChanged: (v) => setState(() => behavior = v),
            ),
            _scoreSelector(
              title: 'Compromiso',
              value: commitment,
              onChanged: (v) => setState(() => commitment = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comentario',
                hintText: 'Ej: Muy puntual y buena actitud',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSaving ? null : _save,
              child: Text(isSaving ? 'Guardando...' : 'Guardar valoración'),
            ),
          ],
        ),
      ),
    );
  }
}