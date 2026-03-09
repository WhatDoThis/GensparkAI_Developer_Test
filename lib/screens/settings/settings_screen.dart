// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/trading_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../models/stock_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 알림 스위치 상태 (로컬 UI 상태)
  bool _buyAlert = true;
  bool _sellAlert = true;
  bool _stopLossAlert = true;
  bool _dailyReportAlert = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: AppTheme.surface,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.divider),
        ),
      ),
      body: Consumer<TradingProvider>(
        builder: (context, provider, _) {
          final account = provider.account;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // ── 계좌 연동 상태 ──
              _buildAccountCard(context, account),
              const SizedBox(height: 16),

              // ── 매매 설정 ──
              _buildSection(context, '매매 설정', [
                _SettingsTile(
                  icon: Icons.swap_horiz,
                  iconColor: AppTheme.primary,
                  title: '매매 모드',
                  subtitle: account?.tradingMode == TradingMode.live
                      ? '실전투자 — 실제 계좌 거래'
                      : '모의투자 — 실제 돈 사용 안 함',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: account?.tradingMode == TradingMode.live
                          ? AppTheme.lossLight
                          : AppTheme.profitLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      account?.tradingMode == TradingMode.live ? '실투자' : '모의투자',
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
                  icon: Icons.smart_toy_outlined,
                  iconColor: const Color(0xFF9C27B0),
                  title: 'AI 분석 엔진',
                  subtitle: 'OpenAI GPT-4o-mini',
                  onTap: () => _showInfoDialog(
                    context,
                    'AI 분석 엔진',
                    'OpenAI GPT-4o-mini 모델을 사용합니다.\n'
                    '기술적 지표(RSI, MACD, 볼린저밴드)를 종합 분석하여\n'
                    '매수 종목을 선택합니다.\n\n'
                    '모델 변경은 서버 .env 파일의\nOPENAI_MODEL 값을 수정하세요.',
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // ── 안전장치 ──
              _buildSection(context, '안전장치', [
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  iconColor: AppTheme.loss,
                  title: '일일 최대 손실 한도',
                  subtitle: '-5% 초과 시 당일 자동 중단',
                  onTap: () => _showInfoDialog(
                    context,
                    '일일 최대 손실 한도',
                    '일일 손실이 -5%를 초과하면 당일 자동매매가 즉시 중단됩니다.\n\n'
                    '변경하려면 서버 .env 파일의\nMAX_DAILY_LOSS_RATE 값을 수정하세요.\n\n'
                    '현재값: -5.0%',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.repeat,
                  iconColor: AppTheme.warning,
                  title: '연속 손절 제한',
                  subtitle: '3회 연속 손절 → 30분 강제 대기',
                  onTap: () => _showInfoDialog(
                    context,
                    '연속 손절 제한',
                    '3회 연속 손절 발생 시 30분간 자동으로 매매를 중단합니다.\n\n'
                    '이 기능은 손실이 연속될 때 감정적 매매를 방지합니다.\n\n'
                    '변경: .env → MAX_CONSECUTIVE_LOSSES\n'
                    '쿨다운: .env → CIRCUIT_BREAKER_COOLDOWN',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.pie_chart_outline,
                  iconColor: AppTheme.primary,
                  title: '단일 종목 비중 한도',
                  subtitle: '전체 예산의 30% 이하',
                  onTap: () => _showInfoDialog(
                    context,
                    '단일 종목 비중 한도',
                    '한 종목에 전체 예산의 30% 이상 투입하지 않습니다.\n\n'
                    '리스크 분산을 위한 핵심 안전장치입니다.\n\n'
                    '변경: .env → MAX_POSITION_RATIO',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppTheme.primary,
                  title: '최대 동시 보유 종목',
                  subtitle: '최대 3종목 동시 보유',
                  onTap: () => _showInfoDialog(
                    context,
                    '최대 동시 보유 종목',
                    '동시에 보유할 수 있는 종목 수를 제한합니다.\n\n'
                    '현재 최대 3종목까지 동시 보유 가능합니다.\n\n'
                    '변경: .env → MAX_CONCURRENT_POSITIONS',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.savings_outlined,
                  iconColor: AppTheme.profit,
                  title: '최소 현금 보유 비율',
                  subtitle: '항상 20% 이상 현금 유지',
                  onTap: () => _showInfoDialog(
                    context,
                    '최소 현금 보유 비율',
                    '항상 전체 자산의 20% 이상을 현금으로 유지합니다.\n\n'
                    '급락 시 추가 매수 기회를 위한 여유 자금입니다.\n\n'
                    '변경: .env → MIN_CASH_RESERVE',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.trending_down,
                  iconColor: AppTheme.loss,
                  title: '단일 종목 손절 기준',
                  subtitle: '-3% 도달 시 자동 손절',
                  onTap: () => _showInfoDialog(
                    context,
                    '단일 종목 손절 기준',
                    '보유 종목이 매수가 대비 -3% 하락하면 자동으로 손절합니다.\n\n'
                    '큰 손실을 막기 위한 핵심 안전장치입니다.\n\n'
                    '변경: .env → STOP_LOSS_THRESHOLD',
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // ── 매매 시간 설정 ──
              _buildSection(context, '매매 시간', [
                _SettingsTile(
                  icon: Icons.access_time,
                  iconColor: AppTheme.warning,
                  title: '시초가 매매 금지',
                  subtitle: '09:00 ~ 09:10 매수 불가',
                  onTap: () => _showInfoDialog(
                    context,
                    '시초가 매매 금지',
                    '장 시작 직후 09:00 ~ 09:10은 변동성이 크므로\n매수를 하지 않습니다.\n\n'
                    '변경: .env → TRADING_START_TIME (기본 09:10)',
                  ),
                ),
                _SettingsTile(
                  icon: Icons.schedule,
                  iconColor: AppTheme.warning,
                  title: '장마감 전 강제 청산',
                  subtitle: '14:50 미체결 포지션 전량 매도',
                  onTap: () => _showInfoDialog(
                    context,
                    '장마감 전 강제 청산',
                    '14:50에 보유 중인 모든 포지션을 강제 매도합니다.\n\n'
                    '당일 단타 전략으로 오버나잇 리스크를 제거합니다.\n\n'
                    '변경: .env → TRADING_END_TIME (기본 14:50)',
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // ── 알림 설정 ──
              _buildSection(context, '앱 알림', [
                _SwitchTile(
                  icon: Icons.shopping_cart_outlined,
                  title: '매수 알림',
                  subtitle: '종목 매수 시 알림',
                  value: _buyAlert,
                  onChanged: (v) => setState(() => _buyAlert = v),
                ),
                _SwitchTile(
                  icon: Icons.sell_outlined,
                  title: '매도 알림',
                  subtitle: '종목 매도 시 알림',
                  value: _sellAlert,
                  onChanged: (v) => setState(() => _sellAlert = v),
                ),
                _SwitchTile(
                  icon: Icons.warning_outlined,
                  title: '손절 알림',
                  subtitle: '강제 손절 발생 시 알림',
                  value: _stopLossAlert,
                  onChanged: (v) => setState(() => _stopLossAlert = v),
                ),
                _SwitchTile(
                  icon: Icons.assessment_outlined,
                  title: '일일 리포트',
                  subtitle: '매일 장마감 후 요약 알림',
                  value: _dailyReportAlert,
                  onChanged: (v) => setState(() => _dailyReportAlert = v),
                ),
              ]),
              const SizedBox(height: 12),

              // ── 증권사 API ──
              _buildSection(context, '증권사 API 연동', [
                _SettingsTile(
                  icon: Icons.key_outlined,
                  iconColor: const Color(0xFF1565C0),
                  title: '한국투자증권 KIS API',
                  subtitle: account?.isConnected == true
                      ? '연동됨 — ${account!.tradingMode == TradingMode.live ? "실전투자" : "모의투자"}'
                      : '미연동 — 탭하여 연결',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: account?.isConnected == true
                              ? AppTheme.profit
                              : AppTheme.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppTheme.textTertiary),
                    ],
                  ),
                  onTap: () => _showKisApiDialog(context, provider),
                ),
              ]),
              const SizedBox(height: 12),

              // ── 위험 고지 ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppTheme.warning),
                      const SizedBox(width: 6),
                      Text('투자 위험 고지',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppTheme.warning, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      '이 시스템은 투자 자문이 아닌 자동 거래 도구입니다. '
                      '모든 투자 손실은 사용자 책임입니다. '
                      '반드시 모의투자로 충분히 검증한 후 실투자로 전환하세요.',
                      style: Theme.of(context).textTheme.bodySmall
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
                        Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_outline,
                                color: AppTheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.user?.email ?? '',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text('계정 소유자',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppTheme.textSecondary)),
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
                            child: Text('인증됨',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppTheme.profit,
                                      fontWeight: FontWeight.w600,
                                    )),
                          ),
                        ]),
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
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('취소'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.loss),
                                    child: const Text('로그아웃'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              await context.read<AuthProvider>().logout();
                            }
                          },
                          icon: const Icon(Icons.logout, size: 18,
                              color: AppTheme.loss),
                          label: const Text('로그아웃',
                              style: TextStyle(
                                  color: AppTheme.loss,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.loss),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
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

  // ── 위젯 빌더 ──────────────────────────────────────────

  Widget _buildAccountCard(BuildContext context, AccountInfo? account) {
    final isConnected = account?.isConnected == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? AppTheme.profit.withValues(alpha: 0.3)
              : AppTheme.divider,
        ),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isConnected ? AppTheme.profitLight : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.account_balance_outlined,
            color: isConnected ? AppTheme.profit : AppTheme.textTertiary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                isConnected ? (account?.brokerName ?? '한국투자증권') : '계좌 미연동',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (isConnected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            ]),
            const SizedBox(height: 2),
            Text(
              isConnected
                  ? (account?.accountNumber ?? '-')
                  : '매매 설정 화면에서 계좌를 연결하세요',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppTheme.textTertiary),
            ),
          ]),
        ),
        if (isConnected)
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              _formatWon(account?.totalBalance ?? 0),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '현금 ${_formatWon(account?.availableCash ?? 0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
      ]),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w600)),
          ),
          ...children.asMap().entries.map((e) => Column(children: [
                if (e.key > 0)
                  const Divider(height: 1, indent: 52, color: AppTheme.divider),
                e.value,
              ])),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── 다이얼로그 ──────────────────────────────────────────

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content, style: const TextStyle(height: 1.6)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showTradingModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('매매 모드'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modeOption(
              context,
              icon: Icons.science_outlined,
              color: AppTheme.profit,
              title: '모의투자 (권장)',
              desc: '실제 돈을 사용하지 않습니다.\n충분한 검증 후 실전 전환을 권장합니다.',
            ),
            const SizedBox(height: 12),
            _modeOption(
              context,
              icon: Icons.attach_money,
              color: AppTheme.loss,
              title: '실전투자',
              desc: '실제 계좌로 거래가 실행됩니다.\n반드시 모의투자 2주 이상 검증 후 전환하세요.',
              isWarning: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '매매 모드 변경은 계좌 재연결이 필요합니다.\n매매 설정 화면에서 변경하세요.',
                style: TextStyle(fontSize: 12, color: AppTheme.warning),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _modeOption(BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: color, fontSize: 14)),
            const SizedBox(height: 2),
            Text(desc,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
          ]),
        ),
      ]),
    );
  }

  void _showKisApiDialog(BuildContext context, TradingProvider provider) {
    final appKeyCtrl = TextEditingController();
    final appSecretCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    bool isMock = true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.key_outlined, size: 20, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('한국투자증권 KIS API'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 발급 안내
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('API 키 발급 방법',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                      const SizedBox(height: 4),
                      const Text(
                        '1. https://apiportal.koreainvestment.com\n'
                        '2. 로그인 → My API → 앱 생성\n'
                        '3. 모의투자 앱 먼저 생성 권장\n'
                        '4. App Key & App Secret 복사',
                        style: TextStyle(fontSize: 11, color: AppTheme.primary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 모드 선택
                Row(children: [
                  const Text('거래 모드',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  ChoiceChip(
                    label: const Text('모의투자', style: TextStyle(fontSize: 12)),
                    selected: isMock,
                    onSelected: (_) => setDialogState(() => isMock = true),
                    selectedColor: AppTheme.profitLight,
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('실전투자', style: TextStyle(fontSize: 12)),
                    selected: !isMock,
                    onSelected: (_) => setDialogState(() => isMock = false),
                    selectedColor: AppTheme.lossLight,
                  ),
                ]),
                if (!isMock)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.lossLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ 실전투자 선택 시 실제 돈으로 거래됩니다!',
                      style: TextStyle(fontSize: 11, color: AppTheme.loss,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 16),

                // App Key
                const Text('App Key',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: appKeyCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'PS0000000000000000000000000000000000',
                    hintStyle: const TextStyle(fontSize: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_outlined, size: 18),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          appKeyCtrl.text = data!.text!.trim();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // App Secret
                const Text('App Secret',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: appSecretCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'App Secret 입력',
                    hintStyle: const TextStyle(fontSize: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_outlined, size: 18),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          appSecretCtrl.text = data!.text!.trim();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 계좌번호
                const Text('계좌번호',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: accountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '8자리 계좌번호 (숫자만)',
                    hintStyle: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🔒 입력된 키는 AES-256-GCM으로 암호화 저장됩니다.\n'
                    '서버 외부로 전송되지 않습니다.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final appKey = appKeyCtrl.text.trim();
                      final appSecret = appSecretCtrl.text.trim();
                      final accountNo = accountCtrl.text.trim();

                      if (appKey.isEmpty || appSecret.isEmpty || accountNo.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('모든 항목을 입력하세요')),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      try {
                        await provider.connectBrokerAccount(
                          appKey: appKey,
                          appSecret: appSecret,
                          accountNo: accountNo,
                          isMock: isMock,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${isMock ? "모의투자" : "실전투자"} 계좌 연동 완료!'),
                              backgroundColor: AppTheme.profit,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('연동 실패: $e'),
                              backgroundColor: AppTheme.loss,
                            ),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('연동하기'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatWon(double v) {
    if (v >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}억';
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(0)}만';
    return '${v.toStringAsFixed(0)}원';
  }
}

// ── 공통 위젯 ────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.textSecondary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18,
                color: iconColor ?? AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppTheme.textTertiary)),
            ]),
          ),
          trailing ??
              const Icon(Icons.chevron_right,
                  size: 18, color: AppTheme.textTertiary),
        ]),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textTertiary)),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.primary,
          activeTrackColor: AppTheme.primary.withValues(alpha: 0.3),
        ),
      ]),
    );
  }
}
