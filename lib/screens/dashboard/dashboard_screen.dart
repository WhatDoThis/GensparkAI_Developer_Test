// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/trading_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/stat_card.dart';
import '../../models/stock_model.dart';
import '../trading_setup/trading_setup_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<TradingProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: () async => provider.refreshData(),
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context, provider),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildStatusBanner(context, provider),
                      _buildTradingControlCard(context, provider),
                      _buildStatsRow(context, provider),
                      _buildPnlChart(context, provider),
                      _buildPositions(context, provider),
                      _buildWatchlistPreview(context, provider),
                      _buildRecentTrades(context, provider),
                      _buildEmptyStateHint(context, provider),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 데이터 없을 때 안내 카드 (스크롤 끝 빈 화면 방지)
  Widget _buildEmptyStateHint(BuildContext context, TradingProvider provider) {
    final hasData = provider.positions.isNotEmpty ||
        provider.watchlist.isNotEmpty ||
        provider.recentTrades.isNotEmpty;
    if (hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.rocket_launch_outlined,
              size: 36, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            '자동매매를 시작할 준비가 됐어요',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '위의 \'설정\' 버튼을 눌러 일일 예산을 설정하고\n\n'
            '매매 시작 버튼을 누르면 AI가 종목을 선정합니다.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _guideStep(context, '1', 'KIS API 연동',
                    '더보기 → 설정 → 한국투자증권'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _guideStep(
                    context, '2', '예산 설정', '위 [설정] → 일일 예산 입력'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _guideStep(context, '3', '매매 시작', '[시작] 버튼 클릭'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guideStep(BuildContext context, String num, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(desc,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textTertiary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, TradingProvider provider) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppTheme.surface,
      title: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.auto_graph, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text('AutoTradeX',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primary, fontWeight: FontWeight.w700)),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: provider.isMarketOpen
                ? AppTheme.profitLight
                : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: provider.isMarketOpen
                      ? AppTheme.profit
                      : AppTheme.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                provider.isMarketOpen ? '장중' : '장마감',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: provider.isMarketOpen
                          ? AppTheme.profit
                          : AppTheme.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: AppTheme.textSecondary,
          tooltip: '알림 설정',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('알림 설정은 더보기 → 설정 → 앱 알림에서 변경하세요'),
                    ),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: '이동',
                  textColor: AppTheme.primary,
                  onPressed: () {
                    Navigator.of(context).pushNamed('/settings');
                  },
                ),
              ),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.divider),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, TradingProvider provider) {
    // 서킷브레이커 발동 시에만 배너 표시, 아닌 경우 숨김
    if (!provider.isCircuitBreaker) {
      final sentiment = provider.marketSentiment;
      // marketSentiment가 기본값이거나 비어있으면 배너 숨김
      if (sentiment.isEmpty || sentiment == '시장 데이터 로딩 중...') {
        return const SizedBox.shrink();
      }
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.smart_toy_outlined,
                color: AppTheme.primary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sentiment,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.lossLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.loss.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.loss, size: 16),
          const SizedBox(width: 8),
          Text('서킷브레이커 발동 — 거래 중단',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.loss, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, TradingProvider provider) {
    final profit = provider.dailyProfitRate;
    final score = provider.dailyScore;
    final wr = provider.winRate;
    final trades = provider.todayTradeCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              label: '오늘 수익',
              value: formatPercent(profit),
              subtitle: profit >= 5 ? '🎯 목표 달성!' : '목표 5%',
              valueColor: profit >= 0 ? AppTheme.profit : AppTheme.loss,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCard(
              label: '오늘 점수',
              value: formatScore(score),
              subtitle: '목표 30pt',
              valueColor: score >= 0 ? AppTheme.primary : AppTheme.loss,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCard(
              label: '승률',
              value: '${wr.toStringAsFixed(0)}%',
              subtitle: '목표 60%',
              valueColor: wr >= 60 ? AppTheme.profit : AppTheme.warning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatCard(
              label: '거래수',
              value: '$trades회',
              subtitle: '최대 100회',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnlChart(BuildContext context, TradingProvider provider) {
    final history = provider.pnlHistory;
    if (history.isEmpty) return const SizedBox.shrink();

    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.profitRate);
    }).toList();

    final minY = history.map((p) => p.profitRate).reduce((a, b) => a < b ? a : b);
    final maxY = history.map((p) => p.profitRate).reduce((a, b) => a > b ? a : b);
    final currentRate = history.last.profitRate;
    final lineColor = currentRate >= 0 ? AppTheme.profit : AppTheme.loss;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('오늘 PnL',
                  style: Theme.of(context).textTheme.titleMedium),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPercent(currentRate),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: lineColor, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    formatWonCompact(
                        (provider.account?.totalBalance ?? 0) -
                            (provider.account?.totalBalance ?? 10000000) /
                                (1 + currentRate / 100) *
                                (currentRate / 100)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppTheme.divider,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 8,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= history.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            formatTime(history[idx].time).substring(0, 5),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: lineColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                minY: (minY - 0.5).floorToDouble(),
                maxY: (maxY + 0.5).ceilToDouble(),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.textPrimary,
                    getTooltipItems: (spots) => spots.map((s) {
                      return LineTooltipItem(
                        formatPercent(s.y),
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositions(BuildContext context, TradingProvider provider) {
    // 포지션 없을 때 섹션 자체를 숨김 (빈 공간 방지)
    if (provider.positions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('현재 포지션',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('${provider.positions.length}종목',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppTheme.textTertiary)),
              ],
            ),
          ),
          ...provider.positions.map((pos) => _PositionTile(position: pos)),
        ],
      ),
    );
  }

  Widget _buildWatchlistPreview(BuildContext context, TradingProvider provider) {
    final list = provider.watchlist;
    // 워치리스트 없을 때 섹션 숨김
    if (list.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('오늘의 워치리스트',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('AI 선정 ${list.length}종목',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppTheme.textTertiary)),
              ],
            ),
          ),
          ...list.asMap().entries.map((e) =>
              _WatchlistRow(rank: e.key + 1, stock: e.value)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRecentTrades(BuildContext context, TradingProvider provider) {
    final trades = provider.recentTrades;
    // 거래 없을 때 섹션 숨김
    if (trades.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            child: Text('최근 거래 로그',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ...trades.map((trade) => _TradeTile(trade: trade)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── 매매 컨트롤 카드 (DashboardScreen 메서드) ─────────────
  Widget _buildTradingControlCard(BuildContext context, TradingProvider provider) {
    final isRunning = provider.isTradingRunning;
    final isLoading = provider.isStatusLoading;
    final stats = provider.todayStats;
    final cfg = provider.tradingSettings;

    final pnl = (stats['pnl'] as num?)?.toDouble() ?? 0.0;
    final tradeCount = (stats['tradeCount'] as num?)?.toInt() ?? 0;
    final consecutive = (stats['consecutiveLosses'] as num?)?.toInt() ?? 0;
    final remaining = (stats['remainingBudget'] as num?)?.toDouble() ?? 0.0;
    final isLossFloor = stats['isLossFloorReached'] as bool? ?? false;
    final budget = (cfg['dailyBudget'] as num?)?.toDouble() ?? 0.0;

    Color statusColor = isRunning
        ? const Color(0xFF00D09E)
        : isLossFloor
            ? const Color(0xFFFF5252)
            : const Color(0xFF8B9CB5);

    String statusLabel = isRunning ? '자동매매 중' : isLossFloor ? '손실 중단' : '대기중';
    IconData statusIcon = isRunning
        ? Icons.play_circle
        : isLossFloor
            ? Icons.warning_amber_rounded
            : Icons.pause_circle_outline;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF00D09E).withValues(alpha: 0.4)
              : AppTheme.border,
          width: isRunning ? 1.5 : 1,
        ),
        boxShadow: isRunning
            ? [BoxShadow(
                color: const Color(0xFF00D09E).withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRunning)
                        Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: statusColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                            )],
                          ),
                        ),
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TradingSetupScreen()),
                  ).then((_) => provider.fetchTradingStatus()),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('설정', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (budget > 0) ...[
              Row(
                children: [
                  _statChip('일일예산', '${(budget / 10000).toStringAsFixed(0)}만', AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  _statChip('잔여', '${(remaining / 10000).toStringAsFixed(0)}만',
                      isLossFloor ? const Color(0xFFFF5252) : AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  _statChip('거래', '${tradeCount}회', AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  _statChip('손익', '${pnl >= 0 ? '+' : ''}${(pnl / 10000).toStringAsFixed(1)}만',
                      pnl >= 0 ? const Color(0xFF00D09E) : const Color(0xFFFF5252)),
                ],
              ),
              if (consecutive > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFFB74D)),
                    const SizedBox(width: 4),
                    Text('연속 손실 ${consecutive}회',
                        style: const TextStyle(
                          fontSize: 12, color: Color(0xFFFFB74D), fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '거래 설정을 완료하면 자동매매를 시작할 수 있습니다',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: isLoading
                      ? const Center(child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                      : isRunning
                          ? _actionButton(
                              label: '중지',
                              icon: Icons.stop_rounded,
                              color: const Color(0xFFFF5252),
                              onTap: () => _handleStop(context, provider),
                            )
                          : _actionButton(
                              label: budget > 0 ? '시작' : '설정 필요',
                              icon: Icons.play_arrow_rounded,
                              color: budget > 0 ? const Color(0xFF00D09E) : AppTheme.textSecondary,
                              onTap: budget > 0 ? () => _handleStart(context, provider) : null,
                            ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isRunning || isLoading ? null : () => _handleReset(context, provider),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('초기화', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: onTap != null ? color : AppTheme.surfaceVariant,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleStart(BuildContext context, TradingProvider provider) async {
    final err = await provider.startTrading();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시작 실패: $err'), backgroundColor: Colors.red));
    }
  }

  Future<void> _handleStop(BuildContext context, TradingProvider provider) async {
    final err = await provider.stopTrading();
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('중지 실패: $err'), backgroundColor: Colors.red));
    }
  }

  Future<void> _handleReset(BuildContext context, TradingProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('설정 초기화'),
        content: const Text('모든 거래 설정이 초기화됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      final err = await provider.resetTradingSettings();
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초기화 실패: $err'), backgroundColor: Colors.red));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정이 초기화되었습니다')));
      }
    }
  }
}

class _PositionTile extends StatelessWidget {
  final Position position;
  const _PositionTile({required this.position});

  @override
  Widget build(BuildContext context) {
    final color = position.isProfit ? AppTheme.profit : AppTheme.loss;
    final bg = position.isProfit ? AppTheme.profitLight : AppTheme.lossLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(position.stockName,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${formatNumber(position.quantity)}주 · 평균 ${formatNumber(position.avgPrice)}원',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _ProgressBar(
                      value: (position.currentPrice - position.stopLossPrice) /
                          (position.targetPrice - position.stopLossPrice),
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '목표 ${formatNumber(position.targetPrice)} / 손절 ${formatNumber(position.stopLossPrice)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  formatPercent(position.profitRate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatWon(position.profitAmount.abs()),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: color),
              ),
              Text(
                formatNumber(position.currentPrice),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;

  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80, height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: AppTheme.divider,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

class _WatchlistRow extends StatelessWidget {
  final int rank;
  final WatchStock stock;
  const _WatchlistRow({required this.rank, required this.stock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stock.stockName,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(stock.theme,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.primary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    '스코어 ${stock.totalScore.toStringAsFixed(0)}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stock.recommendationColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stock.recommendationLabel,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: stock.recommendationColor,
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                formatNumber(stock.currentPrice),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TradeTile extends StatelessWidget {
  final Trade trade;
  const _TradeTile({required this.trade});

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.tradeType == TradeType.buy;
    final color = isBuy
        ? AppTheme.primary
        : (trade.isProfit ? AppTheme.profit : AppTheme.loss);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isBuy ? Icons.arrow_upward : Icons.arrow_downward,
              color: color, size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isBuy ? '매수' : '매도',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: color, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Text(trade.stockName,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (!isBuy && trade.sellReason != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          trade.sellReasonLabel,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: color),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatNumber(trade.quantity)}주 · ${formatNumber(trade.price)}원',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isBuy && trade.profitRate != null)
                Text(
                  formatPercent(trade.profitRate!),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color, fontWeight: FontWeight.w600),
                ),
              Text(
                formatTimeAgo(trade.executedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
