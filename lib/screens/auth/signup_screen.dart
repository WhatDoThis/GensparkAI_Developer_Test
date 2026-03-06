// lib/screens/auth/signup_screen.dart
// 회원가입 화면 — 비밀번호 강도 검증 + 실시간 피드백

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  PasswordStrength _strength = PasswordStrength.weak;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _strength = AuthService.checkPasswordStrength(value);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('투자 위험 고지 동의가 필요합니다.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final ok = await auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (ok && mounted) {
      // 회원가입 성공 → 대시보드로 (Navigator 스택 초기화)
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (mounted) {
      final msg = auth.errorMessage ?? '회원가입에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.loss,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // 안내 텍스트
                Text(
                  'AutoTradeX 계정 만들기',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '실제 증권 계좌와 연동되는 앱입니다.\n강력한 비밀번호로 계정을 보호하세요.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 32),

                // 이메일
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'example@email.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '이메일을 입력하세요.';
                    if (!AuthService.isValidEmail(v.trim())) {
                      return '올바른 이메일 형식이 아닙니다.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 비밀번호
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  onChanged: _onPasswordChanged,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    hintText: '12자 이상, 대소문자·숫자·특수문자 포함',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 입력하세요.';
                    if (v.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                    final strength = AuthService.checkPasswordStrength(v);
                    if (strength == PasswordStrength.weak) {
                      return '비밀번호가 너무 약합니다. 대소문자, 숫자, 특수문자를 포함하세요.';
                    }
                    return null;
                  },
                ),

                // 비밀번호 강도 표시
                if (_passwordCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _PasswordStrengthBar(strength: _strength),
                ],
                const SizedBox(height: 16),

                // 비밀번호 확인
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: '비밀번호 확인',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 한번 더 입력하세요.';
                    if (v != _passwordCtrl.text) return '비밀번호가 일치하지 않습니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 비밀번호 요건 안내
                _PasswordRequirements(password: _passwordCtrl.text),
                const SizedBox(height: 24),

                // 투자 위험 고지 동의
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '투자 위험 고지',
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppTheme.warning,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '• 이 앱은 실제 증권 계좌와 연동하여 자동 매매를 수행합니다.\n'
                        '• 모든 투자 손실은 사용자 본인의 책임입니다.\n'
                        '• 반드시 모의투자로 충분히 검증 후 실투자로 전환하세요.\n'
                        '• AI 판단이 항상 정확하지 않을 수 있습니다.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.6,
                            ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _agreedToTerms = !_agreedToTerms),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreedToTerms,
                                onChanged: (v) => setState(
                                  () => _agreedToTerms = v ?? false,
                                ),
                                activeColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '위 내용을 모두 이해하고 동의합니다.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 회원가입 버튼
                FilledButton(
                  onPressed: auth.isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '계정 만들기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 비밀번호 강도 바
class _PasswordStrengthBar extends StatelessWidget {
  final PasswordStrength strength;
  const _PasswordStrengthBar({required this.strength});

  Color get _color {
    switch (strength) {
      case PasswordStrength.weak:
        return AppTheme.loss;
      case PasswordStrength.medium:
        return AppTheme.warning;
      case PasswordStrength.strong:
        return AppTheme.profit;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: strength.progress,
            backgroundColor: AppTheme.divider,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              strength == PasswordStrength.strong
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 13,
              color: _color,
            ),
            const SizedBox(width: 4),
            Text(
              '비밀번호 강도: ${strength.label}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

// 비밀번호 요건 체크리스트
class _PasswordRequirements extends StatelessWidget {
  final String password;
  const _PasswordRequirements({required this.password});

  @override
  Widget build(BuildContext context) {
    final checks = [
      ('8자 이상', password.length >= 8),
      ('12자 이상 (권장)', password.length >= 12),
      ('소문자 포함', password.contains(RegExp(r'[a-z]'))),
      ('대문자 포함', password.contains(RegExp(r'[A-Z]'))),
      ('숫자 포함', password.contains(RegExp(r'[0-9]'))),
      ('특수문자 포함', password.contains(RegExp(r'[!@#$%^&*()_+=\-\[\]{};:,.<>?]'))),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '비밀번호 요건',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: checks.map((c) {
              final (label, passed) = c;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    passed ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 14,
                    color: passed ? AppTheme.profit : AppTheme.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: passed
                              ? AppTheme.profit
                              : AppTheme.textTertiary,
                        ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
