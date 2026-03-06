// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trading_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../models/stock_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('설정')),
      body: Consumer<TradingProvider>(
        builder: (context, provider, _) {
          final account = provider.account;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // 계좌 연동 상태
              _buildAccountCard(context, account),
              const SizedBox(height: 12),
              // 매매 모드
              _buildSection(context, '매매 설정', [
                _SettingsTile(
                  icon: Icons.swap_horiz,
                  title: '매매 모드',
                  subtitle: account?.tradingModeLabel ?? '모의투자',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: account?.tradingMode == TradingMode.live
                          ? AppTheme.lossLight
                          : AppTheme.profitLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      account?.tradingMode == TradingMode.live
                          ? '실투자 중'
                          : '모의투자 중',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: account?.tradingMode == TradingMode.live
                            ? AppTheme.loss
                            : AppTheme.profit,
                      ),
                    ),
                  ),
                  onTap: () => _showTradingModeDialog(context),
                ),
                _SettingsTile(
                  icon: Icons.bar_chart,
                  title: 'AI 모델',
                  subtitle: 'claude-sonnet-4',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 12),
              // 안전장치
              _buildSection(context, '안전장치', [
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  title: '일일 최대 손실 한도',
                  subtitle: '-5.0%',
                  onTap: () => _showEditDialog(
                      context, '일일 최대 손실 한도', '-5.0'),
                ),
                _SettingsTile(
                  icon: Icons.repeat,
                  title: '연속 손절 제한',
                  subtitle: '3회 → 30분 강제 대기',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.pie_chart_outline,
                  title: '단일 종목 비중 한도',
                  subtitle: '30%',
                  onTap: () => _showEditDialog(
                      context, '단일 종목 비중 한도', '30'),
                ),
                _SettingsTile(
                  icon: Icons.inventory_2_outlined,
                  title: '최대 동시 보유 종목',
                  subtitle: '3종목',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.savings_outlined,
                  title: '최소 현금 보유 비율',
                  subtitle: '20%',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 12),
              // 매매 시간
              _buildSection(context, '매매 시간 설정', [
                _SettingsTile(
                  icon: Icons.access_time,
                  title: '시초가 매매 금지',
                  subtitle: '09:00 ~ 09:10',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.schedule,
                  title: '장마감 전 청산',
                  subtitle: '14:50 강제 매도',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 12),
              // 알림
              _buildSection(context, '알림 설정', [
                _SwitchTile(
                  icon: Icons.notifications_outlined,
                  title: '매수 알림',
                  value: true,
                  onChanged: (_) {},
                ),
                _SwitchTile(
                  icon: Icons.sell_outlined,
                  title: '매도 알림',
                  value: true,
                  onChanged: (_) {},
                ),
                _SwitchTile(
                  icon: Icons.warning_outlined,
                  title: '손절 알림',
                  value: true,
                  onChanged: (_) {},
                ),
                _SwitchTile(
                  icon: Icons.assessment_outlined,
                  title: '일일 리포트 알림',
                  value: true,
                  onChanged: (_) {},
                ),
                _SettingsTile(
                  icon: Icons.telegram,
                  title: '텔레그램 봇',
                  subtitle: '미연동',
                  onTap: () => _showTelegramDialog(context),
                ),
              ]),
              const SizedBox(height: 12),
              // 증권사 API
              _buildSection(context, '증권사 API', [
                _SettingsTile(
                  icon: Icons.key_outlined,
                  title: '키움증권 API Key',
                  subtitle: account?.isConnected == true
                      ? '연동됨 (모의투자)'
                      : '미연동',
                  trailing: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: account?.isConnected == true
                          ? AppTheme.profit
                          : AppTheme.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onTap: () => _showApiKeyDialog(context, '키움증권'),
                ),
                _SettingsTile(
                  icon: Icons.key_outlined,
                  title: '한국투자증권 KIS API',
                  subtitle: '미연동',
                  trailing: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.textTertiary, shape: BoxShape.circle),
                  ),
                  onTap: () => _showApiKeyDialog(context, '한국투자증권'),
                ),
              ]),
              const SizedBox(height: 12),
              // 위험 안내
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppTheme.warning),
                        const SizedBox(width: 6),
                        Text('투자 위험 고지',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: AppTheme.warning)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '이 시스템은 투자 자문이 아닌 자동 거래 도구입니다. '
                      '모든 투자 손실은 사용자 책임입니다. '
                      '반드시 모의투자로 2주 이상 검증 후 실투자로 전환하세요.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.warning),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 계정 정보 + 로그아웃 ──
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (!auth.isAuthenticated) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    auth.user?.email ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '계정 소유자',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.profit.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '인증됨',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.profit,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppTheme.divider, height: 1),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('로그아웃'),
                                content: const Text(
                                    '로그아웃하면 자동매매가 중단됩니다.\n정말 로그아웃 하시겠습니까?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('취소'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.loss,
                                    ),
                                    child: const Text('로그아웃'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              await context
                                  .read<AuthProvider>()
                                  .logout();
                            }
                          },
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: AppTheme.loss,
                          ),
                          label: const Text(
                            '로그아웃',
                            style: TextStyle(
                              color: AppTheme.loss,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.loss),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, AccountInfo? account) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: account?.isConnected == true
                  ? AppTheme.profitLight
                  : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_balance_outlined,
              color: account?.isConnected == true
                  ? AppTheme.profit
                  : AppTheme.textTertiary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      account?.brokerName ?? '계좌 미연동',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: account?.tradingMode == TradingMode.paper
                            ? AppTheme.primaryLight
                            : AppTheme.lossLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        account?.tradingModeLabel ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: account?.tradingMode == TradingMode.paper
                              ? AppTheme.primary
                              : AppTheme.loss,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  account?.accountNumber ?? '-',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatWonCompact(account?.totalBalance ?? 0),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '현금 ${formatWonCompact(account?.availableCash ?? 0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textTertiary)),
          ),
          ...children.asMap().entries.map((e) => Column(
                children: [
                  if (e.key > 0)
                    const Divider(height: 1, indent: 52, color: AppTheme.divider),
                  e.value,
                ],
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showTradingModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('매매 모드 변경'),
        content: const Text(
            '실투자 모드로 전환 시 실제 계좌로 거래가 실행됩니다.\n'
            '반드시 모의투자로 2주 이상 검증 후 전환하세요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('모의투자 유지', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String title, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context),
              child: const Text('저장')),
        ],
      ),
    );
  }

  void _showTelegramDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('텔레그램 봇 연동'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bot Token'),
            SizedBox(height: 6),
            TextField(decoration: InputDecoration(hintText: 'your_bot_token')),
            SizedBox(height: 12),
            Text('Chat ID'),
            SizedBox(height: 6),
            TextField(decoration: InputDecoration(hintText: 'your_chat_id')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context),
              child: const Text('연동')),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, String broker) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$broker API 연동'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App Key'),
            const SizedBox(height: 6),
            const TextField(
                obscureText: true,
                decoration: InputDecoration(hintText: 'App Key')),
            const SizedBox(height: 12),
            const Text('App Secret'),
            const SizedBox(height: 6),
            const TextField(
                obscureText: true,
                decoration: InputDecoration(hintText: 'App Secret')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ API 키는 암호화 저장됩니다.\n모의투자 계좌로 먼저 테스트하세요.',
                style: TextStyle(fontSize: 12, color: AppTheme.warning),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(context),
              child: const Text('연동')),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textTertiary)),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right,
                    size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
