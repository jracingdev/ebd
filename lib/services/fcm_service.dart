import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:livro_registro/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registro de token FCM no Supabase (`fcm_tokens`).
///
/// Push de aniversário é enviado pela Edge Function `birthday-push`
/// (FCM HTTP v1 quando secrets Firebase estão configurados).
class FcmService {
  bool _ready = false;
  String? lastToken;

  bool get ready => _ready;

  Future<void> init() async {
    if (!AppConfig.firebaseConfigured || kIsWeb) {
      _ready = false;
      if (kIsWeb) {
        debugPrint('FCM: desativado na web.');
      } else if (!AppConfig.firebaseConfigured) {
        debugPrint(
          'FCM: FIREBASE_ENABLED=false — token não será registrado. '
          'Ver docs/SETUP_CLOUD.md.',
        );
      }
      return;
    }
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      lastToken = token;
      if (token != null) {
        debugPrint('FCM token obtido (${token.length} chars).');
      } else {
        debugPrint('FCM: getToken() retornou null.');
      }
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('FCM foreground: ${message.notification?.title}');
      });
      messaging.onTokenRefresh.listen((t) {
        lastToken = t;
        debugPrint('FCM token refresh.');
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
      final token = lastToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      lastToken = token;
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'profile_id': profileId,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('FCM token registrado para profile $profileId');
    } catch (e) {
      debugPrint('FCM register failed: $e');
    }
  }
}
