/**
 * AutoTradeX Audit Logger
 * PRD 10-A-7: 감사 로그 (audit_logs 테이블)
 */

const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../db/connection');
const { maskSensitive } = require('./crypto.service');

// PRD 명세 28개 이벤트 타입
const AuditEvent = {
  // 인증
  LOGIN_SUCCESS: 'LOGIN_SUCCESS',
  LOGIN_FAILURE: 'LOGIN_FAILURE',
  LOGIN_LOCKED: 'LOGIN_LOCKED',
  LOGOUT: 'LOGOUT',
  SIGNUP: 'SIGNUP',
  PASSWORD_CHANGE: 'PASSWORD_CHANGE',
  MFA_ENABLE: 'MFA_ENABLE',
  MFA_VERIFY: 'MFA_VERIFY',
  SESSION_REVOKE: 'SESSION_REVOKE',
  TOKEN_REFRESH: 'TOKEN_REFRESH',

  // API 키 관리
  API_KEY_REGISTER: 'API_KEY_REGISTER',
  API_KEY_ACCESS: 'API_KEY_ACCESS',
  API_KEY_ROTATE: 'API_KEY_ROTATE',
  API_KEY_DELETE: 'API_KEY_DELETE',

  // 주문 관련
  ORDER_PLACE: 'ORDER_PLACE',
  ORDER_CANCEL: 'ORDER_CANCEL',
  ORDER_FILLED: 'ORDER_FILLED',
  ORDER_REJECTED: 'ORDER_REJECTED',
  ORDER_INTEGRITY_FAIL: 'ORDER_INTEGRITY_FAIL',

  // 보안 이벤트
  UNAUTHORIZED_ACCESS: 'UNAUTHORIZED_ACCESS',
  CERT_PIN_MISMATCH: 'CERT_PIN_MISMATCH',
  ANOMALY_DETECTED: 'ANOMALY_DETECTED',
  RATE_LIMIT_HIT: 'RATE_LIMIT_HIT',
  CIRCUIT_BREAKER: 'CIRCUIT_BREAKER',

  // 시스템
  SYSTEM_START: 'SYSTEM_START',
  SYSTEM_HALT: 'SYSTEM_HALT',
  KEY_ROTATION: 'KEY_ROTATION',
  CONFIG_CHANGE: 'CONFIG_CHANGE',
};

const RiskLevel = {
  LOW: 'LOW',
  MEDIUM: 'MEDIUM',
  HIGH: 'HIGH',
  CRITICAL: 'CRITICAL',
};

// 이벤트별 기본 위험도
const DEFAULT_RISK = {
  LOGIN_SUCCESS: RiskLevel.LOW,
  LOGIN_FAILURE: RiskLevel.MEDIUM,
  LOGIN_LOCKED: RiskLevel.HIGH,
  LOGOUT: RiskLevel.LOW,
  SIGNUP: RiskLevel.LOW,
  PASSWORD_CHANGE: RiskLevel.MEDIUM,
  MFA_ENABLE: RiskLevel.MEDIUM,
  MFA_VERIFY: RiskLevel.LOW,
  SESSION_REVOKE: RiskLevel.MEDIUM,
  TOKEN_REFRESH: RiskLevel.LOW,
  API_KEY_REGISTER: RiskLevel.HIGH,
  API_KEY_ACCESS: RiskLevel.MEDIUM,
  API_KEY_ROTATE: RiskLevel.HIGH,
  API_KEY_DELETE: RiskLevel.HIGH,
  ORDER_PLACE: RiskLevel.MEDIUM,
  ORDER_CANCEL: RiskLevel.LOW,
  ORDER_FILLED: RiskLevel.LOW,
  ORDER_REJECTED: RiskLevel.MEDIUM,
  ORDER_INTEGRITY_FAIL: RiskLevel.CRITICAL,
  UNAUTHORIZED_ACCESS: RiskLevel.CRITICAL,
  CERT_PIN_MISMATCH: RiskLevel.CRITICAL,
  ANOMALY_DETECTED: RiskLevel.HIGH,
  RATE_LIMIT_HIT: RiskLevel.HIGH,
  CIRCUIT_BREAKER: RiskLevel.HIGH,
  SYSTEM_START: RiskLevel.LOW,
  SYSTEM_HALT: RiskLevel.HIGH,
  KEY_ROTATION: RiskLevel.MEDIUM,
  CONFIG_CHANGE: RiskLevel.MEDIUM,
};

/**
 * 감사 로그 기록
 */
function log({
  eventType,
  actorId = null,
  ip = null,
  device = null,
  resource = null,
  action = null,
  result = 'SUCCESS',
  detail = {},
  riskLevel = null,
}) {
  try {
    const db = getDb();
    const masked = maskSensitive(detail);
    const level = riskLevel || DEFAULT_RISK[eventType] || RiskLevel.LOW;

    db.prepare(`
      INSERT INTO audit_logs
        (id, event_type, actor_id, ip, device, resource, action, result, detail_json, risk_level)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      uuidv4(),
      eventType,
      actorId,
      ip,
      device,
      resource,
      action,
      result,
      JSON.stringify(masked),
      level
    );

    // CRITICAL 이벤트는 콘솔에도 출력
    if (level === RiskLevel.CRITICAL || level === RiskLevel.HIGH) {
      console.warn(`[AUDIT][${level}] ${eventType} | actor=${actorId} ip=${ip} result=${result}`);
    }
  } catch (err) {
    console.error('[AUDIT] Failed to write log:', err.message);
  }
}

/**
 * 최근 감사 로그 조회
 */
function getRecentLogs(limit = 100, riskLevel = null) {
  const db = getDb();
  if (riskLevel) {
    return db.prepare(
      'SELECT * FROM audit_logs WHERE risk_level = ? ORDER BY timestamp DESC LIMIT ?'
    ).all(riskLevel, limit);
  }
  return db.prepare(
    'SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT ?'
  ).all(limit);
}

module.exports = { log, getRecentLogs, AuditEvent, RiskLevel };
