-- ============================================================
-- AutoTradeX Supabase Migration
-- Supabase SQL Editor에서 이 파일 전체를 붙여넣고 실행하세요
-- https://supabase.com/dashboard/project/fphjwmwvdcdhnujamkqr/sql/new
-- ============================================================

-- ── 사용자 테이블 ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  name          TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'OWNER',
  mfa_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
  mfa_secret    TEXT,
  failed_login_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until  TIMESTAMPTZ,
  last_login_at TIMESTAMPTZ,
  last_login_ip TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 세션 테이블 ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
  id                  TEXT PRIMARY KEY,
  user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash          TEXT NOT NULL,
  ip_address          TEXT,
  user_agent          TEXT,
  device_fingerprint  TEXT,
  expires_at          TIMESTAMPTZ NOT NULL,
  revoked             BOOLEAN NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── API 키 저장소 (AES-256-GCM 암호화) ────────────────────
CREATE TABLE IF NOT EXISTS api_credentials (
  id                    TEXT PRIMARY KEY,
  user_id               TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  broker                TEXT NOT NULL,
  label                 TEXT,
  encrypted_app_key     TEXT NOT NULL,
  encrypted_app_secret  TEXT NOT NULL,
  account_no            TEXT,
  is_mock               BOOLEAN NOT NULL DEFAULT TRUE,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  last_rotated_at       TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, broker, is_active)
);

-- ── 매매 내역 ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trades (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id),
  broker            TEXT NOT NULL,
  stock_code        TEXT NOT NULL,
  stock_name        TEXT,
  trade_type        TEXT NOT NULL,
  quantity          INTEGER NOT NULL,
  price             NUMERIC NOT NULL,
  total_amount      NUMERIC NOT NULL,
  profit_loss       NUMERIC,
  profit_loss_rate  NUMERIC,
  status            TEXT NOT NULL DEFAULT 'PENDING',
  order_id          TEXT,
  hmac_signature    TEXT,
  ai_confidence     NUMERIC,
  ai_reason         TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  filled_at         TIMESTAMPTZ
);

-- ── 감사 로그 ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_logs (
  id          TEXT PRIMARY KEY,
  timestamp   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  event_type  TEXT NOT NULL,
  actor_id    TEXT,
  ip          TEXT,
  device      TEXT,
  resource    TEXT,
  action      TEXT,
  result      TEXT NOT NULL DEFAULT 'SUCCESS',
  detail_json JSONB,
  risk_level  TEXT NOT NULL DEFAULT 'LOW'
);

-- ── 일일 리포트 ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS daily_reports (
  id                      TEXT PRIMARY KEY,
  user_id                 TEXT NOT NULL REFERENCES users(id),
  date                    DATE NOT NULL,
  total_trades            INTEGER NOT NULL DEFAULT 0,
  winning_trades          INTEGER NOT NULL DEFAULT 0,
  total_profit_loss       NUMERIC NOT NULL DEFAULT 0,
  total_profit_loss_rate  NUMERIC NOT NULL DEFAULT 0,
  starting_balance        NUMERIC,
  ending_balance          NUMERIC,
  summary_json            JSONB,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, date)
);

-- ── 관심종목 ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS watchlist (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id),
  stock_code  TEXT NOT NULL,
  stock_name  TEXT,
  added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, stock_code)
);

-- ── 증권사 계좌 연동 ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS broker_accounts (
  id                      TEXT PRIMARY KEY,
  user_id                 TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  broker                  TEXT NOT NULL,
  account_no              TEXT NOT NULL,
  account_name            TEXT,
  is_mock                 BOOLEAN NOT NULL DEFAULT TRUE,
  is_active               BOOLEAN NOT NULL DEFAULT TRUE,
  encrypted_app_key       TEXT,
  encrypted_app_secret    TEXT,
  encrypted_access_token  TEXT,
  token_expires_at        TIMESTAMPTZ,
  last_balance            NUMERIC,
  last_balance_checked_at TIMESTAMPTZ,
  connected_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, broker, account_no)
);

-- ── 거래 설정 ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trading_settings (
  id                      TEXT PRIMARY KEY,
  user_id                 TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  broker_account_id       TEXT REFERENCES broker_accounts(id),
  daily_budget            NUMERIC NOT NULL DEFAULT 0,
  loss_floor              NUMERIC NOT NULL DEFAULT 0,
  trading_start_time      TEXT NOT NULL DEFAULT '09:10',
  trading_end_time        TEXT NOT NULL DEFAULT '14:50',
  term_seconds            INTEGER NOT NULL DEFAULT 60,
  max_trades              INTEGER NOT NULL DEFAULT 0,
  max_consecutive_losses  INTEGER NOT NULL DEFAULT 3,
  ai_sources_json         TEXT NOT NULL DEFAULT '["broker_api","krx"]',
  min_confidence_score    INTEGER NOT NULL DEFAULT 70,
  target_profit_rate      NUMERIC NOT NULL DEFAULT 0.02,
  stop_loss_rate          NUMERIC NOT NULL DEFAULT 0.01,
  status                  TEXT NOT NULL DEFAULT 'IDLE',
  today_date              DATE,
  today_used_budget       NUMERIC NOT NULL DEFAULT 0,
  today_trade_count       INTEGER NOT NULL DEFAULT 0,
  today_consecutive_losses INTEGER NOT NULL DEFAULT 0,
  today_pnl               NUMERIC NOT NULL DEFAULT 0,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id)
);

-- ── 거래 세션 로그 ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trading_sessions (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL REFERENCES users(id),
  broker_account_id TEXT,
  date              DATE NOT NULL,
  status            TEXT NOT NULL DEFAULT 'RUNNING',
  halt_reason       TEXT,
  started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at          TIMESTAMPTZ,
  initial_budget    NUMERIC NOT NULL,
  final_balance     NUMERIC,
  total_trades      INTEGER NOT NULL DEFAULT 0,
  winning_trades    INTEGER NOT NULL DEFAULT 0,
  total_pnl         NUMERIC NOT NULL DEFAULT 0,
  settings_snapshot JSONB
);

-- ── 인덱스 ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sessions_user_id        ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash     ON sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_trades_user_id          ON trades(user_id);
CREATE INDEX IF NOT EXISTS idx_trades_created_at       ON trades(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp    ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id     ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type   ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_broker_accounts_user_id ON broker_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_settings_user   ON trading_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_trading_sessions_user   ON trading_sessions(user_id, date);

-- ── Row Level Security (RLS) ────────────────────────────────
-- Service Role Key로 접근하므로 RLS 비활성화 (백엔드 전용 테이블)
ALTER TABLE users             DISABLE ROW LEVEL SECURITY;
ALTER TABLE sessions          DISABLE ROW LEVEL SECURITY;
ALTER TABLE api_credentials   DISABLE ROW LEVEL SECURITY;
ALTER TABLE trades            DISABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs        DISABLE ROW LEVEL SECURITY;
ALTER TABLE daily_reports     DISABLE ROW LEVEL SECURITY;
ALTER TABLE watchlist         DISABLE ROW LEVEL SECURITY;
ALTER TABLE broker_accounts   DISABLE ROW LEVEL SECURITY;
ALTER TABLE trading_settings  DISABLE ROW LEVEL SECURITY;
ALTER TABLE trading_sessions  DISABLE ROW LEVEL SECURITY;

-- ── 기존 사용자 데이터 삽입 (SQLite에서 마이그레이션) ──────
-- 아래 INSERT는 기존 관리자 계정을 유지합니다
-- password: q1w2e3r4!! (bcrypt hash)
INSERT INTO users (id, email, password_hash, name, role, mfa_enabled, failed_login_attempts, created_at, updated_at)
VALUES (
  'b1e04388-59a5-4064-8a22-e9e7373e6c20',
  'whi21@naver.com',
  '$2b$12$hqIlyiBdyXLk3CbuVc4ZFe28FDlu5WKBgYWUcvwoUYHqqm4gpvE8a',
  '관리자',
  'OWNER',
  FALSE,
  0,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 완료! 이제 백엔드 서버를 재시작하세요.
-- ============================================================
