/**
 * AutoTradeX Audit Logger — Supabase Edition
 * PRD 10-A-7: 감사 로그 (audit_logs 테이블)
 */

const { v4: uuidv4 } = require('uuid');
const { getDb }      = require('../db/connection');
const { maskSensitive } = require('./crypto.service');

const AuditEvent = {
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
  API_KEY_REGISTER: 'API_KEY_REGISTER',
  API_KEY_ACCESS: 'API_KEY_ACCESS',
  API_KEY_ROTATE: 'API_KEY_ROTATE',
  API_KEY_DELETE: 'API_KEY_DELETE',
  ORDER_PLACE: 'ORDER_PLACE',
  ORDER_CANCEL: 'ORDER_CANCEL',
  ORDER_FILLED: 'ORDER_FILLED',
  ORDER_REJECTED: 'ORDER_REJECTED',
  ORDER_INTEGRITY_FAIL: 'ORDER_INTEGRITY_FAIL',
  UNAUTHORIZED_ACCESS: 'UNAUTHORIZED_ACCESS',
  CERT_PIN_MISMATCH: 'CERT_PIN_MISMATCH',
  ANOMALY_DETECTED: 'ANOMALY_DETECTED',
  RATE_LIMIT_HIT: 'RATE_LIMIT_HIT',
  CIRCUIT_BREAKER: 'CIRCUIT_BREAKER',
  SYSTEM_START: 'SYSTEM_START',
  SYSTEM_HALT: 'SYSTEM_HALT',
  KEY_ROTATION: 'KEY_ROTATION',
  CONFIG_CHANGE: 'CONFIG_CHANGE',
};

const RiskLevel = {
  LOW: 'LOW', MEDIUM: 'MEDIUM', HIGH: 'HIGH', CRITICAL: 'CRITICAL',
};

const DEFAULT_RISK = {
  LOGIN_SUCCESS: 'LOW', LOGIN_FAILURE: 'MEDIUM', LOGIN_LOCKED: 'HIGH',
  LOGOUT: 'LOW', SIGNUP: 'LOW', PASSWORD_CHANGE: 'MEDIUM',
  MFA_ENABLE: 'MEDIUM', MFA_VERIFY: 'LOW', SESSION_REVOKE: 'MEDIUM',
  TOKEN_REFRESH: 'LOW', API_KEY_REGISTER: 'HIGH', API_KEY_ACCESS: 'MEDIUM',
  API_KEY_ROTATE: 'HIGH', API_KEY_DELETE: 'HIGH',
  ORDER_PLACE: 'MEDIUM', ORDER_CANCEL: 'LOW', ORDER_FILLED: 'LOW',
  ORDER_REJECTED: 'MEDIUM', ORDER_INTEGRITY_FAIL: 'CRITICAL',
  UNAUTHORIZED_ACCESS: 'CRITICAL', CERT_PIN_MISMATCH: 'CRITICAL',
  ANOMALY_DETECTED: 'HIGH', RATE_LIMIT_HIT: 'HIGH',
  CIRCUIT_BREAKER: 'HIGH', SYSTEM_START: 'LOW', SYSTEM_HALT: 'HIGH',
  KEY_ROTATION: 'MEDIUM', CONFIG_CHANGE: 'MEDIUM',
};

/**
 * 감사 로그 기록 (비동기, 실패해도 앱 흐름 차단 안 함)
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
  const level = riskLevel || DEFAULT_RISK[eventType] || 'LOW';

  if (level === 'CRITICAL' || level === 'HIGH') {
    console.warn(`[AUDIT][${level}] ${eventType} | actor=${actorId} ip=${ip} result=${result}`);
  }

  // 비동기로 삽입 (await 안 함 — 로그 실패가 주요 흐름을 막으면 안 됨)
  setImmediate(async () => {
    try {
      const db = getDb();
      const masked = maskSensitive(detail);
      await db.from('audit_logs').insert({
        id:          uuidv4(),
        event_type:  eventType,
        actor_id:    actorId,
        ip,
        device,
        resource,
        action,
        result,
        detail_json: JSON.stringify(masked),
        risk_level:  level,
        timestamp:   new Date().toISOString(),
      });
    } catch (err) {
      console.error('[AUDIT] Failed to write log:', err.message);
    }
  });
}

/**
 * 최근 감사 로그 조회
 */
async function getRecentLogs(limit = 100, riskLevel = null) {
  const db = getDb();
  let query = db.from('audit_logs').select('*').order('timestamp', { ascending: false }).limit(limit);
  if (riskLevel) query = query.eq('risk_level', riskLevel);

  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return data || [];
}

module.exports = { log, getRecentLogs, AuditEvent, RiskLevel };
