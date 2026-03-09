/**
 * AutoTradeX Trading Settings Service — Supabase Edition
 * 거래 설정 CRUD + 상태 관리
 */

const { v4: uuidv4 } = require('uuid');
const { getDb }      = require('../db/connection');
const audit          = require('./audit.service');

const DEFAULTS = {
  daily_budget: 0,
  loss_floor: 0,
  trading_start_time: '09:10',
  trading_end_time: '14:50',
  term_seconds: 60,
  max_trades: 0,
  max_consecutive_losses: 3,
  ai_sources_json: JSON.stringify(['broker_api', 'krx']),
  min_confidence_score: 70,
  target_profit_rate: 0.02,
  stop_loss_rate: 0.01,
};

function isValidTime(t) {
  return /^([01]\d|2[0-3]):([0-5]\d)$/.test(t);
}

function isValidTradingTime(start, end) {
  const toMin = (t) => { const [h, m] = t.split(':').map(Number); return h * 60 + m; };
  const sMin = toMin(start), eMin = toMin(end);
  if (sMin < toMin('09:00') + 10) return '거래 시작은 09:10 이후로 설정하세요';
  if (eMin > toMin('14:50'))       return '거래 종료는 14:50 이전으로 설정하세요';
  if (sMin >= eMin)                return '거래 종료 시간은 시작 시간보다 늦어야 합니다';
  return null;
}

function formatSettings(row) {
  if (!row) return null;
  return {
    ...row,
    ai_sources: (() => {
      try { return JSON.parse(row.ai_sources_json); }
      catch { return ['broker_api', 'krx']; }
    })(),
  };
}

// ── 설정 조회 (없으면 기본값으로 생성) ─────────────────────
async function getOrCreateSettings(userId) {
  const db = getDb();
  const { data: settings } = await db
    .from('trading_settings').select('*').eq('user_id', userId).maybeSingle();

  if (settings) return formatSettings(settings);

  const id  = uuidv4();
  const now = new Date().toISOString();
  const { data: created, error } = await db.from('trading_settings').insert({
    id,
    user_id: userId,
    ...DEFAULTS,
    status: 'IDLE',
    today_used_budget: 0,
    today_trade_count: 0,
    today_consecutive_losses: 0,
    today_pnl: 0,
    created_at: now,
    updated_at: now,
  }).select().single();

  if (error) throw new Error(error.message);
  return formatSettings(created);
}

// ── 설정 저장/수정 ─────────────────────────────────────────
async function saveSettings(userId, updates, { ip } = {}) {
  const current = await getOrCreateSettings(userId);
  const db = getDb();

  if (current.status === 'RUNNING') {
    throw Object.assign(
      new Error('거래 중에는 설정을 변경할 수 없습니다. 먼저 거래를 중지하세요.'),
      { status: 409 }
    );
  }

  const errors = [];
  if (updates.daily_budget !== undefined && updates.daily_budget <= 0)
    errors.push('일일 예산은 0보다 커야 합니다');

  if (updates.loss_floor !== undefined) {
    const budget = updates.daily_budget ?? current.daily_budget;
    if (budget > 0 && updates.loss_floor >= budget)
      errors.push('손실 마지노선은 일일 예산보다 작아야 합니다');
    if (updates.loss_floor < 0)
      errors.push('손실 마지노선은 0 이상이어야 합니다');
  }

  const startTime = updates.trading_start_time || current.trading_start_time;
  const endTime   = updates.trading_end_time   || current.trading_end_time;
  if (updates.trading_start_time || updates.trading_end_time) {
    if (!isValidTime(startTime)) errors.push('거래 시작 시간 형식이 올바르지 않습니다 (HH:MM)');
    if (!isValidTime(endTime))   errors.push('거래 종료 시간 형식이 올바르지 않습니다 (HH:MM)');
    const timeErr = isValidTradingTime(startTime, endTime);
    if (timeErr) errors.push(timeErr);
  }

  if (updates.term_seconds !== undefined && updates.term_seconds < 1)
    errors.push('TERM은 최소 1초 이상이어야 합니다');
  if (updates.max_trades !== undefined && updates.max_trades < 0)
    errors.push('최대 거래 횟수는 0 이상이어야 합니다 (0=무제한)');

  if (errors.length > 0)
    throw Object.assign(new Error(errors.join('\n')), { status: 400, errors });

  if (updates.ai_sources && Array.isArray(updates.ai_sources)) {
    updates.ai_sources_json = JSON.stringify(updates.ai_sources);
    delete updates.ai_sources;
  }

  const allowed = [
    'broker_account_id', 'daily_budget', 'loss_floor',
    'trading_start_time', 'trading_end_time', 'term_seconds',
    'max_trades', 'max_consecutive_losses', 'ai_sources_json',
    'min_confidence_score', 'target_profit_rate', 'stop_loss_rate',
  ];

  const patch = {};
  for (const k of allowed) {
    if (updates[k] !== undefined) patch[k] = updates[k];
  }
  if (Object.keys(patch).length === 0) return getOrCreateSettings(userId);

  patch.status     = 'CONFIGURED';
  patch.updated_at = new Date().toISOString();

  const { error } = await db.from('trading_settings')
    .update(patch).eq('user_id', userId);
  if (error) throw new Error(error.message);

  audit.log({
    eventType: audit.AuditEvent.CONFIG_CHANGE,
    actorId: userId, ip,
    resource: 'trading_settings', action: 'update',
    detail: { fields: Object.keys(patch) },
  });

  return getOrCreateSettings(userId);
}

// ── 거래 시작 ─────────────────────────────────────────────
async function startTrading(userId, { ip } = {}) {
  const settings = await getOrCreateSettings(userId);
  const db = getDb();

  if (settings.status === 'RUNNING')
    throw Object.assign(new Error('이미 거래가 진행 중입니다'), { status: 409 });

  const missing = [];
  if (!settings.broker_account_id)             missing.push('증권사 계좌 연동');
  if (!settings.daily_budget || settings.daily_budget <= 0) missing.push('일일 예산');

  if (missing.length > 0)
    throw Object.assign(
      new Error(`다음 설정을 먼저 완료하세요: ${missing.join(', ')}`),
      { status: 400 }
    );

  const today = new Date().toISOString().slice(0, 10);
  const resetToday = settings.today_date !== today;
  const now = new Date().toISOString();

  await db.from('trading_settings').update({
    status: 'RUNNING',
    today_date: today,
    today_used_budget:        resetToday ? 0 : settings.today_used_budget,
    today_trade_count:        resetToday ? 0 : settings.today_trade_count,
    today_consecutive_losses: resetToday ? 0 : settings.today_consecutive_losses,
    today_pnl:                resetToday ? 0 : settings.today_pnl,
    updated_at: now,
  }).eq('user_id', userId);

  const sessionId = uuidv4();
  await db.from('trading_sessions').insert({
    id: sessionId,
    user_id: userId,
    broker_account_id: settings.broker_account_id,
    date: today,
    status: 'RUNNING',
    initial_budget: settings.daily_budget,
    settings_snapshot: JSON.stringify(settings),
    started_at: now,
    total_trades: 0,
    winning_trades: 0,
    total_pnl: 0,
  });

  audit.log({
    eventType: audit.AuditEvent.SYSTEM_START,
    actorId: userId, ip,
    resource: 'trading_settings', action: 'start_trading',
    detail: { sessionId, budget: settings.daily_budget },
  });

  return { sessionId, status: 'RUNNING', today };
}

// ── 거래 중지 ─────────────────────────────────────────────
async function stopTrading(userId, reason = '수동 중지', { ip } = {}) {
  const db = getDb();
  const now = new Date().toISOString();

  await db.from('trading_settings')
    .update({ status: 'STOPPED', updated_at: now }).eq('user_id', userId);

  await db.from('trading_sessions')
    .update({ status: 'COMPLETED', ended_at: now, halt_reason: reason })
    .eq('user_id', userId).eq('status', 'RUNNING');

  audit.log({
    eventType: audit.AuditEvent.SYSTEM_HALT,
    actorId: userId, ip,
    resource: 'trading_settings', action: 'stop_trading',
    detail: { reason },
  });

  return getOrCreateSettings(userId);
}

// ── 설정 초기화 ────────────────────────────────────────────
async function resetSettings(userId, { ip } = {}) {
  const settings = await getOrCreateSettings(userId);
  const db = getDb();

  if (settings.status === 'RUNNING')
    throw Object.assign(new Error('거래 중에는 초기화할 수 없습니다'), { status: 409 });

  await db.from('trading_settings').update({
    broker_account_id: null,
    daily_budget: 0, loss_floor: 0,
    trading_start_time: '09:10', trading_end_time: '14:50',
    term_seconds: 60, max_trades: 0, max_consecutive_losses: 3,
    ai_sources_json: '["broker_api","krx"]',
    min_confidence_score: 70, target_profit_rate: 0.02, stop_loss_rate: 0.01,
    status: 'IDLE',
    today_date: null, today_used_budget: 0, today_trade_count: 0,
    today_consecutive_losses: 0, today_pnl: 0,
    updated_at: new Date().toISOString(),
  }).eq('user_id', userId);

  audit.log({
    eventType: audit.AuditEvent.CONFIG_CHANGE,
    actorId: userId, ip,
    resource: 'trading_settings', action: 'reset',
    riskLevel: audit.RiskLevel.MEDIUM,
  });

  return getOrCreateSettings(userId);
}

// ── 오늘 거래 통계 업데이트 (거래 엔진에서 호출) ─────────────
async function updateTodayStats(userId, { tradePnl, isWin }) {
  const db = getDb();
  const { data: settings } = await db
    .from('trading_settings').select('*').eq('user_id', userId).maybeSingle();
  if (!settings) return;

  const newPnl              = (settings.today_pnl || 0) + tradePnl;
  const newCount            = (settings.today_trade_count || 0) + 1;
  const newConsecutiveLosses = isWin ? 0 : (settings.today_consecutive_losses || 0) + 1;
  const newUsedBudget       = (settings.today_used_budget || 0) + Math.abs(tradePnl);

  const currentBalance = settings.daily_budget + newPnl;
  const shouldPause    = currentBalance <= settings.loss_floor;
  const tooManyLosses  = newConsecutiveLosses >= settings.max_consecutive_losses;

  let newStatus  = settings.status;
  let haltReason = null;

  if (shouldPause || tooManyLosses) {
    newStatus = 'PAUSED';
    haltReason = shouldPause
      ? `손실 마지노선 도달 (잔고: ${currentBalance.toLocaleString()}원)`
      : `연속 손실 ${newConsecutiveLosses}회 도달`;

    const now = new Date().toISOString();
    await db.from('trading_sessions').update({
      status: 'HALTED', ended_at: now, halt_reason: haltReason,
      total_trades: newCount, total_pnl: newPnl,
    }).eq('user_id', userId).eq('status', 'RUNNING');

    audit.log({
      eventType: audit.AuditEvent.CIRCUIT_BREAKER,
      actorId: userId,
      resource: 'trading_settings', action: 'auto_halt',
      detail: { haltReason, balance: currentBalance },
      riskLevel: audit.RiskLevel.HIGH,
    });
  }

  await db.from('trading_settings').update({
    today_pnl:                newPnl,
    today_trade_count:        newCount,
    today_consecutive_losses: newConsecutiveLosses,
    today_used_budget:        newUsedBudget,
    status:                   newStatus,
    updated_at:               new Date().toISOString(),
  }).eq('user_id', userId);

  return { newStatus, haltReason, currentBalance };
}

module.exports = {
  getOrCreateSettings,
  saveSettings,
  startTrading,
  stopTrading,
  resetSettings,
  updateTodayStats,
};
