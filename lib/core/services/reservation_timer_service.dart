import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationTimerService {
  static final ReservationTimerService _instance =
      ReservationTimerService._internal();

  factory ReservationTimerService() => _instance;

  ReservationTimerService._internal();

  Timer? _timer;

  void start(BuildContext context) {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) return;

      try {
        final now = DateTime.now().toIso8601String();

        final response = await client
            .from('court_reservations')
            .select('id, expires_at')
            .eq('user_id', user.id)
            .eq('status', 'pending_payment');

        for (final r in response) {
          final expiresAt = DateTime.tryParse(r['expires_at'] ?? '');
          if (expiresAt == null) continue;

          final diff = expiresAt.difference(DateTime.now());

          // 🔥 2 minutos antes
          if (diff.inSeconds <= 120 && diff.inSeconds > 110) {
            _showWarning(context, diff);
          }
        }
      } catch (_) {}
    });
  }

  void _showWarning(BuildContext context, Duration diff) {
    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.orange,
        content: Text(
          '⚠ Te quedan ${minutes}m ${seconds}s para pagar tu reserva',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void dispose() {
    _timer?.cancel();
  }
}