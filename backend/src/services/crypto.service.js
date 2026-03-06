/**
 * AutoTradeX Crypto Service
 * PRD 10-A-3: AES-256-GCM API Key 암호화
 * PRD 10-A-2: bcrypt 비밀번호 해싱 (argon2id 준비)
 */

const crypto = require('crypto');
const bcrypt = require('bcryptjs');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;       // GCM 권장 96-bit
const SALT_LENGTH = 32;
const TAG_LENGTH = 16;
const KEY_LENGTH = 32;      // 256-bit

// 마스터 키: 시스템 시크릿 + 사용자 패스워드에서 scrypt 파생
function deriveKey(password, salt) {
  return crypto.scryptSync(
    password,
    salt,
    KEY_LENGTH,
    { N: 32768, r: 8, p: 1 }  // PRD 10-A-3 명세
  );
}

// 시스템 마스터 키 (환경변수에서 읽음)
function getSystemKey() {
  const secret = process.env.SYSTEM_ENCRYPTION_SECRET;
  if (!secret) throw new Error('SYSTEM_ENCRYPTION_SECRET not set');

  const salt = Buffer.from('ATX_SYSTEM_SALT_v1', 'utf8');
  return deriveKey(secret, salt);
}

/**
 * AES-256-GCM 암호화
 * @param {string} plaintext - 암호화할 문자열
 * @returns {string} "salt:iv:authTag:ciphertext" (모두 hex)
 */
function encrypt(plaintext) {
  const salt = crypto.randomBytes(SALT_LENGTH);
  const iv = crypto.randomBytes(IV_LENGTH);
  const key = getSystemKey();

  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([
    cipher.update(plaintext, 'utf8'),
    cipher.final()
  ]);
  const authTag = cipher.getAuthTag();

  return [
    salt.toString('hex'),
    iv.toString('hex'),
    authTag.toString('hex'),
    encrypted.toString('hex')
  ].join(':');
}

/**
 * AES-256-GCM 복호화
 * @param {string} ciphertext - encrypt() 결과
 * @returns {string} 복호화된 문자열
 */
function decrypt(ciphertext) {
  const [saltHex, ivHex, authTagHex, dataHex] = ciphertext.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const authTag = Buffer.from(authTagHex, 'hex');
  const data = Buffer.from(dataHex, 'hex');
  const key = getSystemKey();

  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
  decipher.setAuthTag(authTag);

  return Buffer.concat([
    decipher.update(data),
    decipher.final()
  ]).toString('utf8');
}

/**
 * HMAC-SHA256 서명 (주문 무결성 검증)
 */
function signHmac(data) {
  const secret = process.env.JWT_SECRET || process.env.SYSTEM_ENCRYPTION_SECRET;
  return crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(data))
    .digest('hex');
}

function verifyHmac(data, signature) {
  const expected = signHmac(data);
  return crypto.timingSafeEqual(
    Buffer.from(expected, 'hex'),
    Buffer.from(signature, 'hex')
  );
}

// ── 비밀번호 해싱 ──────────────────────────────────────────
const BCRYPT_ROUNDS = 12;
const PEPPER = process.env.PASSWORD_PEPPER || '';

async function hashPassword(password) {
  const peppered = password + PEPPER;
  return bcrypt.hash(peppered, BCRYPT_ROUNDS);
}

async function verifyPassword(password, hash) {
  const peppered = password + PEPPER;
  return bcrypt.compare(peppered, hash);
}

// ── 민감정보 마스킹 (PRD 10-A-6) ──────────────────────────
const SENSITIVE_FIELDS = ['apiKey', 'appKey', 'appSecret', 'accessToken',
  'password', 'token', 'secret', 'authorization'];

function maskSensitive(obj) {
  if (typeof obj === 'string') {
    // 긴 문자열: 앞 3자리 + *** + 뒤 3자리
    if (obj.length > 8) {
      return obj.slice(0, 3) + '***' + obj.slice(-3);
    }
    return '***';
  }
  if (typeof obj !== 'object' || obj === null) return obj;

  const masked = Array.isArray(obj) ? [] : {};
  for (const [k, v] of Object.entries(obj)) {
    const lk = k.toLowerCase();
    const isSensitive = SENSITIVE_FIELDS.some(f => lk.includes(f.toLowerCase()));
    masked[k] = isSensitive ? maskSensitive(v) : maskSensitive(v);
  }
  return masked;
}

module.exports = {
  encrypt, decrypt,
  signHmac, verifyHmac,
  hashPassword, verifyPassword,
  maskSensitive
};
