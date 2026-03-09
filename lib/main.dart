// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'utils/app_theme.dart';
import 'providers/trading_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/auth_guard.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/watchlist/watchlist_screen.dart';
import 'screens/trades/trades_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/backtest/backtest_screen.dart';
import 'screens/ai_logs/ai_logs_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hive 초기화 (감사 로그 로컬 저장소)
  await Hive.initFlutter();
  runApp(const AutoTradeXApp());
}

class AutoTradeXApp extends StatelessWidget {
  const AutoTradeXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TradingProvider()),
      ],
      child: MaterialApp(
        title: 'AutoTradeX',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGuard(child: MainShell()),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    WatchlistScreen(),
    TradesScreen(),
    ReportsScreen(),
    _MoreScreen(),
  ];

  final _labels = ['대시보드', '워치리스트', '거래현황', '리포트', '더보기'];
  final _icons = [
    Icons.dashboard_outlined,
    Icons.star_outline,
    Icons.swap_horiz_outlined,
    Icons.bar_chart_outlined,
    Icons.more_horiz,
  ];
  final _selectedIcons = [
    Icons.dashboard,
    Icons.star,
    Icons.swap_horiz,
    Icons.bar_chart,
    Icons.more_horiz,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: List.generate(
            _labels.length,
            (i) => NavigationDestination(
              icon: Icon(_icons[i]),
              selectedIcon: Icon(_selectedIcons[i]),
              label: _labels[i],
            ),
          ),
        ),
      ),
    );
  }
}

// 더보기 화면 (백테스팅, AI 로그 진입점)
class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          _MoreTile(
            icon: Icons.analytics_outlined,
            title: '백테스팅',
            subtitle: '과거 데이터로 전략 검증',
            color: AppTheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BacktestScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _MoreTile(
            icon: Icons.smart_toy_outlined,
            title: 'AI 판단 로그',
            subtitle: 'AI 의사결정 이력 조회',
            color: const Color(0xFF9C27B0),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiLogsScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: '설정',
            subtitle: 'API 연동, 안전장치, 알림 설정',
            color: AppTheme.textSecondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          // 앱 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_graph,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AutoTradeX',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text('v1.0.0 — AI 기반 자동매매',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppTheme.divider),
                const SizedBox(height: 10),
                _InfoRow(label: 'AI 모델', value: 'OpenAI GPT-4o-mini'),
                const SizedBox(height: 6),
                _InfoRow(label: '지원 증권사', value: '한국투자증권(KIS)'),
                const SizedBox(height: 6),
                _InfoRow(label: '기술적 지표',
                    value: 'RSI · MACD · 볼린저밴드 · 스토캐스틱'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠️ 모든 투자 손실은 사용자 책임입니다. '
                    '반드시 모의투자로 검증 후 실투자 전환하세요.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.warning),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppTheme.textTertiary)),
        Text(value, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
