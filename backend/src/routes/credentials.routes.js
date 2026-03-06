/**
 * AutoTradeX API Key Routes
 * PRD 10-A-3: API 키 등록/조회/삭제 (AES-256-GCM 암호화)
 */

const { Hono } = require('hono');
const { z } = require('zod');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../db/connection');
const { encrypt, decrypt, maskSensitive } = require('../services/crypto.service');
const { authMiddleware } = require('../middleware/auth.middleware');
const audit = require('../services/audit.service');

const router = new Hono();

const credentialSchema = z.object({
  broker: z.enum(['kiwoom', 'kis'], { message: '지원 브로커: kiwoom, kis' }),
  appKey: z.string().min(1, 'App Key를 입력하세요').max(256),
  appSecret: z.string().min(1, 'App Secret을 입력하세요').max(512),
  accountNo: z.string().max(50).optional(),
  label: z.string().max(100).optional(),
  isMock: z.boolean().default(true),
});

function getClientInfo(c) {
  return {
    ip: c.req.header('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown',
    userAgent: c.req.header('user-agent') || 'unknown',
  };
}

// ── POST /api/credentials - API 키 등록 ──────────────────
router.post('/', authMiddleware, async (c) => {
  try {
    const body = await c.req.json();
    const parsed = credentialSchema.safeParse(body);
    if (!parsed.success) {
      return c.json({
        error: '입력값 오류',
        details: parsed.error.errors.map(e => ({ field: e.path.join('.'), message: e.message }))
      }, 400);
    }

    const { broker, appKey, appSecret, accountNo, label, isMock } = parsed.data;
    const userId = c.get('user').sub;
    const db = getDb();
    const { ip } = getClientInfo(c);

    // 기존 키 비활성화
    db.prepare(`
      UPDATE api_credentials SET is_active = 0
      WHERE user_id = ? AND broker = ? AND is_active = 1
    `).run(userId, broker);

    // 암호화 저장
    const encryptedKey = encrypt(appKey);
    const encryptedSecret = encrypt(appSecret);
    const credId = uuidv4();

    db.prepare(`
      INSERT INTO api_credentials
        (id, user_id, broker, label, encrypted_app_key, encrypted_app_secret, account_no, is_mock)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).run(credId, userId, broker, label || broker, encryptedKey, encryptedSecret, accountNo, isMock ? 1 : 0);

    audit.log({
      eventType: audit.AuditEvent.API_KEY_REGISTER,
      actorId: userId, ip,
      resource: 'api_credentials',
      action: 'register',
      detail: { broker, isMock, accountNo },
      riskLevel: audit.RiskLevel.HIGH
    });

    return c.json({
      message: 'API 키가 등록되었습니다',
      credentialId: credId,
      broker,
      isMock
    }, 201);
  } catch (err) {
    return c.json({ error: err.message }, err.status || 500);
  }
});

// ── GET /api/credentials - 등록된 키 목록 ────────────────
router.get('/', authMiddleware, (c) => {
  const userId = c.get('user').sub;
  const db = getDb();

  const creds = db.prepare(`
    SELECT id, broker, label, account_no, is_mock, is_active, created_at, last_rotated_at
    FROM api_credentials WHERE user_id = ? ORDER BY created_at DESC
  `).all(userId);

  audit.log({
    eventType: audit.AuditEvent.API_KEY_ACCESS,
    actorId: userId,
    ip: c.req.header('x-forwarded-for') || 'unknown',
    resource: 'api_credentials',
    action: 'list'
  });

  // 키 값은 마스킹하여 반환 (원본 노출 안 함)
  return c.json({
    credentials: creds.map(c => ({
      ...c,
      is_mock: !!c.is_mock,
      is_active: !!c.is_active,
    }))
  });
});

// ── DELETE /api/credentials/:id - API 키 삭제 ────────────
router.delete('/:id', authMiddleware, (c) => {
  const userId = c.get('user').sub;
  const credId = c.req.param('id');
  const db = getDb();

  const cred = db.prepare(
    'SELECT * FROM api_credentials WHERE id = ? AND user_id = ?'
  ).get(credId, userId);

  if (!cred) return c.json({ error: '자격증명을 찾을 수 없습니다' }, 404);

  db.prepare('DELETE FROM api_credentials WHERE id = ?').run(credId);

  audit.log({
    eventType: audit.AuditEvent.API_KEY_DELETE,
    actorId: userId,
    ip: c.req.header('x-forwarded-for') || 'unknown',
    resource: 'api_credentials',
    action: 'delete',
    detail: { broker: cred.broker },
    riskLevel: audit.RiskLevel.HIGH
  });

  return c.json({ message: 'API 키가 삭제되었습니다' });
});

module.exports = router;
