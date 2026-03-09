/**
 * AutoTradeX Database Connection
 * Supabase (PostgreSQL) 기반 싱글톤 클라이언트
 *
 * 사용법:
 *   const { getDb } = require('./connection');
 *   const db = getDb();
 *   const { data, error } = await db.from('users').select('*').eq('id', userId);
 */

const { createClient } = require('@supabase/supabase-js');

let client = null;

function getDb() {
  if (client) return client;

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
    || process.env.SUPABASE_ANON_KEY;

  if (!url || !key) {
    throw new Error('[DB] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 환경변수가 없습니다');
  }

  client = createClient(url, key, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  console.log(`[DB] Supabase connected: ${url}`);
  return client;
}

// 호환성 유지 (기존 코드가 closeDb 를 호출하는 경우 대비)
function closeDb() {
  client = null;
  console.log('[DB] Supabase client reset');
}

module.exports = { getDb, closeDb };
