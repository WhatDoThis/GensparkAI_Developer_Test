/**
 * AutoTradeX Auth Service
 * PRD 10-A-2: JWT RS256 → 현재 HS256 (RS256은 키파일 필요, 추후 전환)
 * 회원가입, 로그인, 세션 관리
 */

const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const { getDb } = require('../db/connection');
const { hashPassword, verifyPassword } = require('./crypto.service');
const audit = require('./audit.service');

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_MINUTES = 30;

// JWT jti 해시 (세션 테이블 저장용)
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

// ── 회원가입 ───────────────────────────────────────────────
async function signup({ email, password, name }, { ip, userAgent } = {}) {
  const db = getDb();

  // 중복 이메일 확인
  const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
  if (existing) {
    throw Object.assign(new Error('이미 사용 중인 이메일입니다'), { status: 409 });
  }

  const passwordHash = await hashPassword(password);
  const userId = uuidv4();

  db.prepare(`
    INSERT INTO users (id, email, password_hash, name)
    VALUES (?, ?, ?, ?)
  `).run(userId, email, passwordHash, name);

  audit.log({
    eventType: audit.AuditEvent.SIGNUP,
    actorId: userId,
    ip,
    device: userAgent,
    resource: 'users',
    action: 'signup',
    detail: { email, name }
  });

  return { userId, email, name };
}

// ── 로그인 ────────────────────────────────────────────────
async function login({ email, password }, { ip, userAgent } = {}) {
  const db = getDb();
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);

  // 사용자 없음 (타이밍 공격 방지: 해시 연산 수행)
  if (!user) {
    await hashPassword('dummy_timing_protection');
    audit.log({
      eventType: audit.AuditEvent.LOGIN_FAILURE,
      ip, device: userAgent,
      resource: 'auth', action: 'login',
      result: 'FAILURE',
      detail: { email, reason: 'user_not_found' },
      riskLevel: audit.RiskLevel.MEDIUM
    });
    throw Object.assign(new Error('이메일 또는 비밀번호가 올바르지 않습니다'), { status: 401 });
  }

  // 계정 잠금 확인
  if (user.locked_until) {
    const lockedUntil = new Date(user.locked_until);
    if (lockedUntil > new Date()) {
      const remainMin = Math.ceil((lockedUntil - new Date()) / 60000);
      audit.log({
        eventType: audit.AuditEvent.LOGIN_LOCKED,
        actorId: user.id, ip, device: userAgent,
        resource: 'auth', action: 'login',
        result: 'BLOCKED',
        detail: { email, locked_until: user.locked_until },
        riskLevel: audit.RiskLevel.HIGH
      });
      throw Object.assign(
        new Error(`계정이 잠겨 있습니다. ${remainMin}분 후 다시 시도하세요`),
        { status: 403 }
      );
    } else {
      // 잠금 해제
      db.prepare('UPDATE users SET locked_until = NULL, failed_login_attempts = 0 WHERE id = ?').run(user.id);
    }
  }

  // 비밀번호 검증
  const isValid = await verifyPassword(password, user.password_hash);
  if (!isValid) {
    const newAttempts = user.failed_login_attempts + 1;
    let lockedUntil = null;

    if (newAttempts >= MAX_FAILED_ATTEMPTS) {
      lockedUntil = new Date(Date.now() + LOCKOUT_MINUTES * 60 * 1000).toISOString();
    }

    db.prepare(`
      UPDATE users 
      SET failed_login_attempts = ?, locked_until = ?
      WHERE id = ?
    `).run(newAttempts, lockedUntil, user.id);

    const isLocked = !!lockedUntil;
    audit.log({
      eventType: isLocked ? audit.AuditEvent.LOGIN_LOCKED : audit.AuditEvent.LOGIN_FAILURE,
      actorId: user.id, ip, device: userAgent,
      resource: 'auth', action: 'login',
      result: 'FAILURE',
      detail: { email, attempts: newAttempts, locked: isLocked },
      riskLevel: isLocked ? audit.RiskLevel.HIGH : audit.RiskLevel.MEDIUM
    });

    if (isLocked) {
      throw Object.assign(
        new Error(`비밀번호 ${MAX_FAILED_ATTEMPTS}회 실패. 계정이 ${LOCKOUT_MINUTES}분 잠겼습니다`),
        { status: 403 }
      );
    }
    throw Object.assign(new Error('이메일 또는 비밀번호가 올바르지 않습니다'), { status: 401 });
  }

  // 로그인 성공 → JWT 발급
  const sessionId = uuidv4();
  const token = jwt.sign(
    {
      sub: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      jti: sessionId,
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );

  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  db.prepare(`
    INSERT INTO sessions (id, user_id, token_hash, ip_address, user_agent, expires_at)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(sessionId, user.id, hashToken(token), ip, userAgent, expiresAt);

  // 로그인 정보 업데이트
  db.prepare(`
    UPDATE users 
    SET failed_login_attempts = 0, locked_until = NULL,
        last_login_at = datetime('now'), last_login_ip = ?
    WHERE id = ?
  `).run(ip, user.id);

  audit.log({
    eventType: audit.AuditEvent.LOGIN_SUCCESS,
    actorId: user.id, ip, device: userAgent,
    resource: 'auth', action: 'login',
    result: 'SUCCESS',
    detail: { email }
  });

  return {
    token,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      mfaEnabled: !!user.mfa_enabled,
    }
  };
}

// ── 로그아웃 ──────────────────────────────────────────────
function logout(token, userId, { ip, userAgent } = {}) {
  const db = getDb();
  const tokenHash = hashToken(token);

  db.prepare(`
    UPDATE sessions SET revoked = 1 WHERE token_hash = ?
  `).run(tokenHash);

  audit.log({
    eventType: audit.AuditEvent.LOGOUT,
    actorId: userId, ip, device: userAgent,
    resource: 'auth', action: 'logout',
    result: 'SUCCESS'
  });
}

// ── 토큰 검증 ─────────────────────────────────────────────
function verifyToken(token) {
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const db = getDb();
    const tokenHash = hashToken(token);

    const session = db.prepare(`
      SELECT * FROM sessions 
      WHERE token_hash = ? AND revoked = 0 AND expires_at > datetime('now')
    `).get(tokenHash);

    if (!session) {
      throw new Error('Session not found or revoked');
    }

    return decoded;
  } catch (err) {
    throw Object.assign(new Error('유효하지 않은 토큰입니다'), { status: 401 });
  }
}

// ── 현재 사용자 조회 ───────────────────────────────────────
function getUserById(userId) {
  const db = getDb();
  const user = db.prepare(`
    SELECT id, email, name, role, mfa_enabled, last_login_at, last_login_ip, created_at
    FROM users WHERE id = ?
  `).get(userId);
  return user || null;
}

module.exports = { signup, login, logout, verifyToken, getUserById };
