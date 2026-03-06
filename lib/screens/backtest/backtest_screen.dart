// lib/screens/backtest/backtest_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';

class BacktestScreen extends StatefulWidget {
  const BacktestScreen({super.key});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  bool _isRunning = false;
  bool _hasResult = false;

  // 설정
  double _initialCapital = 10000000;
  int _startDaysAgo = 30;
  double _stopLossThreshold = -3.0;
  double _profitTakeMin = 2.0;
  double _profitTakeMax = 25.0;

  // 결과 (목업)
  final _mockResults = {
    'totalReturn': 18.4,
    'maxDrawdown': -7.2,
    'sharpeRatio': 1.42,
    'winRate': 68.5,
    'totalTrades': 47,
    'avgHoldingHours': 2.3,
    'profitDays': 19,
    'lossDays': 11,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('백테스팅')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          _buildConfig(context),
          const SizedBox(height: 12),
          if (_hasResult) ...[
            _buildResult(context),
            const SizedBox(height: 12),
            _buildReturnChart(context),
          ] else if (!_isRunning)
            _buildEmpty(context),
        ],
      ),
    );
  }

  Widget _buildConfig(BuildContext context) {
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
          Text('백테스트 설정',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          _ConfigRow(
            label: '초기 자금',
            value: formatWonCompact(_initialCapital),
            onEdit: () => _showSlider(
              context, '초기 자금 (만원)', _initialCapital / 10000, 100, 5000,
              (v) => setState(() => _initialCapital = v * 10000),
            ),
          ),
          const Divider(height: 16, color: AppTheme.divider),
          _ConfigRow(
            label: '테스트 기간',
            value: '최근 $_startDaysAgo일',
            onEdit: () => _showSlider(
              context, '기간 (일)', _startDaysAgo.toDouble(), 7, 90,
              (v) => setState(() => _startDaysAgo = v.toInt()),
            ),
          ),
          const Divider(height: 16, color: AppTheme.divider),
          _ConfigRow(
            label: '손절 기준',
            value: '${_stopLossThreshold.toStringAsFixed(1)}%',
            onEdit: () => _showSlider(
              context, '손절 기준 (%)', _stopLossThreshold.abs(), 1, 10,
              (v) => setState(() => _stopLossThreshold = -v),
            ),
          ),
          const Divider(height: 16, color: AppTheme.divider),
          _ConfigRow(
            label: '익절 범위',
            value:
                '${_profitTakeMin.toStringAsFixed(0)}% ~ ${_profitTakeMax.toStringAsFixed(0)}%',
            onEdit: () {},
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isRunning ? null : _runBacktest,
              child: _isRunning
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Text('분석 중...'),
                      ],
                    )
                  : const Text('백테스트 실행'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final r = _mockResults;
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
              Text('백테스트 결과',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.profitLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '최근 $_startDaysAgo일',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.profit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 핵심 지표 2x3
          Row(
            children: [
              Expanded(
                child: _ResultKpi(
                  label: '총 수익률',
                  value: formatPercent(r['totalReturn'] as double),
                  color: AppTheme.profit,
                ),
              ),
              Expanded(
                child: _ResultKpi(
                  label: '최대 낙폭',
                  value: formatPercent(r['maxDrawdown'] as double),
                  color: AppTheme.loss,
                ),
              ),
              Expanded(
                child: _ResultKpi(
                  label: '샤프 비율',
                  value: (r['sharpeRatio'] as double).toStringAsFixed(2),
                  color: (r['sharpeRatio'] as double) >= 1.0
                      ? AppTheme.profit
                      : AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ResultKpi(
                  label: '승률',
                  value: '${(r['winRate'] as double).toStringAsFixed(1)}%',
                  color: (r['winRate'] as double) >= 60
                      ? AppTheme.profit
                      : AppTheme.warning,
                ),
              ),
              Expanded(
                child: _ResultKpi(
                  label: '총 거래',
                  value: '${r['totalTrades']}회',
                ),
              ),
              Expanded(
                child: _ResultKpi(
                  label: '평균 보유',
                  value: '${(r['avgHoldingHours'] as double).toStringAsFixed(1)}h',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // KPI 통과 여부
          _KpiCheckRow(
            label: '일일 5% 수익률 달성일',
            value: '${r['profitDays']}일 / $_startDaysAgo일 중',
            passed: (r['profitDays'] as int) > _startDaysAgo ~/ 2,
          ),
          const SizedBox(height: 6),
          _KpiCheckRow(
            label: '최대 낙폭 10% 이내',
            value: '${(r['maxDrawdown'] as double).abs().toStringAsFixed(1)}%',
            passed: (r['maxDrawdown'] as double).abs() <= 10,
          ),
          const SizedBox(height: 6),
          _KpiCheckRow(
            label: '승률 60% 이상',
            value: '${(r['winRate'] as double).toStringAsFixed(1)}%',
            passed: (r['winRate'] as double) >= 60,
          ),
        ],
      ),
    );
  }

  Widget _buildReturnChart(BuildContext context) {
    // 누적 수익률 시뮬레이션
    final daily = [-0.5, 1.2, 3.4, 2.1, -1.8, 5.2, 4.3, -0.9, 2.8, 6.1,
                   3.5, -2.1, 1.9, 4.7, 2.3, 0.8, -1.5, 3.2, 5.8, 2.4,
                   -0.7, 1.4, 3.9, 2.6, 4.1, -1.3, 0.5, 3.7, 2.9, 1.8];

    double cumulative = 0;
    final spots = daily.sublist(0, _startDaysAgo.clamp(0, daily.length))
        .asMap()
        .entries
        .map((e) {
      cumulative += e.value;
      return FlSpot(e.key.toDouble(), cumulative);
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
          Text('누적 수익률 곡선',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
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
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.analytics_outlined,
              size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text('백테스트를 실행해보세요',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text(
            '실제 자금 투입 전 과거 데이터로 전략을 검증합니다',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _runBacktest() async {
    setState(() => _isRunning = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isRunning = false;
        _hasResult = true;
      });
    }
  }

  void _showSlider(BuildContext context, String title, double current,
      double min, double max, ValueChanged<double> onChanged) {
    double value = current;
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: 20,
                label: value.toStringAsFixed(0),
                activeColor: AppTheme.primary,
                onChanged: (v) => setSheetState(() => value = v),
              ),
              ElevatedButton(
                onPressed: () {
                  onChanged(value);
                  Navigator.pop(context);
                },
                child: const Text('적용'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _ConfigRow({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _ResultKpi({required this.label, required this.value, this.color});

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
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color ?? AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _KpiCheckRow extends StatelessWidget {
  final String label;
  final String value;
  final bool passed;

  const _KpiCheckRow({
    required this.label,
    required this.value,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppTheme.profit : AppTheme.loss;
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle_outline : Icons.cancel_outlined,
          color: color, size: 16,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
