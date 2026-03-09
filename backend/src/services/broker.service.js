/**
 * AutoTradeX Broker Account Service — Supabase Edition
 * 한국투자증권(KIS) 전용
 */

const { v4: uuidv4 }      = require('uuid');
const { getDb }             = require('../db/connection');
const { encrypt, decrypt }  = require('./crypto.service');
const audit                 = require('./audit.service');
const { createBroker }      = require('../brokers');

const TOKEN_REFRESH_MARGIN_MS = 30 * 60 * 1000;

function _decryptRow(row) {
  return {
    accessToken: row.encrypted_access_token ? decrypt(row.encrypted_access_token) : null,
    appKey:      row.encrypted_app_key      ? decrypt(row.encrypted_app_key)      : null,
    appSecret:   row.encrypted_app_secret   ? decrypt(row.encrypted_app_secret)   : null,
  };
}

function _isTokenValid(tokenExpiresAt) {
  if (!tokenExpiresAt) return false;
  return new Date(tokenExpiresAt) > new Date(Date.now() + TOKEN_REFRESH_MARGIN_MS);
}

// ── 계좌 연동 ─────────────────────────────────────────────
async function connectBrokerAccount({ userId, broker, appKey, appSecret, accountNo, isMock, ip }) {
  if (broker !== 'kis') {
    throw new Error(`현재 지원하는 브로커: KIS(한국투자증권). 요청된 브로커: ${broker}`);
  }

  const db = getDb();
  const kisInstance = createBroker('kis', { accountNo, isMock });

  let tokenData;
  try {
    tokenData = await kisInstance.fetchToken({ appKey, appSecret });
  } catch (err) {
    if (process.env.NODE_ENV !== 'production') {
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

  let balance = null;
  try {
    const balData = await kisInstance.getBalance({
      accessToken: tokenData.accessToken, appKey, appSecret,
    });
    balance = balData.availableCash;
  } catch (_) { /* 잔고 조회 실패는 치명적이지 않음 */ }

  const encToken     = encrypt(tokenData.accessToken);
  const encAppKey    = encrypt(appKey);
  const encAppSecret = encrypt(appSecret);
  const now          = new Date().toISOString();

  // 기존 계좌 확인
  const { data: existing } = await db
    .from('broker_accounts')
    .select('id')
    .eq('user_id', userId)
    .eq('broker', broker)
    .eq('account_no', accountNo)
    .maybeSingle();

  if (existing) {
    await db.from('broker_accounts').update({
      encrypted_access_token:  encToken,
      encrypted_app_key:       encAppKey,
      encrypted_app_secret:    encAppSecret,
      token_expires_at:        tokenData.expiresAt,
      last_balance:            balance,
      last_balance_checked_at: now,
      is_active:               true,
      is_mock:                 isMock,
      updated_at:              now,
    }).eq('id', existing.id);

    audit.log({
      eventType: audit.AuditEvent.API_KEY_ROTATE,
      actorId: userId, ip,
      resource: 'broker_accounts', action: 'token_refresh',
      detail: { broker, isMock },
    });
    return existing.id;

  } else {
    const accountId = uuidv4();
    await db.from('broker_accounts').insert({
      id:                      accountId,
      user_id:                 userId,
      broker,
      account_no:              accountNo,
      is_mock:                 isMock,
      is_active:               true,
      encrypted_access_token:  encToken,
      encrypted_app_key:       encAppKey,
      encrypted_app_secret:    encAppSecret,
      token_expires_at:        tokenData.expiresAt,
      last_balance:            balance,
      last_balance_checked_at: now,
      connected_at:            now,
      updated_at:              now,
    });

    audit.log({
      eventType: audit.AuditEvent.API_KEY_REGISTER,
      actorId: userId, ip,
      resource: 'broker_accounts', action: 'connect',
      detail: { broker, isMock, accountNo },
      riskLevel: audit.RiskLevel.HIGH,
    });
    return accountId;
  }
}

// ── 인증정보 조회 (복호화 + 자동 토큰 갱신) ─────────────────
async function getBrokerCredentials(brokerAccountId) {
  const db = getDb();
  const { data: row } = await db
    .from('broker_accounts')
    .select(`id, broker, account_no, is_mock, is_active,
             encrypted_access_token, encrypted_app_key, encrypted_app_secret,
             token_expires_at`)
    .eq('id', brokerAccountId)
    .eq('is_active', true)
    .maybeSingle();

  if (!row) return null;

  const { accessToken, appKey, appSecret } = _decryptRow(row);
  if (!appKey || !appSecret) return null;

  if (!_isTokenValid(row.token_expires_at)) {
    try {
      const kisInstance = createBroker(row.broker, {
        accountNo: row.account_no, isMock: !!row.is_mock,
      });
      const newToken = await kisInstance.fetchToken({ appKey, appSecret });
      const encToken = encrypt(newToken.accessToken);
      const now = new Date().toISOString();

      await db.from('broker_accounts').update({
        encrypted_access_token: encToken,
        token_expires_at: newToken.expiresAt,
        updated_at: now,
      }).eq('id', brokerAccountId);

      return {
        accessToken: newToken.accessToken,
        appKey, appSecret,
        accountNo: row.account_no,
        broker:    row.broker,
        isMock:    !!row.is_mock,
      };
    } catch (err) {
      console.warn(`[BROKER] 토큰 자동 갱신 실패: ${err.message}`);
    }
  }

  return {
    accessToken, appKey, appSecret,
    accountNo: row.account_no,
    broker:    row.broker,
    isMock:    !!row.is_mock,
  };
}

// ── 연동 계좌 목록 ─────────────────────────────────────────
async function getBrokerAccounts(userId) {
  const db = getDb();
  const { data: rows, error } = await db
    .from('broker_accounts')
    .select(`id, broker, account_no, account_name, is_mock, is_active,
             last_balance, last_balance_checked_at, connected_at, token_expires_at`)
    .eq('user_id', userId)
    .order('connected_at', { ascending: false });

  if (error) throw new Error(error.message);
  return (rows || []).map(row => ({
    ...row,
    is_mock:      !!row.is_mock,
    is_active:    !!row.is_active,
    isTokenValid: _isTokenValid(row.token_expires_at),
  }));
}

// ── 계좌 비활성화 ─────────────────────────────────────────
async function deactivateBrokerAccount(brokerAccountId, userId) {
  const db = getDb();
  const { data: account } = await db
    .from('broker_accounts')
    .select('id')
    .eq('id', brokerAccountId)
    .eq('user_id', userId)
    .maybeSingle();

  if (!account) throw Object.assign(new Error('계좌를 찾을 수 없습니다'), { status: 404 });

  await db.from('broker_accounts')
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq('id', brokerAccountId);
}

module.exports = {
  connectBrokerAccount,
  getBrokerCredentials,
  getBrokerAccounts,
  deactivateBrokerAccount,
};
