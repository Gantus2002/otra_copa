import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushSenderService {
  PushSenderService._();

  static final PushSenderService instance = PushSenderService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<void> send({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'userId': userId,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
    } catch (e) {
      debugPrint('Error enviando push: $e');
    }
  }
}