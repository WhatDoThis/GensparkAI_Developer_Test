/**
 * AutoTradeX Trading Settings Routes
 * GET    /api/trading/settings          - 설정 조회
 * PUT    /api/trading/settings          - 설정 저장/수정
 * POST   /api/trading/start             - 거래 시작
 * POST   /api/trading/stop              - 거래 중지
 * POST   /api/trading/reset             - 설정 초기화
 * GET    /api/trading/status            - 현재 거래 상태 및 오늘 통계
 */

const { Hono } = require('hono');
const { z } = require('zod');
const { authMiddleware } = require('../middleware/auth.middleware');
const settingsService = require('../services/trading-settings.service');
const engine = require('../services/trading-engine.service');

const router = new Hono();

function getIp(c) {
  return c.req.header('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
}

const settingsSchema = z.object({
  broker_account_id: z.string().uuid().optional(),
  daily_budget: z.number().positive().optional(),
  loss_floor: z.number().min(0).optional(),
  trading_start_time: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  trading_end_time: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  term_seconds: z.number().int().min(1).optional(),
  max_trades: z.number().int().min(0).optional(),
  max_consecutive_losses: z.number().int().min(1).optional(),
  ai_sources: z.array(z.enum(['broker_api', 'krx', 'naver_finance', 'web_search'])).optional(),
  min_confidence_score: z.number().int().min(0).max(100).optional(),
  target_profit_rate: z.number().min(0.001).max(0.5).optional(),
  stop_loss_rate: z.number().min(0.001).max(0.3).optional(),
}).strict();

// ── GET /api/trading/settings ─────────────────────────────
router.get('/settings', authMiddleware, (c) => {
  const userId = c.get('user').sub;
  const settings = settingsService.getOrCreateSettings(userId);
  return c.json({ settings });
});

// ── PUT /api/trading/settings ─────────────────────────────
router.put('/settings', authMiddleware, async (c) => {
  try {
    const body = await c.req.json();
    const parsed = settingsSchema.safeParse(body);
    if (!parsed.success) {
      return c.json({
        error: '입력값 오류',
        details: parsed.error.errors.map(e => ({ field: e.path.join('.'), message: e.message }))
      }, 400);
    }

    const userId = c.get('user').sub;
    const updated = settingsService.saveSettings(userId, parsed.data, { ip: getIp(c) });
    return c.json({ message: '설정이 저장되었습니다', settings: updated });
  } catch (err) {
    return c.json({ error: err.message, errors: err.errors }, err.status || 500);
  }
});

// ── POST /api/trading/start ───────────────────────────────
router.post('/start', authMiddleware, (c) => {
  try {
    const userId = c.get('user').sub;
    const result = settingsService.startTrading(userId, { ip: getIp(c) });
    // 거래 엔진 시작
    const settings = settingsService.getOrCreateSettings(userId);
    engine.startEngine(userId, settings);
    return c.json({ message: '거래가 시작되었습니다', ...result });
  } catch (err) {
    return c.json({ error: err.message }, err.status || 500);
  }
});

// ── POST /api/trading/stop ────────────────────────────────
router.post('/stop', authMiddleware, async (c) => {
  try {
    const userId = c.get('user').sub;
    let reason = '수동 중지';
    try {
      const body = await c.req.json();
      if (body.reason) reason = body.reason;
    } catch (_) {}

    // 거래 엔진 중지
    engine.stopEngine(userId);
    const settings = settingsService.stopTrading(userId, reason, { ip: getIp(c) });
    return c.json({ message: '거래가 중지되었습니다', settings });
  } catch (err) {
    return c.json({ error: err.message }, err.status || 500);
  }
});

// ── POST /api/trading/reset ───────────────────────────────
router.post('/reset', authMiddleware, (c) => {
  try {
    const userId = c.get('user').sub;
    const settings = settingsService.resetSettings(userId, { ip: getIp(c) });
    return c.json({ message: '설정이 초기화되었습니다', settings });
  } catch (err) {
    return c.json({ error: err.message }, err.status || 500);
  }
});

// ── GET /api/trading/status ───────────────────────────────
router.get('/status', authMiddleware, (c) => {
  const userId = c.get('user').sub;
  const settings = settingsService.getOrCreateSettings(userId);
  const { getDb } = require('../db/connection');
  const db = getDb();

  // 오늘 세션 조회
  const today = new Date().toISOString().slice(0, 10);
  const session = db.prepare(
    'SELECT * FROM trading_sessions WHERE user_id = ? AND date = ? ORDER BY started_at DESC LIMIT 1'
  ).get(userId, today);

  // 잔고 계산
  const currentBalance = settings.daily_budget + (settings.today_pnl || 0);
  const budgetUsedRate = settings.daily_budget > 0
    ? (settings.today_used_budget || 0) / settings.daily_budget
    : 0;

  // 엔진 실시간 상태
  const engineStatus = engine.getEngineStatus(userId);

  return c.json({
    status: settings.status,
    engine: engineStatus,
    today: {
      date: today,
      pnl: settings.today_pnl || 0,
      tradeCount: settings.today_trade_count || 0,
      consecutiveLosses: settings.today_consecutive_losses || 0,
      currentBalance,
      lossFloor: settings.loss_floor,
      budgetUsedRate: Math.round(budgetUsedRate * 100) / 100,
      remainingBudget: Math.max(0, currentBalance - settings.loss_floor),
      isLossFloorReached: currentBalance <= settings.loss_floor,
      isMaxTradesReached: settings.max_trades > 0 &&
        (settings.today_trade_count || 0) >= settings.max_trades,
    },
    session: session ? {
      id: session.id,
      startedAt: session.started_at,
      endedAt: session.ended_at,
      haltReason: session.halt_reason,
    } : null,
    config: {
      dailyBudget: settings.daily_budget,
      lossFlo: settings.loss_floor,
      startTime: settings.trading_start_time,
      endTime: settings.trading_end_time,
      termSeconds: settings.term_seconds,
      maxTrades: settings.max_trades,
    },
  });
});

module.exports = router;
