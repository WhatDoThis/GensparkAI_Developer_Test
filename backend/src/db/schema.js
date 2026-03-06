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

-- ── 인덱스 ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_trades_user_id ON trades(user_id);
CREATE INDEX IF NOT EXISTS idx_trades_created_at ON trades(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_api_credentials_user_id ON api_credentials(user_id);
`;

module.exports = { CREATE_TABLES };
