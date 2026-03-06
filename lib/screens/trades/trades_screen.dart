// lib/screens/trades/trades_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trading_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../models/stock_model.dart';

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('거래 현황'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '거래 이력'),
            Tab(text: '포지션'),
          ],
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.primary,
          dividerColor: AppTheme.divider,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TradeHistoryTab(),
          _PositionsTab(),
        ],
      ),
    );
  }
}

class _TradeHistoryTab extends StatelessWidget {
  const _TradeHistoryTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<TradingProvider>(
      builder: (context, provider, _) {
        final trades = provider.trades;
        if (trades.isEmpty) {
          return const Center(child: Text('거래 내역이 없습니다'));
        }

        // 통계 계산
        final sellTrades = trades.where((t) => t.tradeType == TradeType.sell);
        final profitTrades =
            sellTrades.where((t) => (t.profitRate ?? 0) > 0).toList();
        final lossTrades =
            sellTrades.where((t) => (t.profitRate ?? 0) <= 0).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            // 통계 카드
            _TradeStatsCard(
              totalTrades: trades.length,
              profitCount: profitTrades.length,
              lossCount: lossTrades.length,
              totalScore: trades
                  .fold<double>(0, (sum, t) => sum + (t.score ?? 0)),
            ),
            const SizedBox(height: 12),
            // 거래 목록
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: trades.asMap().entries.map((e) {
                  return _TradeDetailTile(
                    trade: e.value,
                    showDivider: e.key > 0,
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TradeStatsCard extends StatelessWidget {
  final int totalTrades;
  final int profitCount;
  final int lossCount;
  final double totalScore;

  const _TradeStatsCard({
    required this.totalTrades,
    required this.profitCount,
    required this.lossCount,
    required this.totalScore,
  });

  @override
  Widget build(BuildContext context) {
    final wr = totalTrades > 0
        ? (profitCount / (profitCount + lossCount)) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('거래 통계', style: Theme.of(context).textTheme.titleMedium),
              Text('총 $totalTrades건',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textTertiary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: '수익',
                  value: '$profitCount건',
                  color: AppTheme.profit,
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.divider),
              Expanded(
                child: _StatItem(
                  label: '손절',
                  value: '$lossCount건',
                  color: AppTheme.loss,
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.divider),
              Expanded(
                child: _StatItem(
                  label: '승률',
                  value: '${wr.toStringAsFixed(0)}%',
                  color: wr >= 60 ? AppTheme.profit : AppTheme.warning,
                ),
              ),
              Container(width: 1, height: 36, color: AppTheme.divider),
              Expanded(
                child: _StatItem(
                  label: '점수 합계',
                  value: formatScore(totalScore),
                  color: totalScore >= 0 ? AppTheme.primary : AppTheme.loss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textTertiary)),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TradeDetailTile extends StatelessWidget {
  final Trade trade;
  final bool showDivider;

  const _TradeDetailTile({
    required this.trade,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.tradeType == TradeType.buy;
    final profitRate = trade.profitRate;
    final color = isBuy
        ? AppTheme.primary
        : (trade.isProfit ? AppTheme.profit : AppTheme.loss);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(top: BorderSide(color: AppTheme.divider))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타입 아이콘
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                isBuy ? '매수' : '매도',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 종목 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(trade.stockName,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (!isBuy && trade.sellReason != null) ...[
                      const SizedBox(width: 6),
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
                const SizedBox(height: 3),
                Text(
                  '${formatNumber(trade.quantity)}주 · ${formatNumber(trade.price)}원 · '
                  '합계 ${formatWonCompact(trade.totalAmount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  formatDateTime(trade.executedAt),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          // 수익률 / 점수
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isBuy && profitRate != null) ...[
                Text(
                  formatPercent(profitRate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color, fontWeight: FontWeight.w700),
                ),
                if (trade.score != null)
                  Text(
                    formatScore(trade.score!),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppTheme.textTertiary),
                  ),
              ] else
                Text(
                  formatWonCompact(trade.totalAmount),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PositionsTab extends StatelessWidget {
  const _PositionsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<TradingProvider>(
      builder: (context, provider, _) {
        final positions = provider.positions;

        if (positions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 48, color: AppTheme.textTertiary),
                SizedBox(height: 12),
                Text('보유 포지션 없음',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          );
        }

        // 합산
        final totalValue =
            positions.fold<int>(0, (sum, p) => sum + p.totalValue);
        final totalProfit =
            positions.fold<int>(0, (sum, p) => sum + p.profitAmount);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            // 포지션 요약
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('평가금액',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: AppTheme.textTertiary)),
                      const SizedBox(height: 4),
                      Text(
                        formatWonCompact(totalValue),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('평가손익',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: AppTheme.textTertiary)),
                      const SizedBox(height: 4),
                      Text(
                        (totalProfit >= 0 ? '+' : '') +
                            formatWonCompact(totalProfit),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: totalProfit >= 0
                                  ? AppTheme.profit
                                  : AppTheme.loss,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...positions.map((pos) => _PositionDetailCard(position: pos)),
          ],
        );
      },
    );
  }
}

class _PositionDetailCard extends StatelessWidget {
  final Position position;
  const _PositionDetailCard({required this.position});

  @override
  Widget build(BuildContext context) {
    final color = position.isProfit ? AppTheme.profit : AppTheme.loss;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: position.isProfit
              ? AppTheme.profit.withValues(alpha: 0.3)
              : AppTheme.loss.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(position.stockName,
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(position.stockCode,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textTertiary)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPercent(position.profitRate),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${position.isProfit ? '+' : ''}${formatWon(position.profitAmount)}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 12),
          // 상세 지표
          Row(
            children: [
              Expanded(
                child: _DetailItem(label: '수량',
                    value: '${formatNumber(position.quantity)}주'),
              ),
              Expanded(
                child: _DetailItem(label: '평균단가',
                    value: '${formatNumber(position.avgPrice)}'),
              ),
              Expanded(
                child: _DetailItem(label: '현재가',
                    value: '${formatNumber(position.currentPrice)}'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 목표 / 손절 프로그레스
          Row(
            children: [
              Text('손절 ${formatNumber(position.stopLossPrice)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppTheme.loss)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ((position.currentPrice - position.stopLossPrice) /
                              (position.targetPrice - position.stopLossPrice))
                          .clamp(0.0, 1.0),
                      backgroundColor: AppTheme.lossLight,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                    ),
                  ),
                ),
              ),
              Text('목표 ${formatNumber(position.targetPrice)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppTheme.profit)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '최고 수익률: ${formatPercent(position.highestProfitRate)} · '
            '매수시간: ${formatTimeAgo(position.buyTime)}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textTertiary)),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
