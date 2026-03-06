/**
 * AutoTradeX Database Connection
 * better-sqlite3 기반 싱글톤 연결
 */

const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');
const { CREATE_TABLES } = require('./schema');

let db = null;

function getDb() {
  if (db) return db;

  const dbPath = process.env.DATABASE_PATH || './data/autotradex.db';
  const absolutePath = path.resolve(dbPath);

  // 디렉토리 없으면 생성
  const dir = path.dirname(absolutePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  db = new Database(absolutePath);

  // 성능 최적화
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.pragma('synchronous = NORMAL');

  // 테이블 생성
  db.exec(CREATE_TABLES);

  console.log(`[DB] SQLite connected: ${absolutePath}`);
  return db;
}

function closeDb() {
  if (db) {
    db.close();
    db = null;
    console.log('[DB] Connection closed');
  }
}

module.exports = { getDb, closeDb };
