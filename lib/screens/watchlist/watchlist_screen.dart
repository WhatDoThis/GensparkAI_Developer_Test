// lib/screens/watchlist/watchlist_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trading_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../models/stock_model.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('워치리스트'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () =>
                context.read<TradingProvider>().refreshData(),
          ),
        ],
      ),
      body: Consumer<TradingProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              _buildHeader(context, provider),
              const SizedBox(height: 12),
              ...provider.watchlist.asMap().entries.map((e) =>
                _StockScoreCard(rank: e.key + 1, stock: e.value)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TradingProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined,
                  color: AppTheme.primary, size: 16),
              const SizedBox(width: 6),
              Text('AI 종목 선정 완료',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primary)),
              const Spacer(),
              Text(formatDate(DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            provider.marketSentiment,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ScoreSummaryChip(
                label: '매수',
                count: provider.watchlist
                    .where((s) => s.recommendation == Recommendation.buy)
                    .length,
                color: AppTheme.profit,
              ),
              const SizedBox(width: 8),
              _ScoreSummaryChip(
                label: '관망',
                count: provider.watchlist
                    .where((s) => s.recommendation == Recommendation.watch)
                    .length,
                color: AppTheme.warning,
              ),
              const SizedBox(width: 8),
              _ScoreSummaryChip(
                label: '회피',
                count: provider.watchlist
                    .where((s) => s.recommendation == Recommendation.avoid)
                    .length,
                color: AppTheme.loss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreSummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ScoreSummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StockScoreCard extends StatefulWidget {
  final int rank;
  final WatchStock stock;
  const _StockScoreCard({required this.rank, required this.stock});

  @override
  State<_StockScoreCard> createState() => _StockScoreCardState();
}

class _StockScoreCardState extends State<_StockScoreCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.stock;
    final recColor = s.recommendationColor;
    final recBg = recColor.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: s.recommendation == Recommendation.buy
              ? AppTheme.profit.withValues(alpha: 0.3)
              : AppTheme.divider,
        ),
      ),
      child: Column(
        children: [
          // 헤더 행
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 순위
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: widget.rank <= 2
                              ? AppTheme.primary
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${widget.rank}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: widget.rank <= 2
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 종목명
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(s.stockName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(width: 6),
                                Text(
                                  s.stockCode,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: AppTheme.textTertiary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryLight,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    s.theme,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: AppTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 스코어 + 추천
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${s.totalScore.toStringAsFixed(1)}pt',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: recBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s.recommendationLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                          color: recColor,
                                          fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatNumber(s.currentPrice)}원',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 스코어 바
                  _ScoreBreakdownBar(stock: s),
                  const SizedBox(height: 8),
                  // 목표가 / 손절가
                  Row(
                    children: [
                      Expanded(
                        child: _PriceTarget(
                          label: '목표가',
                          price: s.targetPrice,
                          rateText: formatPercent(s.profitRateToTarget),
                          color: AppTheme.profit,
                        ),
                      ),
                      Container(
                          width: 1, height: 28, color: AppTheme.divider),
                      Expanded(
                        child: _PriceTarget(
                          label: '손절가',
                          price: s.stopLossPrice,
                          rateText: formatPercent(s.riskRateToStop),
                          color: AppTheme.loss,
                        ),
                      ),
                      Container(
                          width: 1, height: 28, color: AppTheme.divider),
                      Expanded(
                        child: _PriceTarget(
                          label: 'AI 신뢰도',
                          price: -1,
                          rateText: '${s.aiConfidence.toStringAsFixed(0)}%',
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  // 접기/펼치기 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppTheme.textTertiary,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 상세 확장 패널
          if (_expanded) ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 기술적 지표
                  Text('기술적 지표',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: [
                      _IndicatorChip(label: 'RSI', value: s.rsi.toStringAsFixed(1),
                          good: s.rsi < 45),
                      _IndicatorChip(label: 'MACD', value: s.macd.toStringAsFixed(2),
                          good: s.macd > s.macdSignal),
                      _IndicatorChip(label: '거래량', value: '${s.volumeRatio.toStringAsFixed(1)}x',
                          good: s.volumeRatio >= 2.0),
                      _IndicatorChip(label: 'Stoch', value: '${s.stochasticK.toStringAsFixed(1)}',
                          good: s.stochasticK < 30),
                      _IndicatorChip(label: '5MA', value: formatNumber(s.ma5.toInt()),
                          good: s.ma5 > s.ma20),
                      _IndicatorChip(label: '볼밴상단', value: formatNumber(s.bollingerUpper.toInt()),
                          good: false),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // AI 판단 이유
                  Text('AI 분석',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      s.aiReasoning,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 진입 조건
                  Text('진입 조건',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text(s.entryCondition,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreBreakdownBar extends StatelessWidget {
  final WatchStock stock;
  const _ScoreBreakdownBar({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BarRow(label: '테마', value: stock.themeRelevance, color: AppTheme.primary),
        const SizedBox(height: 4),
        _BarRow(label: '기술', value: stock.technicalScore, color: AppTheme.profit),
        const SizedBox(height: 4),
        _BarRow(label: '거래량', value: stock.volumeScore, color: AppTheme.warning),
        const SizedBox(height: 4),
        _BarRow(label: 'AI', value: stock.aiConfidence, color: const Color(0xFF9C27B0)),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BarRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.textTertiary)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            value.toStringAsFixed(0),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _PriceTarget extends StatelessWidget {
  final String label;
  final int price;
  final String rateText;
  final Color color;

  const _PriceTarget({
    required this.label,
    required this.price,
    required this.rateText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.textTertiary)),
          const SizedBox(height: 2),
          Text(
            rateText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color, fontWeight: FontWeight.w700),
          ),
          if (price > 0)
            Text(
              '${formatNumber(price)}원',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _IndicatorChip extends StatelessWidget {
  final String label;
  final String value;
  final bool good;

  const _IndicatorChip({
    required this.label,
    required this.value,
    required this.good,
  });

  @override
  Widget build(BuildContext context) {
    final color = good ? AppTheme.profit : AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: good
            ? AppTheme.profitLight
            : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: good
              ? AppTheme.profit.withValues(alpha: 0.3)
              : AppTheme.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.textTertiary)),
          const SizedBox(width: 4),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
