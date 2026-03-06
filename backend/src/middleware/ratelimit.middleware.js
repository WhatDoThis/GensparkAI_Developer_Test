/**
 * AutoTradeX Rate Limiting Middleware
 * PRD 10-A-9: Rate Limiting (메모리 기반, 프로덕션에서는 Redis 사용)
 */

const audit = require('../services/audit.service');

// in-memory store: { key: { count, resetAt } }
const store = new Map();

// 정책 정의 (PRD 명세)
const POLICIES = {
  '/auth/login': { limit: 5, windowMs: 60 * 1000 },        // 5회/분
  '/auth/signup': { limit: 3, windowMs: 60 * 1000 },       // 3회/분
  '/api/orders': { limit: 30, windowMs: 60 * 1000 },       // 30회/분
  '/api/market': { limit: 60, windowMs: 60 * 1000 },       // 60회/분
  'default': { limit: 100, windowMs: 60 * 1000 },          // 기본 100회/분
};

// IP 블랙리스트 (임시 차단)
const blacklist = new Set();

function getPolicy(path) {
  for (const [pattern, policy] of Object.entries(POLICIES)) {
    if (pattern !== 'default' && path.includes(pattern)) return policy;
  }
  return POLICIES.default;
}

function rateLimitMiddleware(c, next) {
  const ip = c.req.header('x-forwarded-for')?.split(',')[0]?.trim()
    || c.req.header('x-real-ip')
    || 'unknown';

  // 블랙리스트 확인
  if (blacklist.has(ip)) {
    audit.log({
      eventType: audit.AuditEvent.RATE_LIMIT_HIT,
      ip,
      resource: c.req.path,
      action: 'blocked_blacklist',
      result: 'BLOCKED',
      riskLevel: audit.RiskLevel.HIGH
    });
    return c.json({ error: '접근이 차단되었습니다' }, 429);
  }

  const policy = getPolicy(c.req.path);
  const key = `${ip}:${c.req.path}`;
  const now = Date.now();

  let entry = store.get(key);
  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + policy.windowMs };
    store.set(key, entry);
  }

  entry.count++;

  // Rate limit 초과
  if (entry.count > policy.limit) {
    // 10배 초과 시 블랙리스트 추가 (5분)
    if (entry.count > policy.limit * 10) {
      blacklist.add(ip);
      setTimeout(() => blacklist.delete(ip), 5 * 60 * 1000);
    }

    audit.log({
      eventType: audit.AuditEvent.RATE_LIMIT_HIT,
      ip,
      resource: c.req.path,
      action: 'rate_limit_exceeded',
      result: 'BLOCKED',
      riskLevel: audit.RiskLevel.HIGH,
      detail: { count: entry.count, limit: policy.limit }
    });

    c.header('Retry-After', Math.ceil(policy.windowMs / 1000).toString());
    c.header('X-RateLimit-Limit', policy.limit.toString());
    c.header('X-RateLimit-Remaining', '0');
    return c.json({
      error: '요청 한도를 초과했습니다. 잠시 후 다시 시도하세요',
      retryAfter: Math.ceil((entry.resetAt - now) / 1000)
    }, 429);
  }

  // 헤더 추가
  c.header('X-RateLimit-Limit', policy.limit.toString());
  c.header('X-RateLimit-Remaining', Math.max(0, policy.limit - entry.count).toString());

  return next();
}

// 메모리 정리 (5분마다)
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of store.entries()) {
    if (now > entry.resetAt) store.delete(key);
  }
}, 5 * 60 * 1000);

module.exports = { rateLimitMiddleware };
