// lib/providers/auth_provider.dart
// 인증 상태 관리 Provider — 앱 전체 로그인/로그아웃 상태 공유

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth/auth_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _errorMessage;
  bool _requiresMfa = false;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get requiresMfa => _requiresMfa;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;

  // ──────────────────────────────────────────
  // 앱 시작 시 세션 복원
  // ──────────────────────────────────────────
  Future<void> initialize() async {
    _state = AuthState.loading;
    notifyListeners();

    final savedUser = await AuthService.restoreSession();
    if (savedUser != null) {
      _user = savedUser;
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // ──────────────────────────────────────────
  // 회원가입
  // ──────────────────────────────────────────
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await AuthService.signUp(
      email: email,
      password: password,
    );

    if (result.success && result.user != null) {
      _user = result.user;
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.errorMessage;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────
  // 로그인
  // ──────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    _requiresMfa = false;
    notifyListeners();

    final result = await AuthService.login(
      email: email,
      password: password,
    );

    if (result.success && result.user != null) {
      _user = result.user;
      _state = AuthState.authenticated;
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
      notifyListeners();
      return false;
    }
  }

  // ──────────────────────────────────────────
  // 로그아웃
  // ──────────────────────────────────────────
  Future<void> logout() async {
    await AuthService.logout(_user?.id);
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
