/**
 * AutoTradeX Trading Settings Service
 * 거래 설정 CRUD + 상태 관리
 * 사용자 워크플로우: 설정 → 시작 → (자동거래) → 중지 → 수정 or 초기화
 */

const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../db/connection');
const audit = require('./audit.service');

// ── 기본값 ────────────────────────────────────────────────
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

// 시간 형식 검증 HH:MM
function isValidTime(t) {
  return /^([01]\d|2[0-3]):([0-5]\d)$/.test(t);
}

// 장 운영 시간 검증 (09:00 ~ 15:30, 단일가 시간 제외)
function isValidTradingTime(start, end) {
  const toMinutes = (t) => {
    const [h, m] = t.split(':').map(Number);
    return h * 60 + m;
  };
  const startMin = toMinutes(start);
  const endMin = toMinutes(end);
  const marketOpen = toMinutes('09:00');
  const preClose = toMinutes('14:50'); // 15:20~15:30 단일가 전
  const marketClose = toMinutes('15:20');

  if (startMin < marketOpen + 10) return '거래 시작은 09:10 이후로 설정하세요 (장 시작 후 10분 대기)';
  if (endMin > preClose) return '거래 종료는 14:50 이전으로 설정하세요 (단일가 거래 제외)';
  if (startMin >= endMin) return '거래 종료 시간은 시작 시간보다 늦어야 합니다';
  return null;
}

// ── 설정 조회 (없으면 기본값으로 생성) ─────────────────────
function getOrCreateSettings(userId) {
  const db = getDb();
  let settings = db.prepare(
    'SELECT * FROM trading_settings WHERE user_id = ?'
  ).get(userId);

  if (!settings) {
    const id = uuidv4();
    db.prepare(`
      INSERT INTO trading_settings (id, user_id) VALUES (?, ?)
    `).run(id, userId);
    settings = db.prepare('SELECT * FROM trading_settings WHERE id = ?').get(id);
  }

  return formatSettings(settings);
}

// ── 설정 저장/수정 ─────────────────────────────────────────
function saveSettings(userId, updates, { ip } = {}) {
  const db = getDb();
  const current = getOrCreateSettings(userId);

  // RUNNING 상태에서는 수정 불가
  if (current.status === 'RUNNING') {
    throw Object.assign(
      new Error('거래 중에는 설정을 변경할 수 없습니다. 먼저 거래를 중지하세요.'),
      { status: 409 }
    );
  }

  // 검증
  const errors = [];

  if (updates.daily_budget !== undefined) {
    if (updates.daily_budget <= 0) errors.push('일일 예산은 0보다 커야 합니다');
  }

  if (updates.loss_floor !== undefined && updates.daily_budget !== undefined) {
    if (updates.loss_floor >= updates.daily_budget) {
      errors.push('손실 마지노선은 일일 예산보다 작아야 합니다');
    }
    if (updates.loss_floor < 0) errors.push('손실 마지노선은 0 이상이어야 합니다');
  } else if (updates.loss_floor !== undefined) {
    const budget = current.daily_budget;
    if (budget > 0 && updates.loss_floor >= budget) {
      errors.push('손실 마지노선은 일일 예산보다 작아야 합니다');
    }
  }

  const startTime = updates.trading_start_time || current.trading_start_time;
  const endTime = updates.trading_end_time || current.trading_end_time;
  if (updates.trading_start_time || updates.trading_end_time) {
    if (!isValidTime(startTime)) errors.push('거래 시작 시간 형식이 올바르지 않습니다 (HH:MM)');
    if (!isValidTime(endTime)) errors.push('거래 종료 시간 형식이 올바르지 않습니다 (HH:MM)');
    const timeErr = isValidTradingTime(startTime, endTime);
    if (timeErr) errors.push(timeErr);
  }

  if (updates.term_seconds !== undefined && updates.term_seconds < 1) {
    errors.push('TERM은 최소 1초 이상이어야 합니다');
  }

  if (updates.max_trades !== undefined && updates.max_trades < 0) {
    errors.push('최대 거래 횟수는 0 이상이어야 합니다 (0=무제한)');
  }

  if (errors.length > 0) {
    throw Object.assign(new Error(errors.join('\n')), { status: 400, errors });
  }

  // ai_sources 처리
  if (updates.ai_sources && Array.isArray(updates.ai_sources)) {
    updates.ai_sources_json = JSON.stringify(updates.ai_sources);
    delete updates.ai_sources;
  }

  // 업데이트 쿼리 동적 생성
  const allowed = [
    'broker_account_id', 'daily_budget', 'loss_floor',
    'trading_start_time', 'trading_end_time', 'term_seconds',
    'max_trades', 'max_consecutive_losses', 'ai_sources_json',
    'min_confidence_score', 'target_profit_rate', 'stop_loss_rate',
  ];

  const fields = Object.keys(updates).filter(k => allowed.includes(k));
  if (fields.length === 0) {
    return getOrCreateSettings(userId);
  }

  const setClauses = fields.map(f => `${f} = ?`).join(', ');
  const values = fields.map(f => updates[f]);

  db.prepare(`
    UPDATE trading_settings
    SET ${setClauses}, status = 'CONFIGURED', updated_at = datetime('now')
    WHERE user_id = ?
  `).run(...values, userId);

  audit.log({
    eventType: audit.AuditEvent.CONFIG_CHANGE,
    actorId: userId, ip,
    resource: 'trading_settings',
    action: 'update',
    detail: { fields },
  });

  return getOrCreateSettings(userId);
}

// ── 거래 시작 ─────────────────────────────────────────────
function startTrading(userId, { ip } = {}) {
  const db = getDb();
  const settings = getOrCreateSettings(userId);

  if (settings.status === 'RUNNING') {
    throw Object.assign(new Error('이미 거래가 진행 중입니다'), { status: 409 });
  }

  // 필수 설정 확인
  const missing = [];
  if (!settings.broker_account_id) missing.push('증권사 계좌 연동');
  if (!settings.daily_budget || settings.daily_budget <= 0) missing.push('일일 예산');
  if (!settings.loss_floor && settings.loss_floor !== 0) missing.push('손실 마지노선');

  if (missing.length > 0) {
    throw Object.assign(
      new Error(`다음 설정을 먼저 완료하세요: ${missing.join(', ')}`),
      { status: 400 }
    );
  }

  // 오늘 날짜 확인 → 날짜 바뀌면 일일 통계 리셋
  const today = new Date().toISOString().slice(0, 10);
  const resetToday = settings.today_date !== today;

  db.prepare(`
    UPDATE trading_settings SET
      status = 'RUNNING',
      today_date = ?,
      today_used_budget = ?,
      today_trade_count = ?,
      today_consecutive_losses = ?,
      today_pnl = ?,
      updated_at = datetime('now')
    WHERE user_id = ?
  `).run(
    today,
    resetToday ? 0 : settings.today_used_budget,
    resetToday ? 0 : settings.today_trade_count,
    resetToday ? 0 : settings.today_consecutive_losses,
    resetToday ? 0 : settings.today_pnl,
    userId
  );

  // 세션 기록 생성
  const sessionId = uuidv4();
  db.prepare(`
    INSERT INTO trading_sessions
      (id, user_id, broker_account_id, date, initial_budget, settings_snapshot)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(
    sessionId, userId, settings.broker_account_id, today,
    settings.daily_budget, JSON.stringify(settings)
  );

  audit.log({
    eventType: audit.AuditEvent.SYSTEM_START,
    actorId: userId, ip,
    resource: 'trading_settings',
    action: 'start_trading',
    detail: { sessionId, budget: settings.daily_budget },
  });

  return { sessionId, status: 'RUNNING', today };
}

// ── 거래 중지 ─────────────────────────────────────────────
function stopTrading(userId, reason = '수동 중지', { ip } = {}) {
  const db = getDb();

  db.prepare(`
    UPDATE trading_settings SET
      status = 'STOPPED', updated_at = datetime('now')
    WHERE user_id = ?
  `).run(userId);

  // 진행 중인 세션 종료 처리
  db.prepare(`
    UPDATE trading_sessions SET
      status = 'COMPLETED', ended_at = datetime('now'), halt_reason = ?
    WHERE user_id = ? AND status = 'RUNNING'
  `).run(reason, userId);

  audit.log({
    eventType: audit.AuditEvent.SYSTEM_HALT,
    actorId: userId, ip,
    resource: 'trading_settings',
    action: 'stop_trading',
    detail: { reason },
  });

  return getOrCreateSettings(userId);
}

// ── 설정 초기화 ────────────────────────────────────────────
function resetSettings(userId, { ip } = {}) {
  const db = getDb();
  const settings = getOrCreateSettings(userId);

  if (settings.status === 'RUNNING') {
    throw Object.assign(new Error('거래 중에는 초기화할 수 없습니다'), { status: 409 });
  }

  db.prepare(`
    UPDATE trading_settings SET
      broker_account_id = NULL,
      daily_budget = 0, loss_floor = 0,
      trading_start_time = '09:10', trading_end_time = '14:50',
      term_seconds = 60, max_trades = 0, max_consecutive_losses = 3,
      ai_sources_json = '["broker_api","krx"]',
      min_confidence_score = 70, target_profit_rate = 0.02, stop_loss_rate = 0.01,
      status = 'IDLE',
      today_date = NULL, today_used_budget = 0, today_trade_count = 0,
      today_consecutive_losses = 0, today_pnl = 0,
      updated_at = datetime('now')
    WHERE user_id = ?
  `).run(userId);

  audit.log({
    eventType: audit.AuditEvent.CONFIG_CHANGE,
    actorId: userId, ip,
    resource: 'trading_settings',
    action: 'reset',
    riskLevel: audit.RiskLevel.MEDIUM,
  });

  return getOrCreateSettings(userId);
}

// ── 오늘 거래 통계 업데이트 (거래 엔진에서 호출) ─────────────
function updateTodayStats(userId, { tradePnl, isWin }) {
  const db = getDb();
  const settings = db.prepare('SELECT * FROM trading_settings WHERE user_id = ?').get(userId);
  if (!settings) return;

  const newPnl = (settings.today_pnl || 0) + tradePnl;
  const newCount = (settings.today_trade_count || 0) + 1;
  const newConsecutiveLosses = isWin ? 0 : (settings.today_consecutive_losses || 0) + 1;
  const newUsedBudget = (settings.today_used_budget || 0) + Math.abs(tradePnl);

  // 손실 마지노선 체크
  const currentBalance = settings.daily_budget + newPnl; // 예산 + 손익
  const shouldPause = currentBalance <= settings.loss_floor;
  const tooManyLosses = newConsecutiveLosses >= settings.max_consecutive_losses;

  let newStatus = settings.status;
  let haltReason = null;

  if (shouldPause || tooManyLosses) {
    newStatus = 'PAUSED';
    haltReason = shouldPause
      ? `손실 마지노선 도달 (잔고: ${currentBalance.toLocaleString()}원, 마지노선: ${settings.loss_floor.toLocaleString()}원)`
      : `연속 손실 ${newConsecutiveLosses}회 도달`;

    // 세션 종료 처리
    db.prepare(`
      UPDATE trading_sessions SET
        status = 'HALTED', ended_at = datetime('now'), halt_reason = ?,
        total_trades = ?, total_pnl = ?
      WHERE user_id = ? AND status = 'RUNNING'
    `).run(haltReason, newCount, newPnl, userId);

    audit.log({
      eventType: audit.AuditEvent.CIRCUIT_BREAKER,
      actorId: userId,
      resource: 'trading_settings',
      action: 'auto_halt',
      detail: { haltReason, balance: currentBalance, lossFlo: settings.loss_floor },
      riskLevel: audit.RiskLevel.HIGH,
    });
  }

  db.prepare(`
    UPDATE trading_settings SET
      today_pnl = ?, today_trade_count = ?,
      today_consecutive_losses = ?, today_used_budget = ?,
      status = ?, updated_at = datetime('now')
    WHERE user_id = ?
  `).run(newPnl, newCount, newConsecutiveLosses, newUsedBudget, newStatus, userId);

  return { newStatus, haltReason, currentBalance };
}

// ── 포맷 변환 ─────────────────────────────────────────────
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

module.exports = {
  getOrCreateSettings,
  saveSettings,
  startTrading,
  stopTrading,
  resetSettings,
  updateTodayStats,
};
