// lib/screens/ai_logs/ai_logs_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/trading_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../models/stock_model.dart';

class AiLogsScreen extends StatelessWidget {
  const AiLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('AI 판단 로그')),
      body: Consumer<TradingProvider>(
        builder: (context, provider, _) {
          final logs = provider.aiLogs;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              _buildStats(context, logs),
              const SizedBox(height: 12),
              ...logs.map((log) => _AiLogCard(log: log)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStats(BuildContext context, List<AiDecisionLog> logs) {
    final correct = logs.where((l) => l.wasCorrect == true).length;
    final incorrect = logs.where((l) => l.wasCorrect == false).length;
    final pending = logs.where((l) => l.wasCorrect == null).length;
    final verified = correct + incorrect;
    final accuracy = verified > 0 ? correct / verified * 100 : 0.0;

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
                  size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('AI 판단 정확도',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: '정확',
                  value: '$correct',
                  color: AppTheme.profit,
                ),
              ),
              Expanded(
                child: _StatBox(
                  label: '오판',
                  value: '$incorrect',
                  color: AppTheme.loss,
                ),
              ),
              Expanded(
                child: _StatBox(
                  label: '검증 중',
                  value: '$pending',
                  color: AppTheme.warning,
                ),
              ),
              Expanded(
                child: _StatBox(
                  label: '정확도',
                  value: verified > 0
                      ? '${accuracy.toStringAsFixed(0)}%'
                      : '-',
                  color: accuracy >= 65 ? AppTheme.profit : AppTheme.warning,
                ),
              ),
            ],
          ),
          if (verified > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: accuracy / 100,
                backgroundColor: AppTheme.divider,
                valueColor:
                    const AlwaysStoppedAnimation(AppTheme.primary),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'KPI 목표 65% ${accuracy >= 65 ? "✓ 달성" : "미달"}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        accuracy >= 65 ? AppTheme.profit : AppTheme.loss),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _AiLogCard extends StatefulWidget {
  final AiDecisionLog log;
  const _AiLogCard({required this.log});

  @override
  State<_AiLogCard> createState() => _AiLogCardState();
}

class _AiLogCardState extends State<_AiLogCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final decisionColor = log.decisionColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 판단 타입 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: decisionColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.decisionLabel,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                  color: decisionColor,
                                  fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.stockCode == 'MARKET'
                              ? log.stockName
                              : '${log.stockName} (${log.stockCode})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      // 신뢰도
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${log.confidence.toStringAsFixed(0)}%',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 출력 결론
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.outputDecision,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            formatTimeAgo(log.createdAt),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppTheme.textTertiary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            log.modelUsed,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppTheme.textTertiary),
                          ),
                          if (log.wasCorrect != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              log.wasCorrect!
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 14,
                              color: log.wasCorrect!
                                  ? AppTheme.profit
                                  : AppTheme.loss,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              log.wasCorrect! ? '정확' : '오판',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: log.wasCorrect!
                                          ? AppTheme.profit
                                          : AppTheme.loss),
                            ),
                          ] else ...[
                            const SizedBox(width: 8),
                            Text(
                              '검증 중',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppTheme.warning),
                            ),
                          ],
                        ],
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppTheme.textTertiary, size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 확장 - 입력 데이터
            if (_expanded) ...[
              const Divider(height: 1, color: AppTheme.divider),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI 입력 데이터',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        log.inputSummary,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 신뢰도 바
                    Row(
                      children: [
                        Text('신뢰도',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppTheme.textTertiary)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: log.confidence / 100,
                              backgroundColor: AppTheme.divider,
                              valueColor:
                                  const AlwaysStoppedAnimation(AppTheme.primary),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${log.confidence.toStringAsFixed(0)}%',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
