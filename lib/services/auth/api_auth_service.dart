// lib/services/auth/api_auth_service.dart
// 백엔드 API 연동 인증 서비스
// POST /auth/signup, /auth/login, /auth/logout, GET /auth/me

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import 'auth_service.dart'; // AuthResult, AuthError, PasswordStrength 재사용

/// 백엔드 서버 URL 설정
/// 환경별로 다른 URL 사용 가능
class ApiConfig {
  // 웹 프리뷰: 샌드박스 공개 URL
  // 실제 기기(Android): 컴퓨터 로컬 IP ex) 192.168.x.x:3000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://3000-ivi0bdfwrvp5cntbd9zyx-583b4d74.sandbox.novita.ai',
  );

  static const Duration timeout = Duration(seconds: 15);

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> authHeaders(String token) => {
        ...headers,
        'Authorization': 'Bearer $token',
      };
}

class ApiAuthService {
  static const String _tokenKey = 'atx_jwt_token';
  static const String _userKey = 'atx_user_data';
  static const String _tokenExpiryKey = 'atx_token_expiry';

  // ── 토큰 저장/로드 ─────────────────────────────────────
  static Future<void> _saveToken(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
    // 24시간 만료 (서버 설정과 동일)
    final expiry = DateTime.now().add(const Duration(hours: 24));
    await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
  }

  static Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final expiryStr = prefs.getString(_tokenExpiryKey);

    if (token == null || expiryStr == null) return null;
    final expiry = DateTime.parse(expiryStr);
    if (DateTime.now().isAfter(expiry)) {
      await _clearToken();
      return null;
    }
    return token;
  }

  static Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_tokenExpiryKey);
  }

  // ── 세션 복원 ──────────────────────────────────────────
  static Future<UserModel?> restoreSession() async {
    final token = await getStoredToken();
    if (token == null) return null;

    try {
      final resp = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/auth/me'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final userData = body['user'] as Map<String, dynamic>;
        return _mapToUserModel(userData);
      } else {
        await _clearToken();
        return null;
      }
    } catch (_) {
      // 서버 연결 실패 시 로컬 캐시 사용
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        try {
          return _mapToUserModel(
            Map<String, dynamic>.from(jsonDecode(userJson) as Map),
          );
        } catch (_) {}
      }
      return null;
    }
  }

  // ── 회원가입 ───────────────────────────────────────────
  static Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/signup'),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'email': email,
              'password': password,
              'name': name,
            }),
          )
          .timeout(ApiConfig.timeout);

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 201) {
        // 회원가입 후 바로 로그인
        return login(email: email, password: password);
      }

      // 에러 처리
      final errorMsg = body['error'] as String? ?? '회원가입 실패';
      final details = body['details'] as List?;

      if (resp.statusCode == 409) {
        return AuthResult.fail(AuthError.emailAlreadyExists, errorMsg);
      }
      if (resp.statusCode == 400 && details != null) {
        final firstError = (details.first as Map)['message'] as String? ?? errorMsg;
        return AuthResult.fail(AuthError.weakPassword, firstError);
      }
      return AuthResult.fail(AuthError.unknown, errorMsg);
    } on http.ClientException catch (e) {
      return AuthResult.fail(AuthError.unknown, '서버에 연결할 수 없습니다: ${e.message}');
    } catch (e) {
      return AuthResult.fail(AuthError.unknown, '오류가 발생했습니다: $e');
    }
  }

  // ── 로그인 ────────────────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(ApiConfig.timeout);

      final body = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 200) {
        final token = body['token'] as String;
        final userData = body['user'] as Map<String, dynamic>;
        final user = _mapToUserModel(userData);

        await _saveToken(token, userData);
        return AuthResult.ok(user);
      }

      final errorMsg = body['error'] as String? ?? '로그인 실패';
      if (resp.statusCode == 401) {
        return AuthResult.fail(AuthError.wrongPassword, errorMsg);
      }
      if (resp.statusCode == 403) {
        return AuthResult.fail(AuthError.accountLocked, errorMsg);
      }
      return AuthResult.fail(AuthError.unknown, errorMsg);
    } on http.ClientException catch (e) {
      return AuthResult.fail(AuthError.unknown, '서버에 연결할 수 없습니다.\n백엔드 서버가 실행 중인지 확인하세요.\n${e.message}');
    } catch (e) {
      return AuthResult.fail(AuthError.unknown, '오류: $e');
    }
  }

  // ── 로그아웃 ──────────────────────────────────────────
  static Future<void> logout() async {
    final token = await getStoredToken();
    if (token != null) {
      try {
        await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/auth/logout'),
              headers: ApiConfig.authHeaders(token),
            )
            .timeout(ApiConfig.timeout);
      } catch (_) {
        // 서버 오류여도 로컬 토큰은 삭제
      }
    }
    await _clearToken();
  }

  // ── UserModel 매핑 ────────────────────────────────────
  static UserModel _mapToUserModel(Map<String, dynamic> data) {
    // mfaEnabled: 서버가 bool or int(0/1) 둘 다 보낼 수 있어서 안전하게 처리
    bool parseMfa(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is int) return v == 1;
      return false;
    }

    return UserModel(
      id: data['id']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      role: _parseRole(data['role']?.toString() ?? 'OWNER'),
      isMfaEnabled: parseMfa(data['mfaEnabled'] ?? data['mfa_enabled']),
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLoginAt: data['last_login_at'] != null
          ? DateTime.tryParse(data['last_login_at'].toString())
          : null,
    );
  }

  static UserRole _parseRole(String role) {
    switch (role.toUpperCase()) {
      case 'VIEWER':
        return UserRole.viewer;
      case 'SYSTEM':
        return UserRole.system;
      default:
        return UserRole.owner;
    }
  }
}
