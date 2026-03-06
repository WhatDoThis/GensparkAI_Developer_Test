// lib/screens/reports/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/trading_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../models/stock_model.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('리포트')),
      body: Consumer<TradingProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              if (provider.todayReport != null) ...[
                _buildTodayReport(context, provider),
                const SizedBox(height: 12),
              ],
              _buildWeeklyChart(context, provider),
              const SizedBox(height: 12),
              _buildReportList(context, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTodayReport(BuildContext context, TradingProvider provider) {
    final report = provider.todayReport!;
    final isGoalMet = report.metDailyTarget;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGoalMet
              ? [AppTheme.profitLight, AppTheme.surface]
              : [AppTheme.surfaceVariant, AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGoalMet
              ? AppTheme.profit.withValues(alpha: 0.3)
              : AppTheme.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('오늘 리포트',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (isGoalMet)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.profit,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🎯 목표 달성!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // 핵심 지표 2x2
          Row(
            children: [
              Expanded(
                child: _ReportKpi(
                  label: '총 수익률',
                  value: formatPercent(report.totalProfitRate),
                  valueColor: report.totalProfitRate >= 0
                      ? AppTheme.profit
                      : AppTheme.loss,
                ),
              ),
              Expanded(
                child: _ReportKpi(
                  label: '총 점수',
                  value: formatScore(report.totalScore),
                  valueColor: report.totalScore >= 0
                      ? AppTheme.primary
                      : AppTheme.loss,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ReportKpi(
                  label: '승률',
                  value: '${report.winRate.toStringAsFixed(0)}%',
                  valueColor: report.winRate >= 60
                      ? AppTheme.profit
                      : AppTheme.warning,
                ),
              ),
              Expanded(
                child: _ReportKpi(
                  label: '거래 / 대기',
                  value: '${report.totalTrades} / ${report.waitCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // AI 코멘트
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text('AI 평가',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(report.marketSentiment,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primary)),
                if (report.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...report.recommendations.map((r) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('•  ',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.primary)),
                            Expanded(
                              child: Text(r,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.primary)),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, TradingProvider provider) {
    final reports = provider.reports.reversed.toList();
    if (reports.isEmpty) return const SizedBox.shrink();

    final barGroups = reports.asMap().entries.map((e) {
      final r = e.value;
      final v = r.totalProfitRate;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: v,
            color: v >= 5
                ? AppTheme.profit
                : v >= 0
                    ? AppTheme.primary
                    : AppTheme.loss,
            width: 20,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    }).toList();

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
          Text('최근 7일 수익률',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppTheme.divider, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= reports.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            formatDate(reports[idx].date),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: 5,
                    color: AppTheme.profit.withValues(alpha: 0.4),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      labelResolver: (_) => '목표 5%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.profit,
                          ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _Legend(color: AppTheme.profit, label: '목표 달성'),
              const SizedBox(width: 12),
              _Legend(color: AppTheme.primary, label: '수익'),
              const SizedBox(width: 12),
              _Legend(color: AppTheme.loss, label: '손실'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportList(BuildContext context, TradingProvider provider) {
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
            child:
                Text('일별 리포트', style: Theme.of(context).textTheme.titleMedium),
          ),
          ...provider.reports.asMap().entries.map((e) =>
              _DailyReportTile(report: e.value, showDivider: e.key > 0)),
        ],
      ),
    );
  }
}

class _ReportKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ReportKpi({
    required this.label,
    required this.value,
    this.valueColor,
  });

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
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: valueColor ?? AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _DailyReportTile extends StatelessWidget {
  final DailyReport report;
  final bool showDivider;

  const _DailyReportTile({
    required this.report,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final color = report.totalProfitRate >= 0 ? AppTheme.profit : AppTheme.loss;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(top: BorderSide(color: AppTheme.divider))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(formatDate(report.date),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                    if (report.metDailyTarget)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.profitLight,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text('목표달성',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppTheme.profit)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${report.profitTrades}익 / ${report.lossTrades}손 · '
                  '승률 ${report.winRate.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPercent(report.totalProfitRate),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color, fontWeight: FontWeight.w700),
              ),
              Text(
                formatScore(report.totalScore),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppTheme.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
