import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hash local de senhas Hive: `sha256$<saltHex>$<digestHex>`.
///
/// Senhas antigas em texto claro são aceitas no login e regravadas com hash.
class PasswordHasher {
  static const prefix = 'sha256\$';

  static bool isHashed(String stored) => stored.startsWith(prefix);

  static String hash(String plain, {String? saltHex}) {
    final salt = saltHex ?? _randomSalt();
    final digest = sha256.convert(utf8.encode('$salt:$plain')).toString();
    return '$prefix$salt\$$digest';
  }

  static bool verify(String plain, String stored) {
    if (!isHashed(stored)) return stored == plain;
    final parts = stored.split('\$');
    if (parts.length != 3) return false;
    final salt = parts[1];
    final expected = parts[2];
    final digest = sha256.convert(utf8.encode('$salt:$plain')).toString();
    return digest == expected;
  }

  static String _randomSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
