// lib/services/auth/auth_service.dart
// 인증 서비스 — 회원가입, 로그인, 로그아웃, 세션 관리
// PRD 10-A-2 구현 (Flutter 로컬 버전 — 백엔드 연동 전 단계)

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../security/audit_logger.dart';

enum AuthError {
  invalidEmail,
  weakPassword,
  emailAlreadyExists,
  userNotFound,
  wrongPassword,
  accountLocked,
  tooManyAttempts,
  mfaRequired,
  invalidMfaCode,
  sessionExpired,
  unknown,
}

class AuthResult {
  final bool success;
  final UserModel? user;
  final AuthError? error;
  final String? errorMessage;
  final bool requiresMfa;

  const AuthResult({
    required this.success,
    this.user,
    this.error,
    this.errorMessage,
    this.requiresMfa = false,
  });

  factory AuthResult.ok(UserModel user) =>
      AuthResult(success: true, user: user);

  factory AuthResult.mfaRequired() =>
      AuthResult(success: false, requiresMfa: true);

  factory AuthResult.fail(AuthError error, String message) =>
      AuthResult(success: false, error: error, errorMessage: message);
}

class AuthService {
  static const String _usersKey = 'atx_users';
  static const String _sessionKey = 'atx_session';
  static const String _sessionExpiryKey = 'atx_session_expiry';
  static const Duration _sessionDuration = Duration(hours: 24);
  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 30);

  static final _uuid = const Uuid();

  // ──────────────────────────────────────────
  // 비밀번호 정책 검증 (PRD 10-A-2)
  // ──────────────────────────────────────────
  static PasswordStrength checkPasswordStrength(String password) {
    int score = 0;
    final checks = <String, bool>{
      '8자 이상': password.length >= 8,
      '12자 이상': password.length >= 12,
      '소문자 포함': password.contains(RegExp(r'[a-z]')),
      '대문자 포함': password.contains(RegExp(r'[A-Z]')),
      '숫자 포함': password.contains(RegExp(r'[0-9]')),
      '특수문자 포함':
          password.contains(RegExp(r'[!@#$%^&*()_+=\-\[\]{};:,.<>?]')),
    };
    score = checks.values.where((v) => v).length;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  // ──────────────────────────────────────────
  // 비밀번호 해싱 (SHA-256 + salt)
  // 프로덕션에서는 argon2id 백엔드 서버에서 처리
  // ──────────────────────────────────────────
  static String _hashPassword(String password, String salt) {
    final combined = '$password:$salt:ATX_PEPPER_2024';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  // ──────────────────────────────────────────
  // 회원가입
  // ──────────────────────────────────────────
  static Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    // 1. 이메일 형식 검증
    if (!isValidEmail(email)) {
      return AuthResult.fail(AuthError.invalidEmail, '올바른 이메일 형식이 아닙니다.');
    }

    // 2. 비밀번호 강도 검증
    final strength = checkPasswordStrength(password);
    if (strength == PasswordStrength.weak) {
      return AuthResult.fail(
        AuthError.weakPassword,
        '비밀번호가 너무 약합니다.\n대소문자, 숫자, 특수문자를 포함하고 12자 이상으로 설정하세요.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    final users = usersJson != null
        ? Map<String, dynamic>.from(jsonDecode(usersJson) as Map)
        : <String, dynamic>{};

    // 3. 중복 이메일 확인
    if (users.containsKey(email.toLowerCase())) {
      await AuditLogger.log(
        eventType: AuditEventType.signupSuccess,
        action: '회원가입 시도 — 이미 존재하는 이메일',
        isSuccess: false,
        riskLevel: RiskLevel.medium,
        resource: email,
      );
      return AuthResult.fail(AuthError.emailAlreadyExists, '이미 등록된 이메일 주소입니다.');
    }

    // 4. 계정 생성
    final userId = _uuid.v4();
    final salt = _uuid.v4();
    final hashedPassword = _hashPassword(password, salt);

    final user = UserModel(
      id: userId,
      email: email.toLowerCase(),
      role: UserRole.owner,
      isMfaEnabled: false,
      createdAt: DateTime.now(),
    );

    users[email.toLowerCase()] = {
      ...user.toJson(),
      'passwordHash': hashedPassword,
      'salt': salt,
      'loginAttempts': 0,
      'lockedUntil': null,
    };

    await prefs.setString(_usersKey, jsonEncode(users));

    // 5. 감사 로그
    await AuditLogger.log(
      eventType: AuditEventType.signupSuccess,
      action: '신규 계정 생성',
      isSuccess: true,
      riskLevel: RiskLevel.low,
      actorId: userId,
      resource: email,
    );

    return AuthResult.ok(user);
  }

  // ──────────────────────────────────────────
  // 로그인 (PRD 10-A-2: 브루트포스 방어 포함)
  // ──────────────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);

    if (usersJson == null) {
      return AuthResult.fail(AuthError.userNotFound, '등록된 계정이 없습니다.');
    }

    final users = Map<String, dynamic>.from(jsonDecode(usersJson) as Map);
    final userData = users[normalizedEmail] as Map<String, dynamic>?;

    if (userData == null) {
      // 사용자 존재 여부 노출 방지 (동일한 에러 메시지)
      await AuditLogger.log(
        eventType: AuditEventType.loginFail,
        action: '로그인 실패 — 존재하지 않는 이메일',
        isSuccess: false,
        riskLevel: RiskLevel.medium,
        resource: normalizedEmail,
      );
      return AuthResult.fail(AuthError.userNotFound, '이메일 또는 비밀번호가 올바르지 않습니다.');
    }

    // 1. 계정 잠금 확인
    final lockedUntilStr = userData['lockedUntil'] as String?;
    if (lockedUntilStr != null) {
      final lockedUntil = DateTime.parse(lockedUntilStr);
      if (DateTime.now().isBefore(lockedUntil)) {
        final remaining = lockedUntil.difference(DateTime.now());
        await AuditLogger.log(
          eventType: AuditEventType.loginFail,
          action: '로그인 실패 — 계정 잠금 상태',
          isSuccess: false,
          riskLevel: RiskLevel.high,
          resource: normalizedEmail,
        );
        return AuthResult.fail(
          AuthError.accountLocked,
          '계정이 잠겼습니다. ${remaining.inMinutes + 1}분 후 다시 시도하세요.',
        );
      } else {
        // 잠금 해제
        userData['lockedUntil'] = null;
        userData['loginAttempts'] = 0;
      }
    }

    // 2. 비밀번호 검증
    final salt = userData['salt'] as String;
    final expectedHash = _hashPassword(password, salt);
    final actualHash = userData['passwordHash'] as String;

    if (expectedHash != actualHash) {
      // 실패 카운트 증가
      final attempts = (userData['loginAttempts'] as int? ?? 0) + 1;
      userData['loginAttempts'] = attempts;

      if (attempts >= _maxLoginAttempts) {
        userData['lockedUntil'] =
            DateTime.now().add(_lockoutDuration).toIso8601String();
        users[normalizedEmail] = userData;
        await prefs.setString(_usersKey, jsonEncode(users));

        await AuditLogger.log(
          eventType: AuditEventType.loginFail,
          action: '로그인 실패 $_maxLoginAttempts회 — 계정 잠금',
          isSuccess: false,
          riskLevel: RiskLevel.critical,
          resource: normalizedEmail,
        );
        return AuthResult.fail(
          AuthError.accountLocked,
          '로그인 시도 5회 초과로 30분간 계정이 잠겼습니다.',
        );
      }

      users[normalizedEmail] = userData;
      await prefs.setString(_usersKey, jsonEncode(users));

      await AuditLogger.log(
        eventType: AuditEventType.loginFail,
        action: '로그인 실패 — 비밀번호 불일치 ($attempts/${_maxLoginAttempts}회)',
        isSuccess: false,
        riskLevel: RiskLevel.medium,
        resource: normalizedEmail,
      );

      return AuthResult.fail(
        AuthError.wrongPassword,
        '이메일 또는 비밀번호가 올바르지 않습니다. (${_maxLoginAttempts - attempts}회 남음)',
      );
    }

    // 3. 로그인 성공 — 실패 카운트 초기화
    userData['loginAttempts'] = 0;
    userData['lockedUntil'] = null;
    userData['lastLoginAt'] = DateTime.now().toIso8601String();
    users[normalizedEmail] = userData;
    await prefs.setString(_usersKey, jsonEncode(users));

    final user = UserModel.fromJson(userData);

    // 4. 세션 저장
    await _saveSession(user);

    await AuditLogger.log(
      eventType: AuditEventType.loginSuccess,
      action: '로그인 성공',
      isSuccess: true,
      riskLevel: RiskLevel.low,
      actorId: user.id,
      resource: normalizedEmail,
    );

    return AuthResult.ok(user);
  }

  // ──────────────────────────────────────────
  // 세션 저장 / 복원 / 만료 확인
  // ──────────────────────────────────────────
  static Future<void> _saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(user.toJson()));
    await prefs.setString(
      _sessionExpiryKey,
      DateTime.now().add(_sessionDuration).toIso8601String(),
    );
  }

  static Future<UserModel?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_sessionKey);
    final expiryStr = prefs.getString(_sessionExpiryKey);

    if (sessionJson == null || expiryStr == null) return null;

    final expiry = DateTime.parse(expiryStr);
    if (DateTime.now().isAfter(expiry)) {
      // 세션 만료
      await clearSession();
      await AuditLogger.log(
        eventType: AuditEventType.sessionExpired,
        action: '세션 만료 — 자동 로그아웃',
        isSuccess: true,
        riskLevel: RiskLevel.low,
      );
      return null;
    }

    try {
      return UserModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(sessionJson) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_sessionExpiryKey);
  }

  // ──────────────────────────────────────────
  // 로그아웃
  // ──────────────────────────────────────────
  static Future<void> logout(String? userId) async {
    await clearSession();
    await AuditLogger.log(
      eventType: AuditEventType.logout,
      action: '로그아웃',
      isSuccess: true,
      riskLevel: RiskLevel.low,
      actorId: userId,
    );
  }
}

enum PasswordStrength { weak, medium, strong }

extension PasswordStrengthX on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.weak:
        return '약함';
      case PasswordStrength.medium:
        return '보통';
      case PasswordStrength.strong:
        return '강함';
    }
  }

  double get progress {
    switch (this) {
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.medium:
        return 0.6;
      case PasswordStrength.strong:
        return 1.0;
    }
  }
}
