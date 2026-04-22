import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('📩 Background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _client = Supabase.instance.client;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await _requestPermission();
    await _configureHandlers();
    await _saveToken();

    _initialized = true;
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _configureHandlers() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('📩 Foreground message: ${message.messageId}');
      log('📩 Title: ${message.notification?.title}');
      log('📩 Body: ${message.notification?.body}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('📩 Opened from notification: ${message.messageId}');
      // Más adelante acá navegamos a torneo / equipo / solicitud
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      log('📩 App opened from terminated state: ${initialMessage.messageId}');
    }

    _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token: token);
    });
  }

  Future<void> _saveToken({String? token}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final fcmToken = token ?? await _messaging.getToken();
    if (fcmToken == null || fcmToken.trim().isEmpty) return;

    await _client.from('profiles').update({
      'fcm_token': fcmToken,
    }).eq('id', user.id);
  }
}