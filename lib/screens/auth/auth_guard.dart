// lib/screens/auth/auth_guard.dart
// 인증 상태에 따라 로그인 화면 또는 메인 앱으로 라우팅
// 세션 복원 → 로딩 → 인증됨/미인증됨 분기

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class AuthGuard extends StatefulWidget {
  /// 인증 완료 후 보여줄 메인 앱 위젯
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  @override
  void initState() {
    super.initState();
    // 앱 시작 시 저장된 세션 복원 시도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return switch (auth.state) {
      // 초기화 중 / 로딩 중 → 스플래시
      AuthState.initial || AuthState.loading => const _SplashScreen(),

      // 인증 완료 → 메인 앱
      AuthState.authenticated => widget.child,

      // 미인증 → 로그인 화면
      AuthState.unauthenticated => const LoginScreen(),
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_graph,
              size: 56,
              color: Color(0xFF1565C0),
            ),
            SizedBox(height: 20),
            Text(
              'AutoTradeX',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1565C0),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
