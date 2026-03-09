/**
 * AutoTradeX Auth Middleware — Supabase Edition
 * JWT 검증 + 역할 기반 접근 제어 (RBAC)
 */

const { verifyToken } = require('../services/auth.service');
const audit = require('../services/audit.service');

/**
 * JWT 인증 미들웨어 (Hono) — async
 */
async function authMiddleware(c, next) {
  try {
    const authHeader = c.req.header('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return c.json({ error: '인증이 필요합니다' }, 401);
    }

    const token   = authHeader.slice(7);
    const decoded = await verifyToken(token);   // ← async

    c.set('user', decoded);
    c.set('token', token);

    return next();
  } catch (err) {
    const ip = c.req.header('x-forwarded-for') || c.req.header('x-real-ip') || 'unknown';
    audit.log({
      eventType: audit.AuditEvent.UNAUTHORIZED_ACCESS,
      ip,
      resource: c.req.path,
      action:   c.req.method,
      result:   'FAILURE',
      riskLevel: audit.RiskLevel.HIGH,
      detail: { error: err.message },
    });
    return c.json({ error: err.message || '인증 실패' }, 401);
  }
}

/**
 * 역할 검증 미들웨어
 */
function requireRole(...roles) {
  return (c, next) => {
    const user = c.get('user');
    if (!user || !roles.includes(user.role)) {
      return c.json({ error: '권한이 없습니다' }, 403);
    }
    return next();
  };
}

module.exports = { authMiddleware, requireRole };
