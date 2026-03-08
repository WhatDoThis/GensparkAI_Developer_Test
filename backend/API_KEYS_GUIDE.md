# AutoTradeX API 키 획득 가이드

> 이 가이드는 `.env` 파일에 필요한 실제 값들을 어디서 어떻게 얻는지 설명합니다.

---

## 1. 자동 생성 값 (이미 생성됨)

`.env` 파일에 이미 설정된 항목:
```
JWT_SECRET=...           # npm start 시 자동 생성
SYSTEM_ENCRYPTION_SECRET # ENCRYPTION_SECRET과 동일값
PASSWORD_PEPPER=...      # 자동 생성
```
→ **별도 설정 불필요** (`.env` 파일에 이미 있음)

---

## 2. 키움증권 OpenAPI 키 (KIWOOM_APP_KEY, KIWOOM_APP_SECRET)

### 획득 방법
1. **키움증권 OpenAPI 신청**: https://openapi.kiwoom.com
   - 키움증권 계좌 없으면 먼저 계좌 개설 필요
2. **로그인 후** 상단 메뉴: "OpenAPI" → "신청/해지"
3. **실거래/모의투자 선택**:
   - 처음이라면 **모의투자(VTS)** 먼저 신청 권장 (`.env`의 `KIWOOM_IS_MOCK=true` 상태 유지)
   - 실거래는 `KIWOOM_IS_MOCK=false`로 변경
4. **App Key / App Secret 발급**:
   - "API 관리" → "앱 등록" → 발급된 Key/Secret 복사

### .env 설정
```
KIWOOM_APP_KEY=발급받은_앱키_붙여넣기
KIWOOM_APP_SECRET=발급받은_앱시크릿_붙여넣기
KIWOOM_ACCOUNT_NO=계좌번호_8자리
KIWOOM_IS_MOCK=true   # 모의투자: true, 실거래: false
```

### 참고
- 키움 REST API는 2025년부터 Mac/Linux 지원 (기존 HTS는 Windows 전용)
- API 문서: https://openapi.kiwoom.com/guide/start

---

## 3. 한국투자증권 KIS API 키 (KIS_APP_KEY, KIS_APP_SECRET)

### 획득 방법
1. **KIS Developers 신청**: https://apiportal.koreainvestment.com
   - 한국투자증권 계좌 필요
2. **회원가입 후** "앱 신청" → "실전투자" 또는 "모의투자" 선택
3. **앱 등록** → App Key / App Secret 즉시 발급 (자동)

### .env 설정
```
KIS_APP_KEY=발급받은_앱키
KIS_APP_SECRET=발급받은_앱시크릿
KIS_ACCOUNT_NO=계좌번호
KIS_IS_MOCK=true   # 모의투자: true, 실거래: false
```

### 참고
- API 문서: https://apiportal.koreainvestment.com/apiservice/apiServiceMain
- 모의투자 URL: `https://openapivts.koreainvestment.com:29443`

---

## 4. AI 모델 (현재 목업, 추후 Genspark API)

현재 `AI_PROVIDER=mock`으로 설정되어 있습니다.
실제 AI 연동 시:
```
GENSPARK_API_KEY=젠스파크에서_발급받은_키
AI_PROVIDER=genspark
AI_MODEL=claude-sonnet-4
```

---

## 5. DATABASE_URL (PostgreSQL / Supabase - 프로덕션)

개발 환경은 SQLite 사용 중 (`DATABASE_PATH=./data/autotradex.db`)

프로덕션으로 전환 시 PostgreSQL 사용:
```
DATABASE_URL=postgresql://user:password@localhost:5432/autotradex
```
- 로컬 설치: `sudo apt install postgresql`
- 클라우드: Supabase (무료), Railway, Neon.tech 권장

---

## 7. 보안 주의사항

```bash
# .env 파일은 절대 Git에 커밋하지 마세요!
echo ".env" >> .gitignore

# .env.example 파일은 실제 값 없이 구조만 공유
git add .env.example
git commit -m "Add environment variable template"
```

---

## 8. 개발 단계별 최소 필요 설정

### 1단계: 회원가입/로그인만 테스트
→ **추가 설정 불필요** (JWT_SECRET, DB 이미 설정됨)

### 2단계: 브로커 API 연동
→ **KIWOOM 또는 KIS 모의투자 키** 필요

### 3단계: AI 종목 선정
→ **GENSPARK_API_KEY** 또는 목업 유지

