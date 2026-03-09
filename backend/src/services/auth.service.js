/**
 * AutoTradeX Auth Service — Supabase Edition
 * PRD 10-A-2: JWT HS256, 세션 관리
 */

const jwt    = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const { getDb }  = require('../db/connection');
const { hashPassword, verifyPassword } = require('./crypto.service');
const audit  = require('./audit.service');

const JWT_SECRET    = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_MINUTES     = 30;

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

// ── 공통 에러 핸들러 ──────────────────────────────────────
function sbError(error, msg, status = 500) {
  if (error) {
    const err = new Error(msg || error.message);
    err.status = status;
    throw err;
  }
}

// ── 회원가입 ───────────────────────────────────────────────
async function signup({ email, password, name }, { ip, userAgent } = {}) {
  const db = getDb();

  // 중복 이메일
  const { data: existing } = await db
    .from('users').select('id').eq('email', email).maybeSingle();
  if (existing) sbError({ message: '이미 사용 중인 이메일입니다' }, '이미 사용 중인 이메일입니다', 409);

  const passwordHash = await hashPassword(password);
  const userId = uuidv4();
  const now = new Date().toISOString();

  const { error } = await db.from('users').insert({
    id: userId,
    email,
    password_hash: passwordHash,
    name,
    role: 'OWNER',
    mfa_enabled: false,
    failed_login_attempts: 0,
    created_at: now,
    updated_at: now,
  });
  sbError(error, '회원가입 실패');

  audit.log({
    eventType: audit.AuditEvent.SIGNUP,
    actorId: userId, ip, device: userAgent,
    resource: 'users', action: 'signup',
    detail: { email, name },
  });

  return { userId, email, name };
}

// ── 로그인 ────────────────────────────────────────────────
async function login({ email, password }, { ip, userAgent } = {}) {
  const db = getDb();

  const { data: user } = await db
    .from('users').select('*').eq('email', email).maybeSingle();

  // 사용자 없음 (타이밍 공격 방지)
  if (!user) {
    await hashPassword('dummy_timing_protection');
    audit.log({
      eventType: audit.AuditEvent.LOGIN_FAILURE,
      ip, device: userAgent,
      resource: 'auth', action: 'login',
      result: 'FAILURE',
      detail: { email, reason: 'user_not_found' },
      riskLevel: audit.RiskLevel.MEDIUM,
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
        riskLevel: audit.RiskLevel.HIGH,
      });
      throw Object.assign(
        new Error(`계정이 잠겨 있습니다. ${remainMin}분 후 다시 시도하세요`),
        { status: 403 }
      );
    } else {
      await db.from('users')
        .update({ locked_until: null, failed_login_attempts: 0 })
        .eq('id', user.id);
    }
  }

  // 비밀번호 검증
  const isValid = await verifyPassword(password, user.password_hash);
  if (!isValid) {
    const newAttempts = (user.failed_login_attempts || 0) + 1;
    let lockedUntil = null;
    if (newAttempts >= MAX_FAILED_ATTEMPTS) {
      lockedUntil = new Date(Date.now() + LOCKOUT_MINUTES * 60 * 1000).toISOString();
    }

    await db.from('users')
      .update({ failed_login_attempts: newAttempts, locked_until: lockedUntil })
      .eq('id', user.id);

    const isLocked = !!lockedUntil;
    audit.log({
      eventType: isLocked ? audit.AuditEvent.LOGIN_LOCKED : audit.AuditEvent.LOGIN_FAILURE,
      actorId: user.id, ip, device: userAgent,
      resource: 'auth', action: 'login',
      result: 'FAILURE',
      detail: { email, attempts: newAttempts, locked: isLocked },
      riskLevel: isLocked ? audit.RiskLevel.HIGH : audit.RiskLevel.MEDIUM,
    });

    if (isLocked) {
      throw Object.assign(
        new Error(`비밀번호 ${MAX_FAILED_ATTEMPTS}회 실패. 계정이 ${LOCKOUT_MINUTES}분 잠겼습니다`),
        { status: 403 }
      );
    }
    throw Object.assign(new Error('이메일 또는 비밀번호가 올바르지 않습니다'), { status: 401 });
  }

  // JWT 발급
  const sessionId = uuidv4();
  const token = jwt.sign(
    { sub: user.id, email: user.email, name: user.name, role: user.role, jti: sessionId },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );

  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const now = new Date().toISOString();

  await db.from('sessions').insert({
    id: sessionId,
    user_id: user.id,
    token_hash: hashToken(token),
    ip_address: ip,
    user_agent: userAgent,
    expires_at: expiresAt,
    revoked: false,
    created_at: now,
  });

  await db.from('users')
    .update({
      failed_login_attempts: 0,
      locked_until: null,
      last_login_at: now,
      last_login_ip: ip,
    })
    .eq('id', user.id);

  audit.log({
    eventType: audit.AuditEvent.LOGIN_SUCCESS,
    actorId: user.id, ip, device: userAgent,
    resource: 'auth', action: 'login',
    result: 'SUCCESS',
    detail: { email },
  });

  return {
    token,
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      mfaEnabled: !!user.mfa_enabled,
    },
  };
}

// ── 로그아웃 ──────────────────────────────────────────────
async function logout(token, userId, { ip, userAgent } = {}) {
  const db = getDb();
  const tokenHash = hashToken(token);

  await db.from('sessions').update({ revoked: true }).eq('token_hash', tokenHash);

  audit.log({
    eventType: audit.AuditEvent.LOGOUT,
    actorId: userId, ip, device: userAgent,
    resource: 'auth', action: 'logout',
    result: 'SUCCESS',
  });
}

// ── 토큰 검증 ─────────────────────────────────────────────
async function verifyToken(token) {
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const db = getDb();
    const tokenHash = hashToken(token);
    const now = new Date().toISOString();

    const { data: session } = await db
      .from('sessions')
      .select('id')
      .eq('token_hash', tokenHash)
      .eq('revoked', false)
      .gt('expires_at', now)
      .maybeSingle();

    if (!session) throw new Error('Session not found or revoked');
    return decoded;
  } catch {
    throw Object.assign(new Error('유효하지 않은 토큰입니다'), { status: 401 });
  }
}

// ── 현재 사용자 조회 ───────────────────────────────────────
async function getUserById(userId) {
  const db = getDb();
  const { data: user } = await db
    .from('users')
    .select('id, email, name, role, mfa_enabled, last_login_at, last_login_ip, created_at')
    .eq('id', userId)
    .maybeSingle();
  return user || null;
}

module.exports = { signup, login, logout, verifyToken, getUserById };
