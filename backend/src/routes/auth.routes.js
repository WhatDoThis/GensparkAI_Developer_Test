/**
 * AutoTradeX Auth Routes
 * POST /auth/signup  - 회원가입
 * POST /auth/login   - 로그인
 * POST /auth/logout  - 로그아웃
 * GET  /auth/me      - 내 정보
 */

const { Hono } = require('hono');
const { z } = require('zod');
const authService = require('../services/auth.service');
const { authMiddleware } = require('../middleware/auth.middleware');

const router = new Hono();

// ── Zod 스키마 (입력 검증) ──────────────────────────────────
const signupSchema = z.object({
  email: z.string().email('올바른 이메일 형식이 아닙니다').max(255),
  password: z.string()
    .min(8, '비밀번호는 최소 8자 이상이어야 합니다')
    .max(128)
    .regex(/[A-Z]/, '대문자를 포함해야 합니다')
    .regex(/[a-z]/, '소문자를 포함해야 합니다')
    .regex(/[0-9]/, '숫자를 포함해야 합니다')
    .regex(/[!@#$%^&*]/, '특수문자(!@#$%^&*)를 포함해야 합니다'),
  name: z.string().min(1, '이름을 입력하세요').max(50).trim(),
});

const loginSchema = z.object({
  email: z.string().email().max(255),
  password: z.string().min(1).max(128),
});

function getClientInfo(c) {
  return {
    ip: c.req.header('x-forwarded-for')?.split(',')[0]?.trim()
      || c.req.header('x-real-ip')
      || 'unknown',
    userAgent: c.req.header('user-agent') || 'unknown',
  };
}

// ── POST /auth/signup ─────────────────────────────────────
router.post('/signup', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = signupSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({
        error: '입력값이 올바르지 않습니다',
        details: parsed.error.errors.map(e => ({
          field: e.path.join('.'),
          message: e.message
        }))
      }, 400);
    }

    const result = await authService.signup(parsed.data, getClientInfo(c));
    return c.json({
      message: '회원가입이 완료되었습니다',
      userId: result.userId,
      email: result.email,
      name: result.name,
    }, 201);
  } catch (err) {
    return c.json({ error: err.message }, err.status || 500);
  }
});

// ── POST /auth/login ──────────────────────────────────────
router.post('/login', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = loginSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: '이메일 또는 비밀번호를 입력하세요' }, 400);
    }

    const result = await authService.login(parsed.data, getClientInfo(c));
    return c.json({
      message: '로그인 성공',
      token: result.token,
      user: result.user,
    });
  } catch (err) {
    return c.json({ error: err.message }, err.status || 500);
  }
});

// ── POST /auth/logout ─────────────────────────────────────
router.post('/logout', authMiddleware, (c) => {
  const token = c.get('token');
  const user = c.get('user');
  authService.logout(token, user.sub, getClientInfo(c));
  return c.json({ message: '로그아웃 되었습니다' });
});

// ── GET /auth/me ──────────────────────────────────────────
router.get('/me', authMiddleware, (c) => {
  const { sub: userId } = c.get('user');
  const user = authService.getUserById(userId);
  if (!user) return c.json({ error: '사용자를 찾을 수 없습니다' }, 404);

  return c.json({ user });
});

module.exports = router;
