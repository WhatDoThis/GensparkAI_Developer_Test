/**
 * KIS Market Service (어댑터 레이어)
 *
 * trading-engine 등 내부 서비스가 사용하는 단일 진입점.
 * - brokerAccountId가 있으면 KisBroker(실전/모의)로 실제 API 호출
 * - 없거나 MOCK 토큰이면 KisMock 데이터 반환 (폴백)
 *
 * ※ 직접 KIS HTTP 호출은 src/brokers/kis/kis.broker.js 에서 관리
 */

const { getDb }            = require('../db/connection');
const { decrypt }          = require('./crypto.service');
const { createBroker }     = require('../brokers');
const mock                 = require('../brokers/kis/kis.mock');
const brokerService        = require('./broker.service');

// ── 내부 헬퍼: DB → 인증정보 조합 (동기, 토큰 자동갱신 없음) ──
// 빠른 사이클 내에서는 getBrokerCredentials(async) 대신 사용
function _getCredentialsSync(brokerAccountId) {
  if (!brokerAccountId) return null;
  const db  = getDb();
  const row = db.prepare(
    `SELECT broker, account_no, is_mock, is_active,
            encrypted_access_token, encrypted_app_key, encrypted_app_secret, token_expires_at
     FROM broker_accounts WHERE id = ? AND is_active = 1`
  ).get(brokerAccountId);
  if (!row || !row.encrypted_access_token) return null;

  const accessToken = decrypt(row.encrypted_access_token);
  const appKey      = row.encrypted_app_key    ? decrypt(row.encrypted_app_key)    : null;
  const appSecret   = row.encrypted_app_secret ? decrypt(row.encrypted_app_secret) : null;

  // 토큰 만료 체크
  if (row.token_expires_at && new Date(row.token_expires_at) < new Date()) return null;

  return { accessToken, appKey, appSecret, accountNo: row.account_no, broker: row.broker, isMock: !!row.is_mock };
}

function _isMockToken(accessToken) {
  return !accessToken || accessToken.startsWith('MOCK_');
}

// ── 현재가 조회 ────────────────────────────────────────────────
async function getCurrentPrice(code, brokerAccountId = null) {
  const creds = _getCredentialsSync(brokerAccountId);
  if (!creds || _isMockToken(creds.accessToken) || !creds.appKey) {
    return mock.stockPrice(code);
  }
  try {
    const broker = createBroker(creds.broker, { accountNo: creds.accountNo, isMock: creds.isMock });
    return await broker.getCurrentPrice({
      accessToken: creds.accessToken,
      appKey:      creds.appKey,
      appSecret:   creds.appSecret,
      code,
    });
  } catch (err) {
    console.warn(`[KIS-MARKET] getCurrentPrice fallback: ${err.message}`);
    return mock.stockPrice(code);
  }
}

// ── 일봉 OHLCV ────────────────────────────────────────────────
async function getDailyOhlcv(code, days = 60, brokerAccountId = null) {
  const creds = _getCredentialsSync(brokerAccountId);
  if (!creds || _isMockToken(creds.accessToken) || !creds.appKey) {
    return mock.dailyOhlcv(code, days);
  }
  try {
    const broker = createBroker(creds.broker, { accountNo: creds.accountNo, isMock: creds.isMock });
    return await broker.getDailyOhlcv({
      accessToken: creds.accessToken,
      appKey:      creds.appKey,
      appSecret:   creds.appSecret,
      code, days,
    });
  } catch (err) {
    console.warn(`[KIS-MARKET] getDailyOhlcv fallback: ${err.message}`);
    return mock.dailyOhlcv(code, days);
  }
}

// ── 호가 조회 ─────────────────────────────────────────────────
async function getOrderbook(code, brokerAccountId = null) {
  const creds = _getCredentialsSync(brokerAccountId);
  if (!creds || _isMockToken(creds.accessToken) || !creds.appKey) {
    return mock.orderbook(code);
  }
  try {
    const broker = createBroker(creds.broker, { accountNo: creds.accountNo, isMock: creds.isMock });
    return await broker.getOrderbook({
      accessToken: creds.accessToken,
      appKey:      creds.appKey,
      appSecret:   creds.appSecret,
      code,
    });
  } catch (err) {
    console.warn(`[KIS-MARKET] getOrderbook fallback: ${err.message}`);
    return mock.orderbook(code);
  }
}

// ── 잔고/예수금 조회 ──────────────────────────────────────────
// trading-engine에서 예수금 체크 시 사용 (비동기, 토큰 자동갱신 포함)
async function getAvailableCash(brokerAccountId) {
  if (!brokerAccountId) return mock.balance();

  try {
    const creds = await brokerService.getBrokerCredentials(brokerAccountId);
    if (!creds || _isMockToken(creds.accessToken) || !creds.appKey) {
      return mock.balance();
    }
    const broker = createBroker(creds.broker, { accountNo: creds.accountNo, isMock: creds.isMock });
    return await broker.getBalance({
      accessToken: creds.accessToken,
      appKey:      creds.appKey,
      appSecret:   creds.appSecret,
    });
  } catch (err) {
    console.warn(`[KIS-MARKET] getAvailableCash fallback: ${err.message}`);
    return mock.balance();
  }
}

// ── 매수 가능 금액/수량 조회 ──────────────────────────────────
async function getBuyableAmount(brokerAccountId, code = '', price = '', ordDvsn = '01') {
  if (!brokerAccountId) return mock.buyableAmount();

  try {
    const creds = await brokerService.getBrokerCredentials(brokerAccountId);
    if (!creds || _isMockToken(creds.accessToken) || !creds.appKey) {
      return mock.buyableAmount();
    }
    const broker = createBroker(creds.broker, { accountNo: creds.accountNo, isMock: creds.isMock });
    return await broker.getBuyableAmount({
      accessToken: creds.accessToken,
      appKey:      creds.appKey,
      appSecret:   creds.appSecret,
      code, price, ordDvsn,
    });
  } catch (err) {
    console.warn(`[KIS-MARKET] getBuyableAmount fallback: ${err.message}`);
    return mock.buyableAmount();
  }
}

// ── 주문 실행 (현금 매수/매도) ───────────────────────────────
async function placeOrder({ brokerAccountId, code, orderType, quantity, price, ordDvsn = '00' }) {
  const creds = _getCredentialsSync(brokerAccountId);

  if (!creds || _isMockToken(creds.accessToken) || !creds.appKey) {
    // 목업 즉시 체결
    await new Promise(r => setTimeout(r, 200));
    return mock.placeOrder({ code, orderType, quantity, price });
  }

  const broker = createBroker(creds.broker, { accountNo: creds.accountNo, isMock: creds.isMock });
  return await broker.placeOrder({
    accessToken: creds.accessToken,
    appKey:      creds.appKey,
    appSecret:   creds.appSecret,
    code, orderType, quantity, price, ordDvsn,
  });
}

// ── 주문 정정/취소 ────────────────────────────────────────────
async function modifyOrCancelOrder({ brokerAccountId, orgOrderId, branchNo, rvseOrCncl, qty, price }) {
  const creds = _getCredentialsSync(brokerAccountId);
  if (!creds || _isMockToken(creds.accessToken) || !creds.appKey) {
    return { orderId: `MOCK_CANCEL_${Date.now()}`, isMock: true };
  }
  const broker = createBroker(creds.broker, { accountNo: creds.accountNo, isMock: creds.isMock });
  return await broker.modifyOrCancelOrder({
    accessToken: creds.accessToken,
    appKey:      creds.appKey,
    appSecret:   creds.appSecret,
    orgOrderId, branchNo, rvseOrCncl, qty, price,
  });
}

// ── 일별 체결 조회 ────────────────────────────────────────────
async function getDailyOrders(brokerAccountId, startDate, endDate, sllBuyDvsnCd = '00') {
  const creds = _getCredentialsSync(brokerAccountId);
  if (!creds || _isMockToken(creds.accessToken) || !creds.appKey) {
    return [];
  }
  try {
    const broker = createBroker(creds.broker, { accountNo: creds.accountNo, isMock: creds.isMock });
    return await broker.getDailyOrders({
      accessToken: creds.accessToken,
      appKey:      creds.appKey,
      appSecret:   creds.appSecret,
      startDate, endDate, sllBuyDvsnCd,
    });
  } catch (err) {
    console.warn(`[KIS-MARKET] getDailyOrders error: ${err.message}`);
    return [];
  }
}

// ── 상위 종목 풀 (분석용) ─────────────────────────────────────
async function getTopStocks(count = 20, brokerAccountId = null) {
  const pool = mock.DEFAULT_POOL.slice(0, count);
  return Promise.all(
    pool.map(code => getCurrentPrice(code, brokerAccountId).catch(() => mock.stockPrice(code)))
  );
}

module.exports = {
  getCurrentPrice,
  getDailyOhlcv,
  getOrderbook,
  getAvailableCash,
  getBuyableAmount,
  placeOrder,
  modifyOrCancelOrder,
  getDailyOrders,
  getTopStocks,
  // 목업 직접 접근 (테스트용)
  mockStockPrice: mock.stockPrice,
  mockOhlcv:      mock.dailyOhlcv,
};
