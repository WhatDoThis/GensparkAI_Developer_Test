// lib/utils/formatters.dart
import 'package:intl/intl.dart';

final _wonFormatter = NumberFormat('#,###', 'ko_KR');
final _dateFormatter = DateFormat('MM/dd', 'ko_KR');
final _dateTimeFormatter = DateFormat('MM/dd HH:mm', 'ko_KR');
final _timeFormatter = DateFormat('HH:mm:ss', 'ko_KR');

String formatWon(num value) => '${_wonFormatter.format(value)}원';
String formatWonCompact(num value) {
  if (value.abs() >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(1)}억원';
  } else if (value.abs() >= 10000) {
    return '${(value / 10000).toStringAsFixed(0)}만원';
  }
  return formatWon(value);
}

String formatNumber(num value) => _wonFormatter.format(value);

String formatPercent(double value, {int decimals = 1}) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(decimals)}%';
}

String formatScore(double value, {int decimals = 1}) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(decimals)}pt';
}

String formatDate(DateTime dt) => _dateFormatter.format(dt);
String formatDateTime(DateTime dt) => _dateTimeFormatter.format(dt);
String formatTime(DateTime dt) => _timeFormatter.format(dt);

String formatTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return formatDate(dt);
}
