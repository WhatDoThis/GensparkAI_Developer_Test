/**
 * AutoTradeX Backend Server
 * Hono + @hono/node-server
 */

require('dotenv').config();

const { serve } = require('@hono/node-server');
const { Hono } = require('hono');
const { cors } = require('hono/cors');

// DB 초기화 (앱 시작 시)
const { getDb } = require('./db/connection');

// 미들웨어
const { rateLimitMiddleware } = require('./middleware/ratelimit.middleware');

// 라우트
const authRoutes = require('./routes/auth.routes');
const credentialRoutes = require('./routes/credentials.routes');
const brokerRoutes = require('./routes/broker.routes');
const tradingSettingsRoutes = require('./routes/trading-settings.routes');

// 감사 로그
const audit = require('./services/audit.service');

// ── 앱 초기화 ────────────────────────────────────────────
const app = new Hono();

// CORS 설정
const corsOrigin = process.env.CORS_ORIGIN || 'http://localhost:5060';
app.use('*', cors({
  origin: (origin) => {
    // 허용된 오리진 목록
    const allowed = [
      'http://localhost:5060',
      'http://localhost:3000',
      corsOrigin,
    ].filter(Boolean);
    if (!origin || allowed.includes(origin) || origin.endsWith('.sandbox.novita.ai')) {
      return origin || '*';
    }
    return null;
  },
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
  maxAge: 86400,
}));

// 보안 헤더 (PRD 10-A-4)
app.use('*', async (c, next) => {
  await next();
  c.header('X-Content-Type-Options', 'nosniff');
  c.header('X-Frame-Options', 'DENY');
  c.header('X-XSS-Protection', '1; mode=block');
  c.header('Referrer-Policy', 'strict-origin-when-cross-origin');
  c.header('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  // HSTS (HTTPS 환경에서만 활성화)
  if (process.env.NODE_ENV === 'production') {
    c.header('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  }
});

// Rate Limiting
app.use('*', rateLimitMiddleware);

// ── 헬스 체크 ─────────────────────────────────────────────
app.get('/health', (c) => {
  const db = getDb();
  let dbStatus = 'ok';
  try {
    db.prepare('SELECT 1').get();
  } catch {
    dbStatus = 'error';
  }

  return c.json({
    status: 'ok',
    service: 'AutoTradeX Backend',
    version: '1.0.0',
    db: dbStatus,
    mode: process.env.TRADING_MODE || 'paper',
    timestamp: new Date().toISOString(),
  });
});

// ── 라우트 등록 ────────────────────────────────────────────
app.route('/auth', authRoutes);
app.route('/api/credentials', credentialRoutes);
app.route('/api/broker', brokerRoutes);
app.route('/api/trading', tradingSettingsRoutes);

// ── 추후 추가할 라우트 (placeholder) ─────────────────────
app.get('/api/account', (c) => {
  return c.json({ message: '계좌 API - 브로커 연동 후 구현 예정' });
});

app.get('/api/market/stocks', (c) => {
  return c.json({
    message: '시세 API - 브로커 연동 후 구현 예정',
    mockData: [
      { code: '005930', name: '삼성전자', price: 75000, change: 1.2 },
      { code: '000660', name: 'SK하이닉스', price: 195000, change: -0.5 },
      { code: '035420', name: 'NAVER', price: 228000, change: 0.8 },
    ]
  });
});

app.get('/api/trades', (c) => {
  return c.json({ message: '거래 내역 API - 구현 예정', trades: [] });
});

// ── 에러 핸들러 ────────────────────────────────────────────
app.onError((err, c) => {
  console.error('[ERROR]', err);
  return c.json({
    error: process.env.NODE_ENV === 'production'
      ? '서버 오류가 발생했습니다'
      : err.message
  }, 500);
});

app.notFound((c) => {
  return c.json({ error: `경로를 찾을 수 없습니다: ${c.req.path}` }, 404);
});

// ── 서버 시작 ─────────────────────────────────────────────
const PORT = parseInt(process.env.PORT || '3000');

// DB 초기화
try {
  getDb();
  console.log('[INIT] Database initialized');
} catch (err) {
  console.error('[INIT] Database initialization failed:', err.message);
  process.exit(1);
}

// 필수 환경변수 확인
const requiredEnvs = ['JWT_SECRET', 'SYSTEM_ENCRYPTION_SECRET'];
const missing = requiredEnvs.filter(k => !process.env[k]);
if (missing.length > 0) {
  console.error('[INIT] Missing required env vars:', missing.join(', '));
  process.exit(1);
}

serve({
  fetch: app.fetch,
  port: PORT,
}, (info) => {
  audit.log({
    eventType: audit.AuditEvent.SYSTEM_START,
    resource: 'server',
    action: 'start',
    detail: { port: info.port, mode: process.env.TRADING_MODE, node: process.version }
  });
  console.log(`
╔════════════════════════════════════════╗
║     AutoTradeX Backend v1.0.0          ║
║     Port: ${info.port}                         ║
║     Mode: ${(process.env.TRADING_MODE || 'paper').padEnd(10)}              ║
║     DB: ${'Supabase PostgreSQL'.padEnd(30)}  ║
╚════════════════════════════════════════╝
  `);
  console.log(`[SERVER] http://localhost:${info.port}/health`);
});

module.exports = app;
