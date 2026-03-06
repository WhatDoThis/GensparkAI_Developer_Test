/**
 * AutoTradeX Database Schema
 * PRD 8. Database 스키마 + 10-A 보안 (audit_logs 포함)
 */

const CREATE_TABLES = `
-- ── 사용자 테이블 ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,   -- argon2id (현재: bcrypt 대체)
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'OWNER',  -- OWNER | VIEWER | SYSTEM
  mfa_enabled INTEGER NOT NULL DEFAULT 0,
  mfa_secret TEXT,                     -- TOTP secret (암호화 저장)
  failed_login_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until TEXT,                   -- ISO8601, null = 잠금 없음
  last_login_at TEXT,
  last_login_ip TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── 세션 테이블 ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,            -- JWT jti 해시
  ip_address TEXT,
  user_agent TEXT,
  device_fingerprint TEXT,
  expires_at TEXT NOT NULL,
  revoked INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── API 키 저장소 (AES-256-GCM 암호화) ────────────────────
CREATE TABLE IF NOT EXISTS api_credentials (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  broker TEXT NOT NULL,                -- 'kiwoom' | 'kis'
  label TEXT,                          -- 사용자 표시용 레이블
  encrypted_app_key TEXT NOT NULL,     -- AES-256-GCM ciphertext
  encrypted_app_secret TEXT NOT NULL,
  account_no TEXT,
  is_mock INTEGER NOT NULL DEFAULT 1,  -- 1=모의투자, 0=실거래
  is_active INTEGER NOT NULL DEFAULT 1,
  last_rotated_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(user_id, broker, is_active)
);

-- ── 매매 내역 ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trades (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  broker TEXT NOT NULL,
  stock_code TEXT NOT NULL,
  stock_name TEXT,
  trade_type TEXT NOT NULL,            -- 'BUY' | 'SELL'
  quantity INTEGER NOT NULL,
  price REAL NOT NULL,
  total_amount REAL NOT NULL,
  profit_loss REAL,
  profit_loss_rate REAL,
  status TEXT NOT NULL DEFAULT 'PENDING',  -- PENDING|FILLED|CANCELLED|FAILED
  order_id TEXT,
  hmac_signature TEXT,                 -- 주문 무결성 HMAC-SHA256
  ai_confidence REAL,
  ai_reason TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  filled_at TEXT
);

-- ── 감사 로그 (PRD 10-A-7) ────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id TEXT PRIMARY KEY,
  timestamp TEXT NOT NULL DEFAULT (datetime('now')),
  event_type TEXT NOT NULL,
  actor_id TEXT,
  ip TEXT,
  device TEXT,
  resource TEXT,
  action TEXT,
  result TEXT NOT NULL DEFAULT 'SUCCESS',  -- SUCCESS | FAILURE | BLOCKED
  detail_json TEXT,                         -- JSON 문자열
  risk_level TEXT NOT NULL DEFAULT 'LOW'    -- LOW | MEDIUM | HIGH | CRITICAL
);

-- ── 일일 리포트 ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_reports (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  date TEXT NOT NULL,                  -- YYYY-MM-DD
  total_trades INTEGER NOT NULL DEFAULT 0,
  winning_trades INTEGER NOT NULL DEFAULT 0,
  total_profit_loss REAL NOT NULL DEFAULT 0,
  total_profit_loss_rate REAL NOT NULL DEFAULT 0,
  starting_balance REAL,
  ending_balance REAL,
  summary_json TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(user_id, date)
);

-- ── 관심종목 ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS watchlist (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  stock_code TEXT NOT NULL,
  stock_name TEXT,
  added_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(user_id, stock_code)
);

-- ── 증권사 계좌 연동 ──────────────────────────────────────
-- api_credentials와 별개: 계좌 자체의 연결 상태 및 액세스토큰 캐시
CREATE TABLE IF NOT EXISTS broker_accounts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  broker TEXT NOT NULL,                   -- 'kis' | 'kiwoom'
  account_no TEXT NOT NULL,               -- 계좌번호 (CANO 8자리 + ACNT_PRDT_CD 2자리)
  account_name TEXT,                      -- 계좌명 (예: 위탁종합계좌)
  is_mock INTEGER NOT NULL DEFAULT 1,     -- 1=모의투자, 0=실거래
  is_active INTEGER NOT NULL DEFAULT 1,
  -- APP Key / Secret (AES-256-GCM 암호화 저장, 각 계좌별 개별 키)
  encrypted_app_key TEXT,                 -- KIS appkey (암호화)
  encrypted_app_secret TEXT,             -- KIS appsecret (암호화)
  -- 액세스토큰 캐시 (24h 유효, 암호화 저장)
  encrypted_access_token TEXT,
  token_expires_at TEXT,
  -- 계좌 잔고 캐시 (마지막 조회값)
  last_balance REAL,
  last_balance_checked_at TEXT,
  connected_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(user_id, broker, account_no)
);

-- ── 거래 설정 ────────────────────────────────────────────
-- 사용자별 자동매매 설정값 (PRD 워크플로우 기반)
CREATE TABLE IF NOT EXISTS trading_settings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  broker_account_id TEXT REFERENCES broker_accounts(id),

  -- 자금 설정
  daily_budget REAL NOT NULL DEFAULT 0,         -- 일일 거래 예산 (원)
  loss_floor REAL NOT NULL DEFAULT 0,           -- 손실 마지노선 (원, daily_budget 미만)

  -- 시간 설정 (HH:MM 형식)
  trading_start_time TEXT NOT NULL DEFAULT '09:10',  -- 장시작 후 10분 후 최소
  trading_end_time TEXT NOT NULL DEFAULT '14:50',    -- 단일가 전 강제 종료
  term_seconds INTEGER NOT NULL DEFAULT 60,          -- 거래 간 최소 대기(초), 최소 1

  -- 거래 횟수 제한
  max_trades INTEGER NOT NULL DEFAULT 0,             -- 0=무제한
  max_consecutive_losses INTEGER NOT NULL DEFAULT 3, -- 연속 손실 허용 횟수

  -- AI 분석 소스 설정 (JSON 배열)
  ai_sources_json TEXT NOT NULL DEFAULT '["broker_api","krx"]',
  -- 예: ["broker_api", "krx", "naver_finance", "web_search"]

  -- AI 전략 파라미터
  min_confidence_score INTEGER NOT NULL DEFAULT 70,  -- AI 신뢰도 최소값 (0~100)
  target_profit_rate REAL NOT NULL DEFAULT 0.02,     -- 목표 수익률 (기본 2%)
  stop_loss_rate REAL NOT NULL DEFAULT 0.01,         -- 손절 기준 (기본 -1%)

  -- 상태
  status TEXT NOT NULL DEFAULT 'IDLE',
  -- IDLE: 미설정/초기화됨
  -- CONFIGURED: 설정완료/대기중
  -- RUNNING: 거래중
  -- PAUSED: 일시정지 (당일 마지노선 도달)
  -- STOPPED: 수동 중지

  -- 오늘의 진행 상황 (매일 리셋)
  today_date TEXT,                                   -- YYYY-MM-DD, 날짜 바뀌면 리셋
  today_used_budget REAL NOT NULL DEFAULT 0,         -- 오늘 사용된 예산
  today_trade_count INTEGER NOT NULL DEFAULT 0,      -- 오늘 거래 횟수
  today_consecutive_losses INTEGER NOT NULL DEFAULT 0,
  today_pnl REAL NOT NULL DEFAULT 0,                 -- 오늘 손익 합계

  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(user_id)  -- 사용자당 1개 설정
);

-- ── 거래 세션 로그 (일별 자동매매 실행 기록) ────────────────
CREATE TABLE IF NOT EXISTS trading_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  broker_account_id TEXT,
  date TEXT NOT NULL,                              -- YYYY-MM-DD
  status TEXT NOT NULL DEFAULT 'RUNNING',          -- RUNNING|COMPLETED|HALTED|ERROR
  halt_reason TEXT,                                -- 중단 이유
  started_at TEXT NOT NULL DEFAULT (datetime('now')),
  ended_at TEXT,
  initial_budget REAL NOT NULL,
  final_balance REAL,
  total_trades INTEGER NOT NULL DEFAULT 0,
  winning_trades INTEGER NOT NULL DEFAULT 0,
  total_pnl REAL NOT NULL DEFAULT 0,
  settings_snapshot TEXT                           -- 시작 시 설정값 JSON 스냅샷
);

-- ── 인덱스 ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_trades_user_id ON trades(user_id);
CREATE INDEX IF NOT EXISTS idx_trades_created_at ON trades(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_api_credentials_user_id ON api_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_broker_accounts_user_id ON broker_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_settings_user_id ON trading_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_sessions_user_date ON trading_sessions(user_id, date);
`;

module.exports = { CREATE_TABLES };
