import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static bool get supabaseConfigured {
    final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
    final key = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
    return url.isNotEmpty &&
        key.isNotEmpty &&
        !url.contains('YOUR_') &&
        !key.contains('YOUR_');
  }

  static String get supabaseUrl =>
      dotenv.maybeGet('SUPABASE_URL') ?? 'https://YOUR_PROJECT.supabase.co';

  static String get supabaseAnonKey =>
      dotenv.maybeGet('SUPABASE_ANON_KEY') ?? 'YOUR_ANON_KEY';

  static bool get firebaseConfigured {
    return (dotenv.maybeGet('FIREBASE_ENABLED') ?? 'false').toLowerCase() ==
        'true';
  }

  static String matriculaToEmail(String matricula) {
    final clean = matricula.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return '$clean@ebd.local';
  }
}
