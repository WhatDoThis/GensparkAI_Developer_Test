/**
 * AutoTradeX Trading Engine Core
 * Q1: 현실적 수익 목표 (설정값 기반, 기본 0.5~2%)
 * Q2: AI 호출 vs 거래 횟수 분리 — TERM마다 AI 분석, 신호 시 주문
 * Q3: 연속 손실 강제 중단 + 동일종목 재매수 금지 타이머
 */

const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../db/connection');
const kisMarket = require('./kis-market.service');
const indicators = require('./technical-indicators.service');
const { updateTodayStats, getOrCreateSettings } = require('./trading-settings.service');
const audit = require('./audit.service');
const { signHmac } = require('./crypto.service');

// ── 인메모리 상태 (프로세스 재시작 시 초기화됨) ─────────────
const activeEngines = new Map(); // userId → engineState
const recentTrades = new Map();  // `${userId}:${code}` → lastTradeAt (Q3: 재매수 금지)

const COOLDOWN_AFTER_LOSS_MS = 5 * 60 * 1000; // Q3: 손실 종목 5분 재매수 금지

// ── 엔진 시작 ────────────────────────────────────────────
function startEngine(userId, settings) {
  if (activeEngines.has(userId)) return; // 이미 실행 중

  const state = {
    userId,
    settings,
    isRunning: true,
    currentPositions: new Map(), // code → { quantity, avgPrice, targetPrice, stopPrice }
    sessionPnl: 0,
    sessionTrades: 0,
    lastCycleAt: null,
    timer: null,
  };
  activeEngines.set(userId, state);

  console.log(`[ENGINE] Started for user ${userId}, TERM=${settings.term_seconds}s`);

  // 첫 사이클 즉시 실행
  runCycle(state).catch(e => console.error('[ENGINE] cycle error:', e));
  return state;
}

// ── 엔진 중지 ────────────────────────────────────────────
function stopEngine(userId) {
  const state = activeEngines.get(userId);
  if (!state) return;
  state.isRunning = false;
  if (state.timer) clearTimeout(state.timer);
  activeEngines.delete(userId);
  console.log(`[ENGINE] Stopped for user ${userId}`);
}

// ── 단일 거래 사이클 ──────────────────────────────────────
// Q2: TERM마다 실행 → AI 분석 → 신호 있을 때만 주문 실행
async function runCycle(state) {
  if (!state.isRunning) return;

  const { userId, settings } = state;
  state.lastCycleAt = Date.now();

  try {
    // 0. 현재 설정 새로 로드 (거래 중 변경 대응)
    const currentSettings = getOrCreateSettings(userId);
    if (currentSettings.status !== 'RUNNING') {
      console.log(`[ENGINE] User ${userId} status changed to ${currentSettings.status}, stopping.`);
      stopEngine(userId);
      return;
    }

    // 1. 장 운영 시간 체크
    if (!isMarketTime(currentSettings)) {
      scheduleNext(state, currentSettings.term_seconds);
      return;
    }

    // 2. 거래 횟수 한도 체크 (Q2: 거래 횟수 = 실제 주문 횟수)
    if (currentSettings.max_trades > 0 &&
        currentSettings.today_trade_count >= currentSettings.max_trades) {
      console.log(`[ENGINE] Max trades reached (${currentSettings.today_trade_count}/${currentSettings.max_trades})`);
      stopEngine(userId);
      updateTodayStats(userId, { tradePnl: 0, isWin: true }); // 횟수 초과 → 자동 중지
      return;
    }

    // 3. 예산 잔여액 체크 (설정 기반 로컬 계산)
    const remainingBudget = currentSettings.daily_budget + (currentSettings.today_pnl || 0);
    if (remainingBudget <= currentSettings.loss_floor) {
      console.log(`[ENGINE] Loss floor reached for user ${userId} (budget: ${remainingBudget})`);
      stopEngine(userId);
      return;
    }

    // 3-1. 실계좌 예수금 실시간 확인
    //   남은 예수금 < 설정 거래금액(daily_budget) → 자동 정지
    //   (현금 거래만 사용하므로 예수금이 부족하면 주문 자체가 불가)
    if (currentSettings.broker_account_id) {
      try {
        const cashData = await kisMarket.getAvailableCash(currentSettings.broker_account_id);
        const realCash = cashData.availableCash;
        const perTradeBudget = Math.min(
          currentSettings.daily_budget * 0.3,  // 거래당 예산의 30%
          remainingBudget - currentSettings.loss_floor
        );
        if (!cashData.isMock && realCash < perTradeBudget) {
          const reason = `실계좌 예수금 부족 (예수금: ${realCash.toLocaleString()}원, 필요금액: ${Math.round(perTradeBudget).toLocaleString()}원)`;
          console.log(`[ENGINE] Auto-stop: ${reason}`);
          stopEngine(userId);
          const { getDb } = require('../db/connection');
          getDb().prepare(
            `UPDATE trading_settings SET status='PAUSED', updated_at=datetime('now') WHERE user_id=?`
          ).run(userId);
          audit.log({
            eventType: audit.AuditEvent.ANOMALY_DETECTED,
            actorId: userId, resource: 'trading_engine',
            action: 'auto_stop_low_cash',
            detail: { realCash, perTradeBudget, reason },
            riskLevel: audit.RiskLevel.HIGH,
          });
          return;
        }
      } catch (cashErr) {
        console.warn(`[ENGINE] 예수금 조회 실패 (계속 진행): ${cashErr.message}`);
        // 예수금 조회 실패 시 거래 중단하지 않고 설정값 기준으로 계속 진행
      }
    }

    // 4. 보유 포지션 청산 체크 (목표가/손절가 도달 여부)
    await checkExistingPositions(state, currentSettings);

    // 5. 신규 매수 신호 분석 (Q2: AI 호출)
    if (state.currentPositions.size < 3) { // 최대 3개 동시 보유
      await analyzeAndTrade(state, currentSettings, remainingBudget);
    }

  } catch (err) {
    console.error(`[ENGINE] Cycle error for user ${userId}:`, err.message);
    audit.log({
      eventType: audit.AuditEvent.ANOMALY_DETECTED,
      actorId: userId,
      resource: 'trading_engine',
      action: 'cycle_error',
      result: 'FAILURE',
      detail: { error: err.message },
      riskLevel: audit.RiskLevel.HIGH,
    });
  }

  // 다음 사이클 예약
  if (state.isRunning) {
    scheduleNext(state, settings.term_seconds);
  }
}

// ── 기존 포지션 청산 체크 ─────────────────────────────────
async function checkExistingPositions(state, settings) {
  for (const [code, position] of state.currentPositions.entries()) {
    const priceData = await kisMarket.getCurrentPrice(code, settings.broker_account_id);
    const currentPrice = priceData.currentPrice;
    const pnlRate = (currentPrice - position.avgPrice) / position.avgPrice;

    const shouldSell =
      pnlRate >= settings.target_profit_rate ||  // Q1: 목표 수익 도달
      pnlRate <= -settings.stop_loss_rate;        // Q1: 손절 도달

    if (shouldSell) {
      const reason = pnlRate >= 0 ? '목표수익 달성' : '손절 실행';
      await executeSell(state, settings, code, position, currentPrice, pnlRate, reason);
    }
  }
}

// ── 분석 + 신규 매수 (Q2: AI 호출 분리) ─────────────────
async function analyzeAndTrade(state, settings, remainingBudget) {
  const { userId } = state;

  // 5-1. 종목 풀 가져오기
  const candidates = await kisMarket.getTopStocks(20, settings.broker_account_id);

  // 5-2. 기술적 지표 계산
  const scored = [];
  for (const stock of candidates.slice(0, 10)) { // 상위 10개만 분석
    // Q3: 최근 손실 종목 재매수 금지 쿨다운
    const key = `${userId}:${stock.code}`;
    const lastTrade = recentTrades.get(key);
    if (lastTrade && Date.now() - lastTrade < COOLDOWN_AFTER_LOSS_MS) continue;

    // 이미 보유 중인 종목 스킵
    if (state.currentPositions.has(stock.code)) continue;

    const ohlcv = await kisMarket.getDailyOhlcv(stock.code, 60, settings.broker_account_id);
    const techScore = indicators.calculateAll(ohlcv);
    if (!techScore) continue;

    if (techScore.score >= settings.min_confidence_score) {
      scored.push({ stock, techScore, ohlcv });
    }
  }

  if (scored.length === 0) return; // 조건 만족 종목 없음

  // 5-3. AI 분석 (Q2: 주문 전 AI 확인)
  // 상위 3개만 AI에게 전달
  scored.sort((a, b) => b.techScore.score - a.techScore.score);
  const topCandidates = scored.slice(0, 3);

  const aiResult = await callAIAnalysis(topCandidates, settings, remainingBudget);
  if (!aiResult || !aiResult.selected) return;

  const selected = topCandidates.find(c => c.stock.code === aiResult.selected.code);
  if (!selected) return;

  // AI 신뢰도 최종 확인
  if (aiResult.confidence < settings.min_confidence_score) {
    console.log(`[ENGINE] AI confidence too low: ${aiResult.confidence}`);
    return;
  }

  // 5-4. 주문 실행 (Q2: AI 신호 있을 때만 주문)
  const currentPrice = selected.stock.currentPrice;
  const orderBudget = Math.min(
    remainingBudget * 0.3, // 예산의 30% 이하
    remainingBudget - settings.loss_floor // 마지노선 초과 안 되게
  );
  if (orderBudget <= 0) return;

  const quantity = Math.max(1, Math.floor(orderBudget / currentPrice));

  await executeBuy(state, settings, selected.stock, currentPrice, quantity, aiResult);
}

// ── AI 분석 호출 (Genspark 전용) ────────────────────────────
async function callAIAnalysis(candidates, settings, remainingBudget) {
  const apiKey = process.env.GENSPARK_API_KEY;
  const provider = process.env.AI_PROVIDER || 'mock';

  // mock 모드 or API 키 없으면 목업 응답
  if (provider === 'mock' || !apiKey || apiKey === '여기에_Genspark_API_키_입력') {
    console.log('[AI] mock 모드 — Genspark API 키를 .env에 입력하면 실제 AI 분석을 사용합니다.');
    return mockAIResponse(candidates);
  }

  const prompt = buildAIPrompt(candidates, settings, remainingBudget);
  const baseUrl = process.env.GENSPARK_BASE_URL || 'https://api.genspark.ai/v1';
  const model = process.env.GENSPARK_MODEL || 'genspark-moa-1';

  try {
    const response = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [
          {
            role: 'system',
            content: '당신은 한국 주식 단기 매매 전문가입니다. 기술적 분석 데이터를 바탕으로 매수 종목을 선택하고 반드시 JSON 형식으로만 응답합니다.',
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        temperature: 0.2,       // 분석은 낮은 temperature (일관성 우선)
        max_tokens: 512,
        response_format: { type: 'json_object' },  // JSON 강제 응답
      }),
      signal: AbortSignal.timeout(15000),           // 15초 타임아웃
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`Genspark API ${response.status}: ${errBody}`);
    }

    const data = await response.json();
    const content = data?.choices?.[0]?.message?.content;
    if (!content) throw new Error('Genspark 응답에 content 없음');

    // JSON 파싱 시도
    const parsed = JSON.parse(content);
    console.log(`[AI] Genspark 분석 완료 — 선택: ${parsed.selected?.name}(${parsed.selected?.code}), 신뢰도: ${parsed.confidence}`);

    // 필수 필드 검증
    if (!parsed.selected?.code || typeof parsed.confidence !== 'number') {
      throw new Error('응답 필드 불완전');
    }

    return {
      selected:        parsed.selected,
      reason:          parsed.reason || '기술적 분석 기반 선택',
      confidence:      Math.min(100, Math.max(0, parsed.confidence)),
      targetPriceRate: parsed.targetPriceRate ?? 0.015,
      stopLossRate:    parsed.stopLossRate    ?? 0.01,
      isMock:          false,
    };

  } catch (err) {
    console.warn('[AI] Genspark 호출 실패 → mock 응답 사용:', err.message);
    return mockAIResponse(candidates);
  }
}

function buildAIPrompt(candidates, settings, budget) {
  const candText = candidates.map(c => `
종목: ${c.stock.name}(${c.stock.code})
현재가: ${c.stock.currentPrice.toLocaleString()}원
기술적 점수: ${c.techScore.score}/100
주요 신호: ${c.techScore.signals.join(', ')}
RSI: ${c.techScore.rsi}, MACD: ${c.techScore.macd?.crossover}
볼린저밴드: ${c.techScore.bollingerBands?.signal}
추세: ${c.techScore.trend}
  `.trim()).join('\n\n');

  return `
한국 주식 단기 매매 분석 요청 (당일 수익 목표: ${(settings.target_profit_rate * 100).toFixed(1)}%, 손절: ${(settings.stop_loss_rate * 100).toFixed(1)}%)
가용 예산: ${budget.toLocaleString()}원

분석 종목:
${candText}

요청:
1. 위 종목 중 지금 당장 매수하기 가장 적합한 1개 종목 선택
2. 선택 이유 (기술적 근거 중심, 2~3문장)
3. AI 신뢰도 점수 (0~100)
4. 목표가, 손절가 제안

JSON 형식으로 응답:
{"selected": {"code": "종목코드", "name": "종목명"}, "reason": "...", "confidence": 75, "targetPriceRate": 0.015, "stopLossRate": 0.01}
  `.trim();
}

function mockAIResponse(candidates) {
  if (candidates.length === 0) return null;
  const best = candidates[0];
  return {
    selected: { code: best.stock.code, name: best.stock.name },
    reason: `RSI ${best.techScore.rsi} 과매도 구간 + MACD ${best.techScore.macd?.crossover} 진입 시점. 기술적 점수 ${best.techScore.score}점으로 단기 반등 가능성 높음.`,
    confidence: best.techScore.score,
    targetPriceRate: 0.015,  // Q1: 기본 1.5% (현실적)
    stopLossRate: 0.01,       // Q1: 기본 1% 손절
    isMock: true,
  };
}

// ── 매수 실행 ─────────────────────────────────────────────
async function executeBuy(state, settings, stock, price, quantity, aiResult) {
  const { userId } = state;
  const db = getDb();
  const tradeId = uuidv4();

  // HMAC 서명 (주문 무결성)
  const orderData = { userId, code: stock.code, price, quantity, type: 'BUY', ts: Date.now() };
  const hmac = signHmac(orderData);

  try {
    const orderResult = await kisMarket.placeOrder({
      brokerAccountId: settings.broker_account_id,
      code: stock.code,
      orderType: 'BUY',
      quantity,
      price,
    });

    const targetPrice = Math.round(price * (1 + (aiResult.targetPriceRate || settings.target_profit_rate)));
    const stopPrice = Math.round(price * (1 - (aiResult.stopLossRate || settings.stop_loss_rate)));

    // 포지션 기록
    state.currentPositions.set(stock.code, {
      tradeId,
      quantity,
      avgPrice: price,
      targetPrice,
      stopPrice,
      orderId: orderResult.orderId,
    });

    // DB 저장
    db.prepare(`
      INSERT INTO trades (id, user_id, broker, stock_code, stock_name, trade_type,
        quantity, price, total_amount, status, order_id, hmac_signature, ai_confidence, ai_reason)
      VALUES (?, ?, 'kis', ?, ?, 'BUY', ?, ?, ?, 'FILLED', ?, ?, ?, ?)
    `).run(tradeId, userId, stock.code, stock.name, quantity, price,
      price * quantity, orderResult.orderId, hmac, aiResult.confidence, aiResult.reason);

    console.log(`[ENGINE] BUY ${stock.code} ${quantity}주 @${price}원 (목표:${targetPrice}, 손절:${stopPrice})`);

    audit.log({
      eventType: audit.AuditEvent.ORDER_PLACE,
      actorId: userId,
      resource: 'trades',
      action: 'buy',
      detail: { code: stock.code, price, quantity, targetPrice, stopPrice, aiConfidence: aiResult.confidence },
    });

  } catch (err) {
    console.error(`[ENGINE] Buy failed for ${stock.code}:`, err.message);
    audit.log({
      eventType: audit.AuditEvent.ORDER_REJECTED,
      actorId: userId,
      resource: 'trades',
      action: 'buy_failed',
      result: 'FAILURE',
      detail: { code: stock.code, error: err.message },
      riskLevel: audit.RiskLevel.MEDIUM,
    });
  }
}

// ── 매도 실행 ─────────────────────────────────────────────
async function executeSell(state, settings, code, position, currentPrice, pnlRate, reason) {
  const { userId } = state;
  const db = getDb();
  const tradeId = uuidv4();
  const pnlAmount = Math.round((currentPrice - position.avgPrice) * position.quantity);
  const isWin = pnlAmount > 0;

  const orderData = { userId, code, price: currentPrice, quantity: position.quantity, type: 'SELL', ts: Date.now() };
  const hmac = signHmac(orderData);

  try {
    await kisMarket.placeOrder({
      brokerAccountId: settings.broker_account_id,
      code,
      orderType: 'SELL',
      quantity: position.quantity,
      price: currentPrice,
    });

    state.currentPositions.delete(code);

    // Q3: 손실 종목 재매수 금지 타이머 설정
    if (!isWin) {
      recentTrades.set(`${userId}:${code}`, Date.now());
      console.log(`[ENGINE] Cooldown set for ${code} (loss trade)`);
    }

    // DB 저장
    db.prepare(`
      INSERT INTO trades (id, user_id, broker, stock_code, trade_type,
        quantity, price, total_amount, profit_loss, profit_loss_rate,
        status, hmac_signature, ai_reason)
      VALUES (?, ?, 'kis', ?, 'SELL', ?, ?, ?, ?, ?, 'FILLED', ?, ?)
    `).run(tradeId, userId, code, position.quantity, currentPrice,
      currentPrice * position.quantity, pnlAmount,
      parseFloat((pnlRate * 100).toFixed(2)), hmac, reason);

    // 오늘 통계 업데이트 + 손실 마지노선/연속 손실 체크
    const result = updateTodayStats(userId, { tradePnl: pnlAmount, isWin });
    if (result?.newStatus === 'PAUSED') {
      console.log(`[ENGINE] Auto-halt: ${result.haltReason}`);
      stopEngine(userId);
    }

    state.sessionPnl += pnlAmount;
    state.sessionTrades++;

    console.log(`[ENGINE] SELL ${code} @${currentPrice}원 | ${reason} | PnL: ${pnlAmount.toLocaleString()}원 (${(pnlRate * 100).toFixed(2)}%)`);

    audit.log({
      eventType: audit.AuditEvent.ORDER_PLACE,
      actorId: userId,
      resource: 'trades',
      action: 'sell',
      detail: { code, price: currentPrice, pnlAmount, pnlRate, reason },
    });

  } catch (err) {
    console.error(`[ENGINE] Sell failed for ${code}:`, err.message);
  }
}

// ── 장 운영 시간 체크 ─────────────────────────────────────
function isMarketTime(settings) {
  const now = new Date();
  const tz = 'Asia/Seoul';
  const koreaTime = new Date(now.toLocaleString('en-US', { timeZone: tz }));
  const h = koreaTime.getHours();
  const m = koreaTime.getMinutes();
  const currentMin = h * 60 + m;

  const [sh, sm] = settings.trading_start_time.split(':').map(Number);
  const [eh, em] = settings.trading_end_time.split(':').map(Number);
  const startMin = sh * 60 + sm;
  const endMin = eh * 60 + em;

  // 주말 거래 안함
  const day = koreaTime.getDay();
  if (day === 0 || day === 6) return false;

  return currentMin >= startMin && currentMin < endMin;
}

// ── 다음 사이클 예약 ──────────────────────────────────────
function scheduleNext(state, termSeconds) {
  if (!state.isRunning) return;
  state.timer = setTimeout(() => {
    runCycle(state).catch(e => console.error('[ENGINE] scheduled cycle error:', e));
  }, termSeconds * 1000);
}

// ── 엔진 상태 조회 ────────────────────────────────────────
function getEngineStatus(userId) {
  const state = activeEngines.get(userId);
  if (!state) return { isRunning: false };
  return {
    isRunning: state.isRunning,
    currentPositions: Array.from(state.currentPositions.entries()).map(([code, p]) => ({
      code, ...p,
    })),
    sessionPnl: state.sessionPnl,
    sessionTrades: state.sessionTrades,
    lastCycleAt: state.lastCycleAt,
  };
}

module.exports = { startEngine, stopEngine, getEngineStatus };
