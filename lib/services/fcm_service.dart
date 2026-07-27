import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:livro_registro/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmService {
  bool _ready = false;

  Future<void> init() async {
    if (!AppConfig.firebaseConfigured || kIsWeb) {
      _ready = false;
      return;
    }
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM token: $token');
      }
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('FCM foreground: ${message.notification?.title}');
      });
      _ready = true;
    } catch (e) {
      debugPrint('FCM init skipped: $e');
      _ready = false;
    }
  }

  Future<void> registerTokenForProfile(String profileId) async {
    if (!_ready || !AppConfig.supabaseConfigured) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'profile_id': profileId,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('FCM register failed: $e');
    }
  }
}
