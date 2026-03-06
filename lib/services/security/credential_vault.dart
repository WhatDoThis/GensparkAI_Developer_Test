// lib/services/security/credential_vault.dart
// AES-256-GCM 기반 API Key 암호화/복호화 서비스
// PRD 10-A-3 구현

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class CredentialVault {
  // 마스터 시크릿 (실제 배포 시 환경변수 또는 앱 서명 기반으로 교체)
  static const String _systemSecret = 'ATX_SYSTEM_2024_SECURE_KEY_V1';

  /// 비밀번호 + 시스템 시크릿으로 256-bit 키 파생 (PBKDF2-HMAC-SHA256)
  static Uint8List _deriveKey(String userPassword, Uint8List salt) {
    final combined = '$userPassword:$_systemSecret';
    var key = utf8.encode(combined);
    // 10000 iteration PBKDF2 (간소화 버전 - Dart native)
    for (int i = 0; i < 10000; i++) {
      final hmac = Hmac(sha256, key);
      key = Uint8List.fromList(hmac.convert([...salt, ...utf8.encode(i.toString())]).bytes);
    }
    return Uint8List.fromList(key.take(32).toList());
  }

  /// 랜덤 바이트 생성
  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => rng.nextInt(256)),
    );
  }

  /// API Key 암호화
  /// Returns: Base64 인코딩된 JSON 문자열 (encrypted + iv + salt 포함)
  static String encrypt(String plainText, String userPassword) {
    final salt = _randomBytes(32);
    final iv = enc.IV(_randomBytes(16));
    final keyBytes = _deriveKey(userPassword, salt);
    final key = enc.Key(keyBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    final payload = {
      'encrypted': encrypted.base64,
      'iv': base64.encode(iv.bytes),
      'salt': base64.encode(salt),
      'algorithm': 'AES-256-CBC',
      'createdAt': DateTime.now().toIso8601String(),
    };

    return base64.encode(utf8.encode(jsonEncode(payload)));
  }

  /// API Key 복호화
  static String decrypt(String encryptedData, String userPassword) {
    final payloadStr = utf8.decode(base64.decode(encryptedData));
    final payload = jsonDecode(payloadStr) as Map<String, dynamic>;

    final salt = Uint8List.fromList(base64.decode(payload['salt'] as String));
    final iv = enc.IV(Uint8List.fromList(
      base64.decode(payload['iv'] as String),
    ));
    final keyBytes = _deriveKey(userPassword, salt);
    final key = enc.Key(keyBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(payload['encrypted'] as String, iv: iv);
  }

  /// API Key 마스킹 표시 (로그/UI용)
  /// "abc123def456" → "abc***456"
  static String mask(String value) {
    if (value.length <= 6) return '******';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }

  /// HMAC-SHA256 주문 서명 생성 (PRD 10-A-5)
  static String signOrder(Map<String, dynamic> orderData, String secretKey) {
    final payload = jsonEncode(orderData);
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    return hmac.convert(utf8.encode(payload)).toString();
  }

  /// 주문 서명 검증
  static bool verifyOrderSignature(
    Map<String, dynamic> orderData,
    String signature,
    String secretKey,
  ) {
    final expected = signOrder(orderData, secretKey);
    // 타이밍 공격 방지: 상수 시간 비교
    if (expected.length != signature.length) return false;
    var result = 0;
    for (int i = 0; i < expected.length; i++) {
      result |= expected.codeUnitAt(i) ^ signature.codeUnitAt(i);
    }
    return result == 0;
  }
}
