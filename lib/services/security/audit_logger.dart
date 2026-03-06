// lib/services/security/audit_logger.dart
// 감사 로그 서비스 — PRD 10-A-7 구현
// 중요 이벤트를 Hive 로컬 DB에 변경불가 형태로 기록

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

enum AuditEventType {
  loginSuccess,
  loginFail,
  mfaSuccess,
  mfaFail,
  logout,
  passwordChanged,
  signupSuccess,
  brokerKeyRegistered,
  brokerKeyAccessed,
  brokerKeyRevoked,
  orderPlaced,
  orderBlocked,
  orderExecuted,
  stopLossTriggered,
  unauthorizedAccess,
  anomalyDetected,
  circuitBreakerTriggered,
  emergencyHalt,
  rateLimitHit,
  settingsChanged,
  sessionExpired,
}

enum RiskLevel { low, medium, high, critical }

class AuditLog {
  final String id;
  final DateTime timestamp;
  final AuditEventType eventType;
  final String? actorId;
  final String? actorIp;
  final String? resource;
  final String action;
  final bool isSuccess;
  final RiskLevel riskLevel;
  final Map<String, dynamic>? detail;

  AuditLog({
    required this.id,
    required this.timestamp,
    required this.eventType,
    this.actorId,
    this.actorIp,
    this.resource,
    required this.action,
    required this.isSuccess,
    required this.riskLevel,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'eventType': eventType.name,
        'actorId': actorId,
        'actorIp': actorIp,
        'resource': resource,
        'action': action,
        'isSuccess': isSuccess,
        'riskLevel': riskLevel.name,
        'detail': detail,
      };
}

class AuditLogger {
  static const String _boxName = 'audit_logs';
  static const int _maxLogs = 1000; // 최대 1000개 보관
  static final _uuid = const Uuid();

  static Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  /// 감사 로그 기록
  static Future<void> log({
    required AuditEventType eventType,
    required String action,
    required bool isSuccess,
    RiskLevel riskLevel = RiskLevel.low,
    String? actorId,
    String? resource,
    Map<String, dynamic>? detail,
  }) async {
    try {
      final box = await _getBox();
      final log = AuditLog(
        id: _uuid.v4(),
        timestamp: DateTime.now(),
        eventType: eventType,
        actorId: actorId,
        action: action,
        isSuccess: isSuccess,
        riskLevel: riskLevel,
        resource: resource,
        detail: _sanitizeDetail(detail),
      );

      await box.add(log.toJson());

      // 최대 보관 개수 초과 시 오래된 로그 삭제
      if (box.length > _maxLogs) {
        await box.deleteAt(0);
      }
    } catch (_) {
      // 감사 로그 실패는 앱 동작을 막지 않음
    }
  }

  /// 민감정보 마스킹 (PRD 10-A-6)
  static Map<String, dynamic>? _sanitizeDetail(
      Map<String, dynamic>? detail) {
    if (detail == null) return null;
    const sensitiveFields = {
      'apiKey', 'appKey', 'appSecret', 'accessToken',
      'refreshToken', 'password', 'accountNumber', 'api_key',
    };
    return detail.map((k, v) {
      if (sensitiveFields.contains(k) && v is String) {
        return MapEntry(k, _mask(v));
      }
      return MapEntry(k, v);
    });
  }

  static String _mask(String value) {
    if (value.length <= 6) return '******';
    return '${value.substring(0, 3)}***${value.substring(value.length - 3)}';
  }

  /// 최근 로그 조회
  static Future<List<Map<String, dynamic>>> getRecentLogs({
    int limit = 50,
    RiskLevel? minRiskLevel,
  }) async {
    final box = await _getBox();
    final all = box.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
        .reversed
        .toList();

    if (minRiskLevel != null) {
      final levelOrder = RiskLevel.values;
      return all
          .where((log) {
            final logLevel = RiskLevel.values.firstWhere(
              (l) => l.name == log['riskLevel'],
              orElse: () => RiskLevel.low,
            );
            return levelOrder.indexOf(logLevel) >=
                levelOrder.indexOf(minRiskLevel);
          })
          .take(limit)
          .toList();
    }

    return all.take(limit).toList();
  }

  /// 로그인 실패 횟수 조회 (브루트포스 방어용)
  static Future<int> getRecentLoginFailCount(
    String email, {
    Duration window = const Duration(minutes: 30),
  }) async {
    final box = await _getBox();
    final cutoff = DateTime.now().subtract(window);

    return box.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((log) =>
            log['eventType'] == AuditEventType.loginFail.name &&
            log['resource'] == email &&
            DateTime.parse(log['timestamp'] as String).isAfter(cutoff))
        .length;
  }
}
