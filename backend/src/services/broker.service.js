/**
 * AutoTradeX Broker Account Service
 * 한국투자증권(KIS) 전용
 *
 * 책임:
 *  - 계좌 연동 (토큰 발급 → DB 저장)
 *  - appKey / appSecret AES-256-GCM 암호화 저장
 *  - 액세스토큰 자동 갱신 (24h 만료 전 재발급)
 *  - 연동 계좌 목록 / 비활성화
 *
 * 새 증권사 추가 시:
 *  → src/brokers/ 하위에 구현체 추가 후
 *  → src/brokers/index.js 팩토리에만 등록하면 됩니다.
 */

const { v4: uuidv4 }    = require('uuid');
const { getDb }          = require('../db/connection');
const { encrypt, decrypt } = require('./crypto.service');
const audit              = require('./audit.service');
const { createBroker }   = require('../brokers');

// ── 상수 ──────────────────────────────────────────────────────
const TOKEN_REFRESH_MARGIN_MS = 30 * 60 * 1000; // 만료 30분 전 갱신

// ── 내부 헬퍼: DB 행 → 복호화된 인증정보 ──────────────────────
function _decryptRow(row) {
  return {
    accessToken: row.encrypted_access_token ? decrypt(row.encrypted_access_token) : null,
    appKey:      row.encrypted_app_key      ? decrypt(row.encrypted_app_key)      : null,
    appSecret:   row.encrypted_app_secret   ? decrypt(row.encrypted_app_secret)   : null,
  };
}

// ── 토큰 유효성 확인 ───────────────────────────────────────────
function _isTokenValid(tokenExpiresAt) {
  if (!tokenExpiresAt) return false;
  return new Date(tokenExpiresAt) > new Date(Date.now() + TOKEN_REFRESH_MARGIN_MS);
}

// ── 계좌 연동 (토큰 발급 + DB 저장) ──────────────────────────
async function connectBrokerAccount({ userId, broker, appKey, appSecret, accountNo, isMock, ip }) {
  if (broker !== 'kis') {
    throw new Error(`현재 지원하는 브로커: KIS(한국투자증권). 요청된 브로커: ${broker}`);
  }

  const db = getDb();
  const kisInstance = createBroker('kis', { accountNo, isMock });

  // 1. 토큰 발급
  let tokenData;
  try {
    tokenData = await kisInstance.fetchToken({ appKey, appSecret });
  } catch (err) {
    if (process.env.NODE_ENV !== 'production') {
      // 개발환경: 실제 키 없으면 목업 토큰으로 대체
      console.warn(`[BROKER] KIS API 실패, 목업 토큰 사용: ${err.message}`);
      tokenData = {
        accessToken: `MOCK_KIS_TOKEN_${Date.now()}`,
        expiresAt:   new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        tokenType:   'Bearer',
      };
    } else {
      throw err;
    }
  }

  // 2. 잔고 조회 (실패해도 연동은 진행)
  let balance = null;
  try {
    const balData = await kisInstance.getBalance({
      accessToken: tokenData.accessToken,
      appKey, appSecret,
    });
    balance = balData.availableCash;
  } catch (_) { /* 잔고 조회 실패는 치명적이지 않음 */ }

  // 3. DB 저장 (기존 계좌 업데이트 or 신규 생성)
  const encToken     = encrypt(tokenData.accessToken);
  const encAppKey    = encrypt(appKey);
  const encAppSecret = encrypt(appSecret);
  const accountId    = uuidv4();

  const existing = db.prepare(
    'SELECT id FROM broker_accounts WHERE user_id = ? AND broker = ? AND account_no = ?'
  ).get(userId, broker, accountNo);

  if (existing) {
    db.prepare(`
      UPDATE broker_accounts SET
        encrypted_access_token = ?,
        encrypted_app_key      = ?,
        encrypted_app_secret   = ?,
        token_expires_at       = ?,
        last_balance           = ?,
        last_balance_checked_at = datetime('now'),
        is_active              = 1,
        is_mock                = ?,
        updated_at             = datetime('now')
      WHERE id = ?
    `).run(encToken, encAppKey, encAppSecret, tokenData.expiresAt, balance, isMock ? 1 : 0, existing.id);

    audit.log({
      eventType: audit.AuditEvent.API_KEY_ROTATE,
      actorId: userId, ip,
      resource: 'broker_accounts',
      action: 'token_refresh',
      detail: { broker, isMock },
    });
    return existing.id;

  } else {
    db.prepare(`
      INSERT INTO broker_accounts
        (id, user_id, broker, account_no, is_mock,
         encrypted_access_token, encrypted_app_key, encrypted_app_secret,
         token_expires_at, last_balance, last_balance_checked_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
    `).run(accountId, userId, broker, accountNo, isMock ? 1 : 0,
      encToken, encAppKey, encAppSecret, tokenData.expiresAt, balance);

    audit.log({
      eventType: audit.AuditEvent.API_KEY_REGISTER,
      actorId: userId, ip,
      resource: 'broker_accounts',
      action: 'connect',
      detail: { broker, isMock, accountNo },
      riskLevel: audit.RiskLevel.HIGH,
    });
    return accountId;
  }
}

// ── 저장된 인증정보 조회 (복호화 포함, 토큰 자동 갱신) ──────
async function getBrokerCredentials(brokerAccountId) {
  const db  = getDb();
  const row = db.prepare(
    `SELECT id, broker, account_no, is_mock, is_active,
            encrypted_access_token, encrypted_app_key, encrypted_app_secret,
            token_expires_at
     FROM broker_accounts WHERE id = ? AND is_active = 1`
  ).get(brokerAccountId);

  if (!row) return null;

  const { accessToken, appKey, appSecret } = _decryptRow(row);
  if (!appKey || !appSecret) return null;

  // 토큰 만료 임박 시 자동 갱신
  if (!_isTokenValid(row.token_expires_at)) {
    try {
      const kisInstance = createBroker(row.broker, {
        accountNo: row.account_no,
        isMock: !!row.is_mock,
      });
      const newToken = await kisInstance.fetchToken({ appKey, appSecret });
      const encToken = encrypt(newToken.accessToken);

      db.prepare(`
        UPDATE broker_accounts
        SET encrypted_access_token = ?, token_expires_at = ?, updated_at = datetime('now')
        WHERE id = ?
      `).run(encToken, newToken.expiresAt, brokerAccountId);

      return {
        accessToken: newToken.accessToken,
        appKey, appSecret,
        accountNo:  row.account_no,
        broker:     row.broker,
        isMock:     !!row.is_mock,
      };
    } catch (err) {
      console.warn(`[BROKER] 토큰 자동 갱신 실패: ${err.message}`);
      // 실패해도 기존 토큰으로 시도
    }
  }

  return {
    accessToken,
    appKey, appSecret,
    accountNo: row.account_no,
    broker:    row.broker,
    isMock:    !!row.is_mock,
  };
}

// ── 연동 계좌 목록 ─────────────────────────────────────────────
function getBrokerAccounts(userId) {
  const db = getDb();
  return db.prepare(`
    SELECT id, broker, account_no, account_name, is_mock, is_active,
           last_balance, last_balance_checked_at, connected_at, token_expires_at
    FROM broker_accounts
    WHERE user_id = ? ORDER BY connected_at DESC
  `).all(userId).map(row => ({
    ...row,
    is_mock:      !!row.is_mock,
    is_active:    !!row.is_active,
    isTokenValid: _isTokenValid(row.token_expires_at),
  }));
}

// ── 계좌 비활성화 ──────────────────────────────────────────────
function deactivateBrokerAccount(brokerAccountId, userId) {
  const db = getDb();
  const account = db.prepare(
    'SELECT id FROM broker_accounts WHERE id = ? AND user_id = ?'
  ).get(brokerAccountId, userId);
  if (!account) throw Object.assign(new Error('계좌를 찾을 수 없습니다'), { status: 404 });

  db.prepare('UPDATE broker_accounts SET is_active = 0, updated_at = datetime(\'now\') WHERE id = ?')
    .run(brokerAccountId);
}

module.exports = {
  connectBrokerAccount,
  getBrokerCredentials,
  getBrokerAccounts,
  deactivateBrokerAccount,
};
