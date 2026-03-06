/**
 * AutoTradeX Broker Account Routes
 * 한국투자증권(KIS) 전용
 *
 * POST   /api/broker/connect    - KIS 계좌 연동
 * GET    /api/broker/accounts   - 연동 계좌 목록
 * DELETE /api/broker/:id        - 계좌 연동 해제
 * GET    /api/broker/supported  - 지원 브로커 목록 (추후 확장용)
 */

const { Hono }          = require('hono');
const { z }             = require('zod');
const { authMiddleware } = require('../middleware/auth.middleware');
const brokerService      = require('../services/broker.service');
const { getImplementedBrokers } = require('../brokers');

const router = new Hono();

// ── 입력 유효성 검사 스키마 ────────────────────────────────────
// broker 필드는 현재 'kis'만 허용 (추후 enum 확장)
const connectSchema = z.object({
  broker:    z.literal('kis', { errorMap: () => ({ message: '현재 한국투자증권(kis)만 지원합니다' }) }),
  appKey:    z.string().min(1, 'App Key를 입력하세요').max(36),
  appSecret: z.string().min(1, 'App Secret을 입력하세요').max(180),
  // 계좌번호: 8자리(CANO) 또는 10자리(CANO+ACNT_PRDT_CD), 하이픈 허용
  accountNo: z.string()
    .min(8, '계좌번호는 최소 8자리입니다')
    .max(20)
    .transform(v => v.replace(/-/g, '')), // 하이픈 제거 후 저장
  isMock: z.boolean().default(false), // 실전 키를 받았으므로 기본값 false
});

function getIp(c) {
  return c.req.header('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
}

// ── GET /api/broker/supported ─────────────────────────────────
// 클라이언트가 어떤 증권사가 지원되는지 동적으로 확인할 수 있도록
router.get('/supported', (c) => {
  return c.json({ brokers: getImplementedBrokers() });
});

// ── POST /api/broker/connect ──────────────────────────────────
router.post('/connect', authMiddleware, async (c) => {
  try {
    const body   = await c.req.json();
    const parsed = connectSchema.safeParse(body);
    if (!parsed.success) {
      return c.json({
        error:   '입력값 오류',
        details: parsed.error.errors.map(e => ({ field: e.path.join('.'), message: e.message })),
      }, 400);
    }

    const userId    = c.get('user').sub;
    const accountId = await brokerService.connectBrokerAccount({
      userId, ip: getIp(c),
      ...parsed.data,
    });

    return c.json({
      message:   '한국투자증권 계좌가 연동되었습니다',
      accountId,
      broker:    'kis',
      isMock:    parsed.data.isMock,
    }, 201);
  } catch (err) {
    return c.json({ error: err.message }, err.status || 500);
  }
});

// ── GET /api/broker/accounts ──────────────────────────────────
router.get('/accounts', authMiddleware, (c) => {
  const userId   = c.get('user').sub;
  const accounts = brokerService.getBrokerAccounts(userId);
  return c.json({ accounts });
});

// ── DELETE /api/broker/:id ────────────────────────────────────
router.delete('/:id', authMiddleware, (c) => {
  const userId    = c.get('user').sub;
  const accountId = c.req.param('id');
  try {
    brokerService.deactivateBrokerAccount(accountId, userId);
    return c.json({ message: '계좌 연동이 해제되었습니다' });
  } catch (err) {
    return c.json({ error: err.message }, err.status || 500);
  }
});

module.exports = router;
