// lib/providers/auth_provider.dart
// 인증 상태 관리 Provider — 백엔드 API 연동 버전

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth/api_auth_service.dart';
import '../services/auth/auth_service.dart'; // AuthResult, AuthError 재사용

enum AuthState { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _requiresMfa = false;
  bool _isBackendConnected = false;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get requiresMfa => _requiresMfa;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  bool get isBackendConnected => _isBackendConnected;

  // ── 앱 시작 시 세션 복원 ───────────────────────────────
  Future<void> initialize() async {
    _state = AuthState.loading;
    notifyListeners();

    // 백엔드 연결 상태 확인
    await _checkBackendHealth();

    final savedUser = await ApiAuthService.restoreSession();
    if (savedUser != null) {
      _user = savedUser;
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _checkBackendHealth() async {
    try {
      await ApiAuthService.getStoredToken();
      _isBackendConnected = true;
    } catch (_) {
      _isBackendConnected = false;
    }
  }

  // ── 회원가입 ───────────────────────────────────────────
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await ApiAuthService.signUp(
      email: email,
      password: password,
      name: name,
    );

    if (result.success && result.user != null) {
      _user = result.user;
      _state = AuthState.authenticated;
      _isBackendConnected = true;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // ── 로그인 ────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    _requiresMfa = false;
    notifyListeners();

    final result = await ApiAuthService.login(
      email: email,
      password: password,
    );

    if (result.success && result.user != null) {
      _user = result.user;
      _state = AuthState.authenticated;
      _isBackendConnected = true;
      notifyListeners();
      return true;
    } else if (result.requiresMfa) {
      _requiresMfa = true;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } else {
      _errorMessage = result.errorMessage;
      _state = AuthState.unauthenticated;
      // 서버 연결 실패 감지
      if (result.error == AuthError.unknown &&
          (result.errorMessage?.contains('연결') == true ||
              result.errorMessage?.contains('connect') == true)) {
        _isBackendConnected = false;
      }
      notifyListeners();
      return false;
    }
  }

  // ── 로그아웃 ──────────────────────────────────────────
  Future<void> logout() async {
    await ApiAuthService.logout();
    _user = null;
    _state = AuthState.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
