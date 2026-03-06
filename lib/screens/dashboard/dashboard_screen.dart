// lib/screens/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/trading_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/stat_card.dart';
import '../../models/stock_model.dart';

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
                      _buildStatsRow(context, provider),
                      _buildPnlChart(context, provider),
                      _buildPositions(context, provider),
                      _buildWatchlistPreview(context, provider),
                      _buildRecentTrades(context, provider),
                      const SizedBox(height: 80),
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
          onPressed: () {},
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.divider),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, TradingProvider provider) {
    if (!provider.isCircuitBreaker) {
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
                provider.marketSentiment,
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
    if (provider.positions.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 포지션', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            const Center(
              child: Text('보유 종목 없음',
                  style: TextStyle(color: AppTheme.textTertiary)),
            ),
          ],
        ),
      );
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
                Text('AI 선정 ${provider.watchlist.length}종목',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppTheme.textTertiary)),
              ],
            ),
          ),
          ...provider.watchlist.asMap().entries.map((e) {
            return _WatchlistRow(
              rank: e.key + 1,
              stock: e.value,
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRecentTrades(BuildContext context, TradingProvider provider) {
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
          ...provider.recentTrades.map((trade) => _TradeTile(trade: trade)),
          const SizedBox(height: 4),
        ],
      ),
    );
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
