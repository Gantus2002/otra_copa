import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationBadgeService extends ChangeNotifier {
  static final NotificationBadgeService _instance =
      NotificationBadgeService._internal();

  factory NotificationBadgeService() => _instance;

  NotificationBadgeService._internal();

  int _count = 0;
  int get count => _count;

  Timer? _timer;

  void start() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) return;

      try {
        final response = await client
            .from('court_reservations')
            .select('id, expires_at')
            .eq('user_id', user.id)
            .eq('status', 'pending_payment');

        int newCount = 0;

        for (final r in response) {
          final expiresAt = DateTime.tryParse(r['expires_at'] ?? '');
          if (expiresAt == null) continue;

          final diff = expiresAt.difference(DateTime.now());

          if (diff.inMinutes <= 10 && diff.inSeconds > 0) {
            newCount++;
          }
        }

        if (newCount != _count) {
          _count = newCount;
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  void disposeService() {
    _timer?.cancel();
  }
}