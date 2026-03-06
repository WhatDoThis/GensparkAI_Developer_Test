이제 충분한 정보를 확보했습니다. 젠스파크 AI Developer의 특성(GitHub 연동, Full-Stack 빌드, Hono/Cloudflare 배포)과 한국 증권사 API 생태계(키움 REST API, 한국투자증권 KIS API 등)를 종합해서 PRD 문서를 작성하겠습니다.

아래에 완성된 PRD markdown 문서를 드립니다. 이걸 그대로 젠스파크 AI Developer에 입력하면 전체 개발 계획을 세워서 진행할 수 있도록 설계했어요.

---

```markdown
# PRD: AutoTradeX — AI 기반 자동 주식 거래 앱

> **문서 버전**: v1.0  
> **작성일**: 2026-03-06  
> **목적**: 젠스파크(Genspark) AI Developer에 입력하여 전체 개발을 한 번에 계획·실행하기 위한 Product Requirements Document

---

## 0. 젠스파크 AI Developer 활용 가이드

### 0-1. 프로젝트 시작 방법

1. **Genspark 접속**: https://www.genspark.ai → 좌측 사이드바에서 **AI Developer** 클릭
2. **프로젝트 타입 선택**: `Full-Stack Website or App` 선택 (인증, 계정관리, 백엔드, DB 포함 production-ready 스택)
3. **이 PRD 전체를 프롬프트에 붙여넣기**: AI Developer가 자동으로 요구사항을 분석하고, 태스크를 분할하여 순차적으로 개발 진행
4. **GitHub 연동 (권장)**: Settings에서 GitHub repository를 연결하면 코드를 직접 commit/PR 가능

### 0-2. 젠스파크 AI Developer 프로젝트 구성

- **프레임워크**: Hono (Node.js) 백엔드 + React/Next.js 프론트엔드
- **배포**: Cloudflare Pages (기본) 또는 GitHub → 자체 서버 SSH 배포
- **AI 모델**: Claude Sonnet 4 / Opus 4.1 / GPT-5 등 (젠스파크 내장 모델 활용)

### 0-3. 개발 진행 순서 (젠스파크에게 단계별 지시)

이 PRD를 입력한 후, 아래 순서로 단계별 프롬프트를 추가 입력하여 진행:

```
Phase 1: "PRD 기반으로 프로젝트 구조와 DB 스키마를 설계해줘"
Phase 2: "증권사 API 연동 모듈을 구현해줘 (키움 REST API 우선)"
Phase 3: "기술적 분석 엔진(RSI, MACD, 볼린저밴드 등)을 구현해줘"
Phase 4: "AI 기반 종목 선정 및 스코어링 시스템을 구현해줘"
Phase 5: "매매 실행 엔진(매수/매도/손절 로직)을 구현해줘"
Phase 6: "대시보드 UI와 실시간 모니터링 화면을 만들어줘"
Phase 7: "백테스팅 모듈과 시뮬레이션 기능을 추가해줘"
Phase 8: "전체 통합 테스트 및 배포 설정을 해줘"
```

---

## 1. 제품 개요

### 1-1. 앱 이름
**AutoTradeX** (자동 주식 거래 앱)

### 1-2. 한 줄 요약
한국 증권사 계좌를 연동하여 AI가 매일 주도 테마의 핵심 종목 5개를 선정하고, 기술적 지표 분석을 통해 최적 시점에 매수/매도를 자동 수행하여 일일 목표 수익률 5% 이상을 달성하는 자동 거래 시스템.

### 1-3. 핵심 목표

| 항목 | 목표값 | 비고 |
|------|--------|------|
| 일일 목표 수익률 | ≥ 5% | 초과 시 가산점 |
| 일일 거래 횟수 | 1 ~ 100회 | 무리한 거래 금지, 기다림 가능 |
| 종목당 수익률 목표 | 2% ~ 25% 구간 내 극대화 | 수익률 극대화 시점에 매도 |
| 손절 기준 | -3% 이하 | 즉시 손절 후 대체 종목 탐색 |
| 후보 종목 수 | 매일 최대 5개 선정 | 적절한 종목 없으면 0개도 허용 |

### 1-4. 핵심 원칙

1. **억지 매매 금지**: 적절한 종목이 없거나 타이밍이 아니면 기다린다
2. **리스크 우선**: 손절은 즉시, 수익은 극대화 시점까지 보유
3. **AI 판단 기반**: 모든 매매 의사결정에 AI 분석 결과 반영
4. **점수 시스템**: 수익 거래 = 가산점, 손절 거래 = 감점, 최종 점수 극대화

---

## 2. 시스템 아키텍처

### 2-1. 전체 구조

```
┌─────────────────────────────────────────────────────┐
│                    Frontend (Dashboard)               │
│         React/Next.js + TailwindCSS + Chart.js        │
└──────────────────────┬──────────────────────────────┘
                       │ REST API / WebSocket
┌──────────────────────▼──────────────────────────────┐
│                    Backend (Hono / Node.js)            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │ 종목선정  │ │ 분석엔진  │ │ 매매엔진  │ │ 스코어링 │ │
│  │ 모듈     │ │ 모듈     │ │ 모듈     │ │ 모듈    │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬────┘ │
│       │            │            │             │      │
│  ┌────▼────────────▼────────────▼─────────────▼────┐ │
│  │              AI Decision Engine                   │ │
│  │        (Genspark AI API / LLM 연동)               │ │
│  └──────────────────┬───────────────────────────────┘ │
└─────────────────────┼───────────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ 증권사API │  │ 시세 API  │  │ Database │
│ (키움/KIS)│  │ (실시간)  │  │ (SQLite/ │
│           │  │           │  │ Postgres)│
└──────────┘  └──────────┘  └──────────┘
```

### 2-2. 기술 스택

| 레이어 | 기술 | 선정 이유 |
|--------|------|-----------|
| Frontend | Next.js 14+ / React 18+ / TailwindCSS | Genspark 기본 지원, 빠른 UI 구현 |
| Backend | Hono (Node.js) | Genspark Full-Stack 기본 프레임워크, 경량·고속 |
| Database | SQLite (개발) / PostgreSQL (운영) | 거래 이력, 종목 데이터, 스코어 저장 |
| 차트 | Chart.js / Lightweight Charts (TradingView) | 캔들차트, 지표 시각화 |
| AI 엔진 | Genspark AI API (내장 LLM) | 종목 분석·의사결정 지원 |
| 증권사 API | 키움 REST API (1순위) / KIS Developers (2순위) | 자동매매 주문·시세 조회 |
| 스케줄러 | node-cron / Bull Queue | 정기 분석·매매 사이클 관리 |
| 배포 | Cloudflare Pages + Workers | Genspark 기본 배포 타겟 |

---

## 3. 증권사 API 연동 상세

### 3-1. 지원 증권사 (우선순위)

#### 1순위: 키움증권 REST API
- **API 포털**: https://openapi.kiwoom.com
- **특징**: Windows 제약 없음, Python/Node.js 등 다양한 언어 지원, REST 방식
- **필요 기능**: 로그인/토큰 발급, 주문(매수/매도/정정/취소), 잔고 조회, 실시간 시세(WebSocket), 종목 정보
- **주의사항**:
  - TLS 1.2 이상 필수
  - NXT(넥스트레이드) 거래가능종목이 분기별로 변경됨 → 종목 유니버스 자동 갱신 필요
  - API 호출 횟수 제한(Rate Limit) 존재 → 요청 큐잉 필요

#### 2순위: 한국투자증권 KIS Developers
- **API 포털**: https://apiportal.koreainvestment.com
- **특징**: REST + WebSocket 모두 지원, 문서화 우수
- **주의사항**:
  - WebSocket 무한루프 자동 차단 정책 → heartbeat/reconnect/backoff 필수
  - 잔고조회 필드값 입력 제한 → 파라미터 사전 검증

### 3-2. 연동 모듈 구조

```typescript
// broker-adapter.ts — 증권사 추상화 인터페이스

interface BrokerAdapter {
  // 인증
  authenticate(): Promise<AuthToken>;
  refreshToken(token: AuthToken): Promise<AuthToken>;
  
  // 계좌
  getBalance(): Promise<AccountBalance>;
  getPositions(): Promise<Position[]>;
  
  // 시세
  getQuote(stockCode: string): Promise<Quote>;
  getCandles(stockCode: string, interval: CandleInterval): Promise<Candle[]>;
  subscribeRealtime(stockCodes: string[], callback: RealtimeCallback): void;
  
  // 주문
  buyMarket(stockCode: string, quantity: number): Promise<OrderResult>;
  buyLimit(stockCode: string, quantity: number, price: number): Promise<OrderResult>;
  sellMarket(stockCode: string, quantity: number): Promise<OrderResult>;
  sellLimit(stockCode: string, quantity: number, price: number): Promise<OrderResult>;
  cancelOrder(orderId: string): Promise<OrderResult>;
  
  // 종목 정보
  getStockInfo(stockCode: string): Promise<StockInfo>;
  getMarketThemes(): Promise<Theme[]>;
}

// 키움 구현체
class KiwoomAdapter implements BrokerAdapter { ... }

// 한투 구현체  
class KISAdapter implements BrokerAdapter { ... }
```

### 3-3. 키움 REST API 인증 플로우

```
1. API Key 발급 (openapi.kiwoom.com → 마이페이지 → API 관리)
2. 앱 등록 후 App Key + App Secret 수령
3. 토큰 발급 요청:
   POST https://openapi.kiwoom.com/oauth2/token
   Body: { grant_type, appkey, appsecret }
4. Access Token 수신 (유효기간 24시간)
5. 모든 API 호출 헤더에 Authorization: Bearer {token} 포함
6. 토큰 만료 전 자동 갱신 로직 구현
```

---

## 4. AI 기반 종목 선정 시스템

### 4-1. 종목 선정 파이프라인

```
[시장 오픈 전 08:30]
    │
    ▼
Step 1: 테마 스캔 ─────────────────────────────────────
  - 전일 거래량 급등 섹터/테마 탐지
  - 뉴스/공시 기반 이슈 테마 수집
  - AI에게 "오늘 주도할 테마 Top 3" 판단 요청
    │
    ▼
Step 2: 후보 종목 풀 생성 ─────────────────────────────
  - 주도 테마 내 시가총액 상위 20개 종목 추출
  - 전일 거래량 상위 필터링
  - 신용잔고율, 대차잔고 등 수급 지표 확인
    │
    ▼
Step 3: 기술적 분석 스코어링 ───────────────────────────
  - 각 후보 종목에 대해 기술적 지표 계산 (상세: 4-2절)
  - 종합 스코어 산출
    │
    ▼
Step 4: AI 최종 판단 ──────────────────────────────────
  - 상위 스코어 종목 10개를 AI에게 전달
  - AI가 차트 패턴, 수급, 뉴스 종합하여 최종 5개 선정
  - "매수 적절" / "관망" / "위험" 등급 부여
    │
    ▼
Step 5: 워치리스트 확정 ───────────────────────────────
  - 최종 5개 종목 (또는 적절한 종목 없으면 0~4개)
  - 각 종목별 목표가, 손절가, 진입 시점 조건 설정
```

### 4-2. 기술적 분석 지표

각 종목에 대해 아래 지표를 계산하고 종합 스코어를 산출:

| 지표 | 계산 방법 | 매수 시그널 조건 | 가중치 |
|------|-----------|-----------------|--------|
| RSI (14) | 14일 상대강도지수 | 30~45 구간 진입 (과매도 탈출) | 20% |
| MACD | 12-26 EMA 차이 / Signal 9 | MACD가 Signal을 상향 돌파 | 20% |
| 볼린저밴드 | 20일 이동평균 ± 2σ | 하단밴드 터치 후 반등 | 15% |
| 거래량 | 5일 평균 대비 비율 | 평균 대비 200% 이상 급증 | 15% |
| 이동평균선 | 5/20/60일 MA | 5MA > 20MA 골든크로스 | 15% |
| 스토캐스틱 | %K, %D (14,3,3) | %K가 %D를 20 이하에서 상향돌파 | 10% |
| 캔들 패턴 | 망치형, 장악형 등 | 반전 패턴 출현 | 5% |

### 4-3. 종합 스코어 계산

```typescript
interface StockScore {
  stockCode: string;
  stockName: string;
  themeRelevance: number;    // 0~100: 테마 관련성
  technicalScore: number;    // 0~100: 기술적 지표 종합
  volumeScore: number;       // 0~100: 거래량 점수
  aiConfidence: number;      // 0~100: AI 판단 신뢰도
  totalScore: number;        // 가중 합산 (0~100)
  recommendation: 'BUY' | 'WATCH' | 'AVOID';
  targetPrice: number;       // 목표가
  stopLossPrice: number;     // 손절가
  entryCondition: string;    // 진입 조건 설명
}

// 종합 점수 계산
totalScore = (themeRelevance * 0.25) 
           + (technicalScore * 0.35) 
           + (volumeScore * 0.20) 
           + (aiConfidence * 0.20);

// 70점 이상만 BUY 추천, 50~69 WATCH, 49 이하 AVOID
```

---

## 5. AI Decision Engine (Genspark AI API 활용)

### 5-1. Genspark AI API 연동 방법

젠스파크의 AI Developer 환경에서는 내장 LLM 모델을 직접 호출할 수 있다. 백엔드에서 AI 판단 로직을 구현할 때, 아래 패턴으로 활용:

```typescript
// ai-decision-engine.ts

import { GensparkAI } from './genspark-client';

const ai = new GensparkAI({
  // Genspark 환경 내에서는 별도 API 키 불필요 (내장)
  // 외부 배포 시: 환경변수로 API Key 관리
  apiKey: process.env.GENSPARK_API_KEY || 'built-in',
  model: 'claude-sonnet-4'  // 또는 gpt-5, opus-4.1
});

// 종목 분석 요청
async function analyzeStocks(candidates: StockCandidate[]): Promise<AIAnalysis> {
  const prompt = `
    당신은 한국 주식시장 전문 트레이더입니다.
    아래 후보 종목들의 데이터를 분석하여 오늘 거래에 최적인 종목 최대 5개를 선정해주세요.
    
    ## 선정 기준
    - 일일 2~25% 수익이 가능한 단기 모멘텀 종목
    - 손절 리스크(-3%)가 낮은 종목 우선
    - 거래량이 충분하여 매수/매도가 원활한 종목
    - 적절한 종목이 없으면 "오늘은 관망"이라고 답변
    
    ## 후보 종목 데이터
    ${JSON.stringify(candidates, null, 2)}
    
    ## 응답 형식 (JSON)
    {
      "selectedStocks": [
        {
          "stockCode": "종목코드",
          "reason": "선정 이유",
          "entryPrice": 매수희망가,
          "targetPrice": 목표가,
          "stopLoss": 손절가,
          "confidence": 0~100,
          "strategy": "구체적 매매 전략"
        }
      ],
      "marketSentiment": "오늘 시장 전체 분위기 평가",
      "recommendation": "적극매매 | 보수적매매 | 관망"
    }
  `;
  
  const response = await ai.chat(prompt);
  return JSON.parse(response);
}

// 매매 타이밍 판단
async function shouldTrade(
  stock: StockScore, 
  currentPrice: number, 
  realtimeData: RealtimeData
): Promise<TradeDecision> {
  const prompt = `
    현재 ${stock.stockName}(${stock.stockCode})의 실시간 데이터:
    - 현재가: ${currentPrice}원
    - 호가 스프레드: ${realtimeData.spread}
    - 체결강도: ${realtimeData.tradingStrength}
    - 실시간 RSI: ${realtimeData.rsi}
    - 틱 차트 최근 30개: ${JSON.stringify(realtimeData.recentTicks)}
    
    목표 매수가: ${stock.targetPrice}원
    손절가: ${stock.stopLossPrice}원
    
    지금 매수해야 하나요? 
    응답: { "action": "BUY|WAIT|SKIP", "reason": "이유", "urgency": 0~100 }
  `;
  
  const response = await ai.chat(prompt);
  return JSON.parse(response);
}
```

### 5-2. AI 판단을 위한 보조 데이터 수집

```typescript
// data-collector.ts

interface MarketContext {
  // 테마/섹터 데이터
  hotThemes: Theme[];              // 오늘의 주도 테마
  sectorPerformance: SectorData[];  // 섹터별 등락률
  
  // 시장 전체 지표
  kospiIndex: number;
  kosdaqIndex: number;
  foreignNetBuy: number;            // 외국인 순매수
  institutionNetBuy: number;        // 기관 순매수
  
  // 뉴스/이슈
  topNews: NewsItem[];              // 주요 뉴스 헤드라인
  disclosures: Disclosure[];        // 당일 공시
  
  // 수급 데이터
  programTrading: ProgramData;      // 프로그램 매매 동향
  shortSelling: ShortData;          // 공매도 현황
}
```

---

## 6. 매매 실행 엔진

### 6-1. 매매 사이클 (Trading Cycle)

```
[장 시작 09:00]
    │
    ├─ 09:00~09:10: 시초가 형성 관찰 (매매 금지 구간)
    │
    ├─ 09:10~: 매수 타이밍 탐색 시작
    │    │
    │    ├─ 조건 충족 → 매수 실행
    │    │    │
    │    │    ├─ 보유 중 모니터링
    │    │    │    ├─ 수익률 +2~25% → 매도 타이밍 판단
    │    │    │    │    ├─ 수익 극대화 시점 도달 → 매도
    │    │    │    │    └─ 수익 감소 추세 → 즉시 매도
    │    │    │    │
    │    │    │    └─ 손실률 -3% 이하 → 즉시 손절
    │    │    │         └─ 대체 종목 탐색 → 재매수 사이클
    │    │    │
    │    │    └─ 매도 완료 → 스코어 기록 → 다음 사이클
    │    │
    │    └─ 조건 미충족 → 대기 (강제 매수 금지)
    │
    ├─ 14:30~15:00: 보유 종목 정리 (당일 매매 원칙)
    │
    └─ 15:30: 장 마감 → 일일 리포트 생성
```

### 6-2. 매수 로직

```typescript
// buy-engine.ts

interface BuyConfig {
  maxPositionRatio: number;     // 계좌 대비 최대 종목별 비중 (기본: 30%)
  maxConcurrentPositions: number; // 최대 동시 보유 종목 수 (기본: 3)
  minCashReserve: number;       // 최소 현금 보유 비율 (기본: 20%)
  cooldownAfterLoss: number;    // 손절 후 대기 시간 (초, 기본: 300)
  entryConfidenceThreshold: number; // AI 신뢰도 최소치 (기본: 70)
}

async function executeBuy(
  stock: StockScore,
  account: AccountBalance,
  config: BuyConfig
): Promise<BuyResult> {
  
  // 1. 사전 검증
  if (stock.totalScore < config.entryConfidenceThreshold) {
    return { status: 'SKIP', reason: '신뢰도 부족' };
  }
  
  // 2. 포지션 사이즈 계산
  const availableCash = account.cash * (1 - config.minCashReserve);
  const maxBuyAmount = availableCash * config.maxPositionRatio;
  const quantity = Math.floor(maxBuyAmount / stock.targetPrice);
  
  if (quantity <= 0) {
    return { status: 'SKIP', reason: '매수 가능 수량 없음' };
  }
  
  // 3. AI 최종 확인
  const aiDecision = await shouldTrade(stock, currentPrice, realtimeData);
  if (aiDecision.action !== 'BUY') {
    return { status: 'WAIT', reason: aiDecision.reason };
  }
  
  // 4. 매수 실행
  const order = await broker.buyLimit(stock.stockCode, quantity, stock.targetPrice);
  
  // 5. 모니터링 등록
  registerPositionMonitor(order, stock);
  
  return { status: 'EXECUTED', order };
}
```

### 6-3. 매도 로직 (수익 극대화 + 손절)

```typescript
// sell-engine.ts

interface SellConfig {
  profitTakeMin: number;        // 최소 익절 기준 (기본: 2%)
  profitTakeMax: number;        // 최대 익절 기준 (기본: 25%)
  stopLossThreshold: number;    // 손절 기준 (기본: -3%)
  trailingStopRatio: number;    // 트레일링 스탑 비율 (기본: 1.5%)
  profitDeclineThreshold: number; // 고점 대비 하락 허용치 (기본: 1%)
}

async function monitorAndSell(
  position: Position,
  config: SellConfig
): Promise<SellResult> {
  
  let highestProfit = 0;
  
  // 실시간 모니터링 루프
  while (position.isActive) {
    const currentPrice = await broker.getQuote(position.stockCode);
    const profitRate = (currentPrice.price - position.avgPrice) / position.avgPrice;
    
    // ── 손절 체크 (최우선) ──
    if (profitRate <= config.stopLossThreshold) {
      const result = await broker.sellMarket(position.stockCode, position.quantity);
      await scoreEngine.recordLoss(position, profitRate);
      return { status: 'STOP_LOSS', profitRate, result };
    }
    
    // ── 수익 구간 진입 (2% 이상) ──
    if (profitRate >= config.profitTakeMin) {
      
      // 최고 수익률 갱신
      highestProfit = Math.max(highestProfit, profitRate);
      
      // 트레일링 스탑: 고점 대비 하락 시 매도
      if (profitRate < highestProfit - config.profitDeclineThreshold) {
        const result = await broker.sellMarket(position.stockCode, position.quantity);
        await scoreEngine.recordProfit(position, profitRate);
        return { status: 'TRAILING_STOP', profitRate, result };
      }
      
      // 최대 익절 기준 도달 시 즉시 매도
      if (profitRate >= config.profitTakeMax) {
        const result = await broker.sellMarket(position.stockCode, position.quantity);
        await scoreEngine.recordProfit(position, profitRate);
        return { status: 'MAX_PROFIT', profitRate, result };
      }
      
      // AI에게 지금 팔아야 하는지 실시간 질의
      const aiSellDecision = await ai.shouldSell(position, currentPrice, profitRate);
      if (aiSellDecision.action === 'SELL') {
        const result = await broker.sellMarket(position.stockCode, position.quantity);
        await scoreEngine.recordProfit(position, profitRate);
        return { status: 'AI_DECISION', profitRate, result };
      }
    }
    
    // 다음 틱 대기 (500ms~1s)
    await sleep(500);
  }
}
```

### 6-4. "기다림" 로직 (No-Trade 판단)

```typescript
// patience-engine.ts

interface MarketCondition {
  isVolatilityTooHigh: boolean;   // 변동성 과다
  isVolumeTooLow: boolean;        // 거래량 부족
  isNoGoodCandidate: boolean;     // 적절한 종목 없음
  consecutiveLosses: number;      // 연속 손절 횟수
  dailyLossRate: number;          // 당일 누적 손실률
}

function shouldWait(condition: MarketCondition): WaitDecision {
  
  // 연속 3회 이상 손절 → 30분 강제 대기
  if (condition.consecutiveLosses >= 3) {
    return { wait: true, duration: 1800, reason: '연속 손절 — 시장 재분석 필요' };
  }
  
  // 당일 누적 손실 -5% 이상 → 당일 거래 종료
  if (condition.dailyLossRate <= -0.05) {
    return { wait: true, duration: Infinity, reason: '일일 손실 한도 초과 — 거래 종료' };
  }
  
  // 변동성 과다 (VIX 상당) → 변동성 안정까지 대기
  if (condition.isVolatilityTooHigh) {
    return { wait: true, duration: 600, reason: '변동성 과다 — 안정 후 재진입' };
  }
  
  // 종목 없음 → 10분 후 재스캔
  if (condition.isNoGoodCandidate) {
    return { wait: true, duration: 600, reason: '적절한 종목 없음 — 재스캔 예정' };
  }
  
  return { wait: false };
}
```

---

## 7. 스코어링 시스템

### 7-1. 점수 체계

```typescript
// scoring-engine.ts

interface TradeScore {
  tradeId: string;
  stockCode: string;
  stockName: string;
  type: 'PROFIT' | 'LOSS';
  profitRate: number;
  rawScore: number;
  bonusScore: number;
  penaltyScore: number;
  finalScore: number;
  timestamp: Date;
}

function calculateScore(profitRate: number, tradeType: string): TradeScore {
  let rawScore = 0;
  let bonus = 0;
  let penalty = 0;
  
  if (profitRate > 0) {
    // ── 수익 거래 점수 ──
    rawScore = profitRate * 100;  // 1% = 1점 기본
    
    // 보너스: 목표(5%) 초과 시 초과분 × 2배
    if (profitRate > 0.05) {
      bonus = (profitRate - 0.05) * 200;
    }
    
    // 보너스: 10% 이상 수익 시 추가 +5점
    if (profitRate >= 0.10) {
      bonus += 5;
    }
    
    // 보너스: 20% 이상 수익 시 추가 +10점
    if (profitRate >= 0.20) {
      bonus += 10;
    }
    
  } else {
    // ── 손절 거래 감점 ──
    rawScore = 0;
    penalty = Math.abs(profitRate) * 150;  // 1% 손실 = -1.5점
    
    // 추가 감점: -5% 이상 손실 시 가중 감점
    if (profitRate <= -0.05) {
      penalty += 5;
    }
  }
  
  const finalScore = rawScore + bonus - penalty;
  
  return { rawScore, bonusScore: bonus, penaltyScore: penalty, finalScore };
}
```

### 7-2. 일일 리포트 스코어

```typescript
interface DailyReport {
  date: string;
  totalTrades: number;
  profitTrades: number;
  lossTrades: number;
  winRate: number;              // 승률 (%)
  totalProfitRate: number;      // 총 수익률
  totalScore: number;           // 총 점수
  avgScorePerTrade: number;     // 거래당 평균 점수
  bestTrade: TradeScore;        // 최고 거래
  worstTrade: TradeScore;       // 최악 거래
  waitCount: number;            // 대기(미거래) 횟수
  marketSentiment: string;      // AI 시장 평가
  recommendations: string[];    // AI 개선 제안
}
```

---

## 8. Database 스키마

```sql
-- 사용자 계좌 정보
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  broker_type TEXT NOT NULL,          -- 'KIWOOM' | 'KIS'
  account_number TEXT NOT NULL,
  api_key_encrypted TEXT NOT NULL,
  api_secret_encrypted TEXT NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 일일 워치리스트
CREATE TABLE watchlist (
  id TEXT PRIMARY KEY,
  date DATE NOT NULL,
  stock_code TEXT NOT NULL,
  stock_name TEXT NOT NULL,
  theme TEXT,
  total_score REAL,
  recommendation TEXT,                -- 'BUY' | 'WATCH' | 'AVOID'
  target_price INTEGER,
  stop_loss_price INTEGER,
  entry_condition TEXT,
  ai_reasoning TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 거래 이력
CREATE TABLE trades (
  id TEXT PRIMARY KEY,
  account_id TEXT REFERENCES accounts(id),
  stock_code TEXT NOT NULL,
  stock_name TEXT NOT NULL,
  trade_type TEXT NOT NULL,           -- 'BUY' | 'SELL'
  quantity INTEGER NOT NULL,
  price INTEGER NOT NULL,
  total_amount INTEGER NOT NULL,
  sell_reason TEXT,                    -- 'PROFIT' | 'STOP_LOSS' | 'TRAILING' | 'AI_DECISION' | 'MARKET_CLOSE'
  profit_rate REAL,
  score REAL,
  ai_decision_log TEXT,               -- AI 판단 과정 JSON
  executed_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- 일일 리포트
CREATE TABLE daily_reports (
  id TEXT PRIMARY KEY,
  date DATE NOT NULL UNIQUE,
  total_trades INTEGER,
  profit_trades INTEGER,
  loss_trades INTEGER,
  win_rate REAL,
  total_profit_rate REAL,
  total_score REAL,
  report_json TEXT,                    -- 상세 리포트 JSON
  created_at TIMESTAMP DEFAULT NOW()
);

-- 기술적 지표 캐시
CREATE TABLE technical_indicators (
  id TEXT PRIMARY KEY,
  stock_code TEXT NOT NULL,
  date DATE NOT NULL,
  rsi REAL,
  macd REAL,
  macd_signal REAL,
  bollinger_upper REAL,
  bollinger_lower REAL,
  ma5 REAL,
  ma20 REAL,
  ma60 REAL,
  volume_ratio REAL,
  stochastic_k REAL,
  stochastic_d REAL,
  total_score REAL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(stock_code, date)
);

-- AI 판단 로그 (추적용)
CREATE TABLE ai_decision_logs (
  id TEXT PRIMARY KEY,
  decision_type TEXT NOT NULL,        -- 'STOCK_SELECT' | 'BUY' | 'SELL' | 'WAIT'
  input_data TEXT NOT NULL,           -- AI에 전달한 데이터 JSON
  output_data TEXT NOT NULL,          -- AI 응답 JSON
  model_used TEXT,
  confidence REAL,
  was_correct BOOLEAN,               -- 사후 검증 결과
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## 9. Frontend 대시보드

### 9-1. 페이지 구성

```
/ (메인 대시보드)
├── /dashboard          → 실시간 거래 현황, PnL, 스코어
├── /watchlist          → 오늘의 워치리스트 5종목 + AI 분석
├── /positions          → 현재 보유 포지션 실시간 모니터링
├── /trades             → 거래 이력 (필터, 검색, 통계)
├── /reports            → 일일/주간/월간 리포트
├── /backtest           → 백테스팅 시뮬레이션
├── /settings           → 계좌 연동, 매매 설정, 알림 설정
└── /ai-logs            → AI 판단 이력 열람
```

### 9-2. 메인 대시보드 레이아웃

```
┌──────────────────────────────────────────────────────┐
│  AutoTradeX Dashboard                    [설정] [알림] │
├──────────┬───────────┬───────────┬───────────────────┤
│ 오늘 수익 │ 오늘 점수  │ 승률      │ 거래 횟수         │
│ +3.2%    │ 47.5pt   │ 75%      │ 8/100             │
├──────────┴───────────┴───────────┴───────────────────┤
│                                                      │
│  [실시간 PnL 차트 - 오늘 계좌 잔고 변화 추이]           │
│                                                      │
├──────────────────────┬───────────────────────────────┤
│ 현재 포지션           │ 워치리스트                      │
│ ┌─────────────────┐  │ ┌───────────────────────────┐ │
│ │ 삼성전자 +2.3%  │  │ │ 1. XXXXX  스코어:87 [매수] │ │
│ │ 수량:50 목표:3% │  │ │ 2. XXXXX  스코어:82 [대기] │ │
│ └─────────────────┘  │ │ 3. XXXXX  스코어:78 [대기] │ │
│ ┌─────────────────┐  │ │ 4. XXXXX  스코어:71 [관망] │ │
│ │ 카카오 -0.8%    │  │ │ 5. XXXXX  스코어:70 [관망] │ │
│ │ 수량:30 손절:-3%│  │ └───────────────────────────┘ │
│ └─────────────────┘  │                               │
├──────────────────────┴───────────────────────────────┤
│ 최근 거래 로그                                         │
│ 09:32 삼성전자 매수 50주 @ 72,300원  [AI신뢰도:85]     │
│ 09:15 LG에너지 매도 30주 @ 412,000원 [+4.2% / +6.3pt] │
│ 09:10 시장분석 완료: "반도체·2차전지 주도" [적극매매]     │
└──────────────────────────────────────────────────────┘
```

### 9-3. 차트 컴포넌트

```typescript
// 종목 상세 차트에 포함할 요소
interface StockChartProps {
  stockCode: string;
  candles: Candle[];           // 캔들차트 (1분/5분/일봉)
  overlays: {
    ma5: number[];             // 5일 이동평균
    ma20: number[];            // 20일 이동평균
    ma60: number[];            // 60일 이동평균
    bollingerUpper: number[];  // 볼린저밴드 상단
    bollingerLower: number[];  // 볼린저밴드 하단
  };
  subCharts: {
    volume: number[];          // 거래량 바
    rsi: number[];             // RSI 라인
    macd: { macd: number[]; signal: number[]; histogram: number[] };
    stochastic: { k: number[]; d: number[] };
  };
  markers: {
    buyPoints: TradeMarker[];  // 매수 시점 마커
    sellPoints: TradeMarker[]; // 매도 시점 마커
  };
}
```

---

## 10. 안전장치 및 리스크 관리

### 10-1. 필수 안전장치

| 안전장치 | 설명 | 설정값 |
|----------|------|--------|
| 일일 최대 손실 | 하루 총 손실 한도 초과 시 거래 중단 | -5% |
| 연속 손절 제한 | 연속 3회 손절 시 30분 강제 대기 | 3회/30분 |
| 단일 종목 비중 | 한 종목에 전체 자산의 30% 초과 투자 금지 | 30% |
| 최대 동시 보유 | 동시에 3종목 이상 보유 금지 | 3종목 |
| 시초가 매매 금지 | 09:00~09:10 사이 주문 금지 | 10분 |
| 장마감 전 청산 | 14:50까지 미청산 포지션 강제 매도 | 14:50 |
| API 호출 제한 | 초당/분당 API 호출 수 제한 | 증권사별 상이 |
| 현금 보유 최소 | 항상 20% 이상 현금 유지 | 20% |

### 10-2. 서킷브레이커

```typescript
// circuit-breaker.ts

class TradingCircuitBreaker {
  private consecutiveLosses = 0;
  private dailyLoss = 0;
  private isHalted = false;
  
  onTradeComplete(result: TradeResult) {
    if (result.profitRate < 0) {
      this.consecutiveLosses++;
      this.dailyLoss += result.profitRate;
    } else {
      this.consecutiveLosses = 0;
    }
    
    // 서킷브레이커 발동 조건 체크
    if (this.consecutiveLosses >= 3) {
      this.halt('CONSECUTIVE_LOSS', 1800);
    }
    if (this.dailyLoss <= -0.05) {
      this.halt('DAILY_LOSS_LIMIT', Infinity);
    }
  }
  
  private halt(reason: string, durationSec: number) {
    this.isHalted = true;
    log(`[서킷브레이커] ${reason} — ${durationSec}초 거래 중단`);
    notify(`거래 중단: ${reason}`);
    
    if (durationSec !== Infinity) {
      setTimeout(() => { this.isHalted = false; }, durationSec * 1000);
    }
  }
  
  canTrade(): boolean {
    return !this.isHalted;
  }
}
```

---

## 10-A. 보안 아키텍처 (Security Architecture)

> **원칙**: 이 앱은 실제 증권 계좌와 연동되어 자금이 이동하는 금융 거래 시스템이다.
> 따라서 **"뚫리면 곧 돈이 날아간다"**는 전제 하에, 모든 레이어에 방어를 설계한다.

---

### 10-A-1. 보안 위협 모델 (Threat Model)

이 시스템에서 발생할 수 있는 핵심 위협을 먼저 정의하고, 각 위협별 대응을 설계한다:

| 위협 | 심각도 | 공격 시나리오 | 대응 방안 |
|------|--------|--------------|-----------|
| 증권사 API Key 탈취 | **Critical** | 서버 침입 → 평문 저장된 API Key 탈취 → 무단 매매 | AES-256-GCM 암호화 + Vault 저장 |
| 세션 하이재킹 | **Critical** | 토큰 가로채기 → 관리자 대시보드 무단 접근 | JWT + HttpOnly Secure Cookie + IP 바인딩 |
| 중간자 공격 (MITM) | **High** | 증권사 API 통신 도청 → 계좌정보/주문정보 유출 | TLS 1.2+ 강제 + 인증서 피닝 |
| 주문 변조 | **Critical** | API 요청 조작 → 의도하지 않은 대량 매수/매도 실행 | 요청 서명(HMAC) + 주문 한도 검증 |
| 무차별 대입 (Brute Force) | **High** | 로그인 반복 시도 → 계정 탈취 | Rate Limiting + 계정 잠금 + CAPTCHA |
| 내부 로그 유출 | **Medium** | 로그에 평문 API Key/계좌번호 노출 → 로그 수집 시 유출 | 민감정보 마스킹 + 로그 접근 제어 |
| XSS / CSRF | **High** | 대시보드를 통한 악성 스크립트 주입 → 세션 탈취 | CSP 헤더 + CSRF 토큰 + 입력값 새니타이징 |
| 공급망 공격 | **Medium** | 악성 npm 패키지 → 백도어 삽입 | 의존성 감사(audit) + lock 파일 고정 + SCA 도구 |
| DB 인젝션 | **High** | SQL Injection → 거래 이력/계좌 정보 탈취 | ORM/Prepared Statement 강제 + 입력값 검증 |
| 서버 권한 탈취 | **Critical** | 서버 SSH 접근 → 전체 시스템 장악 | 키 기반 인증만 허용 + 방화벽 + 최소 권한 원칙 |

---

### 10-A-2. 인증 및 권한 관리 (Authentication & Authorization)

#### 앱 사용자 인증

```typescript
// auth/auth-config.ts

interface AuthConfig {
  // JWT 설정
  jwt: {
    algorithm: 'RS256';                    // 비대칭키 알고리즘 (HS256 사용 금지)
    accessTokenExpiry: '15m';              // Access Token 15분
    refreshTokenExpiry: '7d';              // Refresh Token 7일
    issuer: 'autotradex';
    audience: 'autotradex-client';
  };
  
  // 세션 보안
  session: {
    cookieHttpOnly: true;                  // JS에서 쿠키 접근 차단
    cookieSecure: true;                    // HTTPS에서만 전송
    cookieSameSite: 'strict';              // CSRF 방어
    ipBinding: true;                       // 토큰 발급 IP와 요청 IP 일치 검증
    deviceFingerprint: true;               // 디바이스 지문 검증
  };
  
  // 로그인 보안
  login: {
    maxAttempts: 5;                        // 5회 실패 시 잠금
    lockoutDuration: 1800;                 // 30분 잠금
    requireMFA: true;                      // 다중 인증 필수
    mfaMethods: ['TOTP', 'EMAIL'];         // Google Authenticator 또는 이메일 OTP
    passwordMinLength: 12;                 // 최소 12자
    passwordRequireSpecial: true;          // 특수문자 필수
    passwordRequireNumber: true;           // 숫자 필수
    passwordRequireUpperLower: true;       // 대소문자 혼합 필수
  };
  
  // 비밀번호 해싱
  hashing: {
    algorithm: 'argon2id';                 // bcrypt 대신 argon2id (메모리 하드)
    memoryCost: 65536;                     // 64MB
    timeCost: 3;
    parallelism: 4;
  };
}
```

#### 역할 기반 접근 제어 (RBAC)

```typescript
// auth/rbac.ts

enum Role {
  OWNER = 'owner',       // 계좌 소유자: 모든 권한
  VIEWER = 'viewer',     // 읽기 전용: 대시보드 조회만 가능
  SYSTEM = 'system',     // 시스템: 자동매매 엔진 전용 (UI 접근 불가)
}

const permissions = {
  [Role.OWNER]: [
    'account:read', 'account:write', 'account:delete',
    'trade:execute', 'trade:cancel', 'trade:read',
    'settings:read', 'settings:write',
    'report:read', 'report:export',
    'ai-log:read',
  ],
  [Role.VIEWER]: [
    'account:read',
    'trade:read',
    'report:read',
    'ai-log:read',
  ],
  [Role.SYSTEM]: [
    'trade:execute', 'trade:cancel', 'trade:read',
    'account:read',
    'ai-log:write',
  ],
};

// 매 API 요청마다 권한 체크
function requirePermission(permission: string) {
  return (req: Request, res: Response, next: Next) => {
    const userRole = req.auth.role;
    if (!permissions[userRole]?.includes(permission)) {
      auditLog('UNAUTHORIZED_ACCESS', { 
        userId: req.auth.userId, 
        attempted: permission,
        ip: req.ip 
      });
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  };
}
```

---

### 10-A-3. 증권사 API Key 암호화 및 관리

> **핵심 원칙**: API Key와 Secret은 **절대 평문으로 저장하지 않는다**.
> DB, 환경변수, 로그, 에러 메시지 어디에도 평문이 노출되어서는 안 된다.

#### 암호화 저장 구조

```typescript
// security/credential-vault.ts

import { createCipheriv, createDecipheriv, randomBytes, scrypt } from 'crypto';

class CredentialVault {
  
  private static readonly ALGORITHM = 'aes-256-gcm';
  private static readonly KEY_LENGTH = 32;
  private static readonly IV_LENGTH = 16;
  private static readonly AUTH_TAG_LENGTH = 16;
  
  /**
   * 마스터 키 파생: 사용자 비밀번호 + 시스템 시크릿으로부터 파생
   * - 마스터 키는 메모리에만 존재, 디스크에 저장 금지
   * - 서버 재시작 시 사용자 인증을 통해 재파생
   */
  private static async deriveKey(
    userPassword: string, 
    salt: Buffer
  ): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      scrypt(
        userPassword + process.env.SYSTEM_ENCRYPTION_SECRET,
        salt,
        CredentialVault.KEY_LENGTH,
        { N: 32768, r: 8, p: 1 },
        (err, key) => err ? reject(err) : resolve(key)
      );
    });
  }
  
  /**
   * 증권사 API Key 암호화 후 저장
   */
  static async encrypt(plainText: string, userPassword: string): Promise<EncryptedData> {
    const salt = randomBytes(32);
    const iv = randomBytes(CredentialVault.IV_LENGTH);
    const key = await this.deriveKey(userPassword, salt);
    
    const cipher = createCipheriv(this.ALGORITHM, key, iv);
    let encrypted = cipher.update(plainText, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag();
    
    return {
      encrypted,
      iv: iv.toString('hex'),
      salt: salt.toString('hex'),
      authTag: authTag.toString('hex'),
      algorithm: this.ALGORITHM,
      createdAt: new Date().toISOString(),
    };
  }
  
  /**
   * 복호화 (매매 실행 시점에만 메모리에서 복호화, 사용 후 즉시 폐기)
   */
  static async decrypt(data: EncryptedData, userPassword: string): Promise<string> {
    const salt = Buffer.from(data.salt, 'hex');
    const iv = Buffer.from(data.iv, 'hex');
    const authTag = Buffer.from(data.authTag, 'hex');
    const key = await this.deriveKey(userPassword, salt);
    
    const decipher = createDecipheriv(this.ALGORITHM, key, iv);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(data.encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
    // 호출자는 사용 후 변수를 null로 설정하여 메모리에서 제거
  }
}
```

#### 시크릿 관리 전략 (환경별)

```
[개발 환경]
  .env.local 파일 (gitignore 필수)
  + dotenv-vault 또는 Infisical (로컬 시크릿 관리)

[스테이징 / 프로덕션]
  방법 1 (권장): HashiCorp Vault
    - AppRole 인증 → 런타임에 시크릿 주입
    - 시크릿 자동 로테이션 (90일 주기)
    - 감사 로그 자동 기록
    
  방법 2: Cloudflare Workers Secrets
    - wrangler secret put KIWOOM_APP_KEY
    - Workers 런타임 내에서만 접근 가능
    - 환경변수와 분리된 암호화 저장소
    
  방법 3: AWS Secrets Manager / GCP Secret Manager
    - IAM 기반 접근 제어
    - 자동 로테이션 + 버전 관리
```

#### API Key 생명주기 관리

```typescript
// security/key-lifecycle.ts

interface KeyLifecycle {
  // 키 로테이션: 90일마다 자동 갱신 알림
  rotationIntervalDays: 90;
  
  // 키 상태 추적
  statuses: 'ACTIVE' | 'ROTATING' | 'EXPIRED' | 'REVOKED';
  
  // 비상 폐기: 이상 거래 감지 시 즉시 키 무효화
  emergencyRevoke(): Promise<void>;
  
  // 키 사용 감사: 언제, 어디서, 어떤 API 호출에 사용되었는지 기록
  auditKeyUsage(keyId: string, action: string, ip: string): void;
}
```

---

### 10-A-4. 통신 보안 (Transport Security)

```typescript
// security/transport.ts

interface TransportSecurityConfig {
  
  // TLS 설정
  tls: {
    minVersion: 'TLSv1.2';                // TLS 1.0, 1.1 차단
    preferredVersion: 'TLSv1.3';          // TLS 1.3 우선
    cipherSuites: [                        // 강력한 암호화 스위트만 허용
      'TLS_AES_256_GCM_SHA384',
      'TLS_CHACHA20_POLY1305_SHA256',
      'TLS_AES_128_GCM_SHA256',
    ];
    rejectUnauthorized: true;              // 유효하지 않은 인증서 거부
  };
  
  // 인증서 피닝 (증권사 API 통신 시)
  certificatePinning: {
    enabled: true;
    pins: {
      'openapi.kiwoom.com': ['sha256/XXXX...'],   // 키움 인증서 핀
      'apiportal.koreainvestment.com': ['sha256/XXXX...'],  // KIS 인증서 핀
    };
    // 인증서 변경 시 알림 → 수동 확인 후 핀 업데이트
    onPinMismatch: 'BLOCK_AND_ALERT';
  };
  
  // HTTP 보안 헤더
  headers: {
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload';
    'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'";
    'X-Content-Type-Options': 'nosniff';
    'X-Frame-Options': 'DENY';
    'X-XSS-Protection': '1; mode=block';
    'Referrer-Policy': 'strict-origin-when-cross-origin';
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=()';
  };
}
```

#### 증권사 API 통신 보안 래퍼

```typescript
// security/secure-http-client.ts

import https from 'https';

class SecureBrokerClient {
  private agent: https.Agent;
  
  constructor() {
    this.agent = new https.Agent({
      minVersion: 'TLSv1.2',
      rejectUnauthorized: true,
      // 인증서 피닝 콜백
      checkServerIdentity: (host, cert) => {
        const expectedPin = CERTIFICATE_PINS[host];
        if (expectedPin && !this.verifyPin(cert, expectedPin)) {
          auditLog('CERT_PIN_MISMATCH', { host, certFingerprint: cert.fingerprint256 });
          throw new Error(`Certificate pinning failed for ${host}`);
        }
      },
    });
  }
  
  // 모든 증권사 API 호출은 이 메서드를 통과
  async request(url: string, options: RequestOptions): Promise<Response> {
    // 1. 요청 전 URL 화이트리스트 검증
    this.validateUrl(url);
    
    // 2. 요청 본문에 민감정보 포함 시 로깅 제외
    const sanitizedOptions = this.sanitizeForLogging(options);
    auditLog('API_REQUEST', sanitizedOptions);
    
    // 3. 보안 에이전트로 요청
    const response = await fetch(url, { ...options, agent: this.agent });
    
    // 4. 응답 무결성 검증
    this.validateResponse(response);
    
    return response;
  }
  
  // 허용된 도메인만 호출 가능
  private validateUrl(url: string) {
    const allowedDomains = [
      'openapi.kiwoom.com',
      'apiportal.koreainvestment.com',
    ];
    const hostname = new URL(url).hostname;
    if (!allowedDomains.includes(hostname)) {
      throw new Error(`Blocked request to unauthorized domain: ${hostname}`);
    }
  }
}
```

---

### 10-A-5. 주문 무결성 및 이상 거래 탐지

```typescript
// security/trade-integrity.ts

class TradeIntegrityGuard {
  
  /**
   * 주문 전 무결성 검증 체크리스트
   * 모든 주문은 이 가드를 통과해야만 증권사 API로 전달됨
   */
  async validateOrder(order: TradeOrder, account: Account): Promise<ValidationResult> {
    const checks: Check[] = [];
    
    // 1. 주문 금액 한도 검증
    checks.push({
      name: 'ORDER_AMOUNT_LIMIT',
      passed: order.totalAmount <= account.maxSingleOrderAmount,
      detail: `주문금액 ${order.totalAmount} / 한도 ${account.maxSingleOrderAmount}`,
    });
    
    // 2. 일일 최대 거래 횟수 검증
    const todayTradeCount = await this.getTodayTradeCount(account.id);
    checks.push({
      name: 'DAILY_TRADE_LIMIT',
      passed: todayTradeCount < 100,
      detail: `오늘 거래 ${todayTradeCount}회 / 한도 100회`,
    });
    
    // 3. 동일 종목 반복 매매 검증 (5분 이내 동일 종목 재매수 방지)
    const recentSameStock = await this.getRecentTrade(order.stockCode, 300);
    checks.push({
      name: 'RAPID_RETRADE_GUARD',
      passed: !recentSameStock,
      detail: `동일 종목 5분 내 재매수 방지`,
    });
    
    // 4. 주문가격 이상치 검증 (현재가 대비 ±10% 벗어나면 차단)
    const currentPrice = await this.getCurrentPrice(order.stockCode);
    const priceDeviation = Math.abs(order.price - currentPrice) / currentPrice;
    checks.push({
      name: 'PRICE_ANOMALY',
      passed: priceDeviation <= 0.10,
      detail: `주문가 ${order.price} / 현재가 ${currentPrice} / 괴리 ${(priceDeviation * 100).toFixed(1)}%`,
    });
    
    // 5. 총 포지션 비중 검증
    const totalPositionRatio = await this.getTotalPositionRatio(account.id);
    checks.push({
      name: 'TOTAL_EXPOSURE_LIMIT',
      passed: totalPositionRatio + (order.totalAmount / account.totalAsset) <= 0.80,
      detail: `전체 비중 ${(totalPositionRatio * 100).toFixed(1)}% + 신규 → 80% 이하`,
    });
    
    // 6. 주문 서명 검증 (내부 HMAC — AI 엔진 → 매매 엔진 간 변조 방지)
    checks.push({
      name: 'ORDER_SIGNATURE',
      passed: this.verifyOrderSignature(order),
      detail: `HMAC-SHA256 서명 검증`,
    });
    
    // 하나라도 실패 시 주문 차단 + 감사 로그
    const failed = checks.filter(c => !c.passed);
    if (failed.length > 0) {
      auditLog('ORDER_BLOCKED', { order, failedChecks: failed });
      notify(`[보안 경고] 주문 차단됨: ${failed.map(f => f.name).join(', ')}`);
    }
    
    return { 
      approved: failed.length === 0, 
      checks,
      orderId: this.generateSecureOrderId(),
    };
  }
  
  /**
   * 이상 거래 패턴 감지 (Anomaly Detection)
   */
  async detectAnomalies(account: Account): Promise<AnomalyReport> {
    const anomalies: Anomaly[] = [];
    
    // 패턴 1: 평소 거래량 대비 비정상적으로 많은 거래
    const avgDailyTrades = await this.getAvgDailyTrades(account.id, 30);
    const todayTrades = await this.getTodayTradeCount(account.id);
    if (todayTrades > avgDailyTrades * 3) {
      anomalies.push({ type: 'UNUSUAL_TRADE_VOLUME', severity: 'HIGH' });
    }
    
    // 패턴 2: 평소 거래하지 않는 시간대에 거래 발생
    const currentHour = new Date().getHours();
    if (currentHour < 9 || currentHour > 16) {
      anomalies.push({ type: 'OFF_HOURS_TRADING', severity: 'CRITICAL' });
    }
    
    // 패턴 3: 비정상적으로 큰 금액의 단일 거래
    // 패턴 4: 새로운 IP/디바이스에서의 거래 요청
    // 패턴 5: 짧은 시간 내 다수의 손절 (시스템 오작동 가능성)
    
    if (anomalies.some(a => a.severity === 'CRITICAL')) {
      await this.emergencyHalt(account.id);
      notify(`[긴급] 이상 거래 감지 — 자동매매 긴급 중단됨`);
    }
    
    return { anomalies, timestamp: new Date() };
  }
}
```

---

### 10-A-6. 민감정보 로깅 정책

```typescript
// security/secure-logger.ts

class SecureLogger {
  
  // 마스킹 대상 필드 목록
  private static SENSITIVE_FIELDS = [
    'apiKey', 'appKey', 'appSecret', 'api_key', 'app_key', 'app_secret',
    'accessToken', 'refreshToken', 'access_token', 'refresh_token',
    'password', 'accountNumber', 'account_number', 'account_no',
    'api_key_encrypted', 'api_secret_encrypted',
  ];
  
  /**
   * 로그 출력 전 민감정보 자동 마스킹
   * "appKey": "abc123def456" → "appKey": "abc***456"
   */
  static sanitize(data: any): any {
    if (typeof data === 'string') {
      return data;
    }
    
    const sanitized = { ...data };
    for (const key of Object.keys(sanitized)) {
      if (this.SENSITIVE_FIELDS.includes(key)) {
        const val = String(sanitized[key]);
        if (val.length > 6) {
          sanitized[key] = val.slice(0, 3) + '***' + val.slice(-3);
        } else {
          sanitized[key] = '******';
        }
      } else if (typeof sanitized[key] === 'object') {
        sanitized[key] = this.sanitize(sanitized[key]);
      }
    }
    return sanitized;
  }
  
  static info(message: string, data?: any) {
    console.log(`[INFO] ${message}`, data ? this.sanitize(data) : '');
  }
  
  static error(message: string, data?: any) {
    console.error(`[ERROR] ${message}`, data ? this.sanitize(data) : '');
  }
}
```

---

### 10-A-7. 감사 로그 (Audit Trail)

> 금융 거래 시스템에서 감사 로그는 선택이 아닌 필수다.
> 모든 중요 행위는 **변경 불가능한 로그**로 기록한다.

```sql
-- audit_logs 테이블 (기존 DB 스키마에 추가)
CREATE TABLE audit_logs (
  id TEXT PRIMARY KEY,
  timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
  event_type TEXT NOT NULL,               -- 'LOGIN' | 'LOGIN_FAIL' | 'ORDER_PLACED' | 'ORDER_BLOCKED' | 'KEY_ACCESS' | 'SETTINGS_CHANGED' 등
  actor_id TEXT,                          -- 수행자 (userId 또는 'SYSTEM')
  actor_ip TEXT,                          -- 요청 IP
  actor_device TEXT,                      -- 디바이스 정보 (User-Agent 해시)
  resource TEXT,                          -- 대상 리소스 (종목코드, 계좌ID 등)
  action TEXT NOT NULL,                   -- 수행한 행위 상세
  result TEXT NOT NULL,                   -- 'SUCCESS' | 'FAIL' | 'BLOCKED'
  detail_json TEXT,                       -- 추가 상세 (민감정보 마스킹 상태)
  risk_level TEXT DEFAULT 'LOW',          -- 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
  
  -- 감사 로그는 수정/삭제 금지 (앱 레벨에서 DELETE/UPDATE 쿼리 차단)
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 인덱스: 빠른 조회용
CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_event_type ON audit_logs(event_type);
CREATE INDEX idx_audit_risk_level ON audit_logs(risk_level);
CREATE INDEX idx_audit_actor ON audit_logs(actor_id);
```

#### 감사 대상 이벤트 목록

```typescript
const AUDITABLE_EVENTS = [
  // 인증 관련
  'LOGIN_SUCCESS',
  'LOGIN_FAIL',
  'MFA_SUCCESS',
  'MFA_FAIL',
  'LOGOUT',
  'PASSWORD_CHANGED',
  'TOKEN_REFRESHED',
  'SESSION_EXPIRED',
  
  // 계좌/키 관련
  'BROKER_KEY_REGISTERED',
  'BROKER_KEY_ACCESSED',        // API Key 복호화 시점 기록
  'BROKER_KEY_ROTATED',
  'BROKER_KEY_REVOKED',
  'SETTINGS_CHANGED',
  
  // 거래 관련
  'ORDER_PLACED',
  'ORDER_EXECUTED',
  'ORDER_CANCELLED',
  'ORDER_BLOCKED',              // 보안 가드에 의해 차단된 주문
  'STOP_LOSS_TRIGGERED',
  
  // 보안 이벤트
  'UNAUTHORIZED_ACCESS',
  'CERT_PIN_MISMATCH',
  'ANOMALY_DETECTED',
  'CIRCUIT_BREAKER_TRIGGERED',
  'EMERGENCY_HALT',
  'RATE_LIMIT_HIT',
  'IP_BLOCKED',
] as const;
```

---

### 10-A-8. 입력값 검증 및 인젝션 방지

```typescript
// security/input-validator.ts

import { z } from 'zod';  // Zod 스키마 검증 라이브러리

// 모든 API 엔드포인트의 입력값을 Zod 스키마로 강제 검증

const StockCodeSchema = z.string()
  .regex(/^[0-9]{6}$/, '종목코드는 6자리 숫자여야 합니다');

const OrderSchema = z.object({
  stockCode: StockCodeSchema,
  quantity: z.number().int().positive().max(99999),
  price: z.number().int().positive().max(99999999),
  orderType: z.enum(['LIMIT', 'MARKET']),
});

const LoginSchema = z.object({
  email: z.string().email().max(100),
  password: z.string().min(12).max(100),
  mfaCode: z.string().length(6).regex(/^[0-9]+$/),
});

// SQL Injection 방지: ORM(Drizzle/Prisma)의 Prepared Statement만 사용
// 직접 SQL 문자열 조합 절대 금지
// 코드 리뷰 체크리스트에 포함
```

---

### 10-A-9. Rate Limiting & DDoS 방어

```typescript
// security/rate-limiter.ts

interface RateLimitConfig {
  endpoints: {
    // 로그인: 분당 5회 (Brute Force 방지)
    '/api/auth/login': { windowMs: 60000, max: 5 };
    
    // 주문 실행: 분당 30회 (증권사 Rate Limit 보호)
    '/api/trade/order': { windowMs: 60000, max: 30 };
    
    // 일반 API: 분당 100회
    '/api/*': { windowMs: 60000, max: 100 };
    
    // 증권사 API 프록시: 초당 5회 (증권사 정책 준수)
    'broker-api': { windowMs: 1000, max: 5 };
  };
  
  // IP 기반 차단
  ipBlacklist: {
    autoBlockThreshold: 50;    // 1분 내 50회 초과 시 자동 차단
    autoBlockDuration: 3600;   // 1시간 차단
    permanentBlockAfter: 3;    // 자동 차단 3회 누적 시 영구 차단
  };
}
```

---

### 10-A-10. 보안 체크리스트 (개발 및 배포 시 필수 확인)

```
[개발 단계]
☐ 모든 API Key/Secret은 AES-256-GCM으로 암호화 후 저장
☐ 환경변수에 민감정보 직접 하드코딩 없음 (.env 파일 gitignore 확인)
☐ 모든 DB 쿼리는 ORM 또는 Prepared Statement 사용
☐ 모든 API 입력값은 Zod 스키마로 검증
☐ 비밀번호는 argon2id로 해싱
☐ JWT는 RS256 알고리즘 사용 (비대칭키)
☐ 민감정보 로그 마스킹 적용 확인
☐ npm audit으로 취약 의존성 0건 확인

[배포 단계]
☐ TLS 1.2+ 강제 (TLS 1.0/1.1 차단 확인)
☐ 보안 헤더 전체 적용 (HSTS, CSP, X-Frame-Options 등)
☐ CORS 화이트리스트 설정 (와일드카드 금지)
☐ Rate Limiting 전 엔드포인트 적용
☐ SSH 키 기반 인증만 허용 (비밀번호 로그인 차단)
☐ 방화벽 규칙 최소 포트만 개방 (443, SSH 포트)
☐ 감사 로그 정상 기록 확인
☐ 비상 연락 체계 설정 (이상 거래 감지 시 알림)

[운영 단계]
☐ API Key 90일 주기 로테이션 알림 설정
☐ 의존성 업데이트 주간 점검 (dependabot 또는 수동)
☐ 감사 로그 30일 이상 보관
☐ 분기별 모의 침투 테스트 (또는 OWASP ZAP 자동 스캔)
☐ 인증서 만료 모니터링
☐ 백업 및 복구 테스트 분기 1회
```

---

### 10-A-11. 규정 준수 참고사항

이 앱은 개인 자동매매 도구이지만, 향후 확장 시 아래 규정을 참고해야 한다:

| 규정 | 핵심 내용 | 적용 시점 |
|------|-----------|-----------|
| 전자금융감독규정 | 금융 시스템의 보안 요구사항, 접근통제, 암호화, 감사 추적 | 전자금융업자 등록 시 |
| 전자금융거래법 | 전자금융거래의 안전성·신뢰성 확보 의무 | 타인 자금 운용 시 |
| 개인정보보호법 (PIPA) | 개인정보 수집·이용·제공·파기 규율 | 사용자 정보 수집 시 |
| OWASP API Security Top 10 (2025) | API 보안 취약점 10대 항목 대응 | 개발 전 과정 |

---

### 10-A-12. 긴급 대응 플로우 (Incident Response)

```
[이상 징후 감지]
    │
    ├─ 자동 대응 (즉시)
    │   ├─ 자동매매 엔진 긴급 정지
    │   ├─ 미체결 주문 전량 취소 시도
    │   ├─ API Key 임시 비활성화
    │   └─ 감사 로그에 CRITICAL 이벤트 기록
    │
    ├─ 알림 발송 (30초 이내)
    │   ├─ 텔레그램: "[긴급] AutoTradeX 이상 거래 감지"
    │   ├─ 이메일: 상세 로그 포함
    │   └─ SMS: 간략 알림 (선택)
    │
    └─ 수동 확인 (사용자)
        ├─ 대시보드 → 감사 로그 확인
        ├─ 오탐(False Positive) → 거래 재개
        └─ 실제 침입 → 증권사 고객센터 연락 + 비밀번호/API Key 즉시 변경
```

---

## 11. 백테스팅 모듈

### 11-1. 목적
실제 자금 투입 전, 과거 데이터로 전략을 검증한다.

### 11-2. 구현 범위

```typescript
interface BacktestConfig {
  startDate: string;           // 시작일
  endDate: string;             // 종료일
  initialCapital: number;      // 초기 자금
  strategy: TradingStrategy;   // 적용할 전략
  slippage: number;            // 슬리피지 (기본: 0.1%)
  commission: number;          // 수수료 (기본: 0.015%)
}

interface BacktestResult {
  totalReturn: number;         // 총 수익률
  maxDrawdown: number;         // 최대 낙폭
  sharpeRatio: number;         // 샤프 비율
  winRate: number;             // 승률
  totalTrades: number;         // 총 거래 횟수
  avgHoldingTime: number;      // 평균 보유 시간
  dailyReturns: number[];      // 일별 수익률 배열
  tradeLog: BacktestTrade[];   // 거래 내역
}
```

---

## 12. 알림 시스템

```typescript
// notifications.ts

interface NotificationConfig {
  channels: {
    push: boolean;            // 앱 푸시
    email: boolean;           // 이메일
    telegram: boolean;        // 텔레그램 봇 (선택)
  };
  triggers: {
    onBuy: boolean;           // 매수 시
    onSell: boolean;          // 매도 시
    onStopLoss: boolean;      // 손절 시 (항상 ON)
    onDailyReport: boolean;   // 일일 리포트
    onCircuitBreaker: boolean; // 서킷브레이커 발동 시 (항상 ON)
    onTargetReached: boolean;  // 일일 목표 수익률 달성 시
  };
}
```

---

## 13. 배포 및 운영

### 13-1. 배포 환경

```
[개발/테스트]
  Genspark AI Developer → Preview 환경
  모의투자 API 사용 (키움/한투 모의투자 계좌)

[스테이징]
  GitHub → Cloudflare Pages (자동 배포)
  모의투자 API + 실시간 시세

[프로덕션]  
  GitHub → 자체 서버 (SSH 배포) 또는 Cloudflare Workers
  실제 증권사 API (실계좌)
  24시간 모니터링 + 알림
```

### 13-2. 환경변수

```env
# 증권사 API
KIWOOM_APP_KEY=your_app_key
KIWOOM_APP_SECRET=your_app_secret
KIWOOM_ACCOUNT_NO=your_account_number

KIS_APP_KEY=your_app_key
KIS_APP_SECRET=your_app_secret
KIS_ACCOUNT_NO=your_account_number

# AI
GENSPARK_AI_MODEL=claude-sonnet-4

# Database
DATABASE_URL=postgresql://...

# 알림
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id

# 운영
NODE_ENV=production
TZ=Asia/Seoul
TRADING_MODE=live  # 'paper' | 'live'
```

---

## 14. 개발 일정 (예상)

| Phase | 내용 | 예상 기간 | 산출물 |
|-------|------|-----------|--------|
| 1 | 프로젝트 구조 + DB 스키마 + 기본 설정 | 1일 | 프로젝트 boilerplate, DB 마이그레이션 |
| 2 | 증권사 API 연동 모듈 (키움 REST) | 2일 | BrokerAdapter 구현체, 인증 플로우 |
| 3 | 기술적 분석 엔진 (RSI, MACD 등) | 1일 | 지표 계산 모듈, 스코어링 로직 |
| 4 | AI 종목 선정 + 의사결정 엔진 | 2일 | AI Decision Engine, 프롬프트 체계 |
| 5 | 매매 실행 엔진 (매수/매도/손절) | 2일 | Trading Engine, 서킷브레이커 |
| 6 | 대시보드 UI | 2일 | 6개 페이지 프론트엔드 |
| 7 | 백테스팅 + 시뮬레이션 | 1일 | 백테스트 모듈, 결과 시각화 |
| 8 | 통합 테스트 + 모의투자 검증 + 배포 | 2일 | E2E 테스트, CI/CD, 배포 완료 |
| **합계** | | **약 13일** | |

---

## 15. 핵심 제약사항 및 주의사항

1. **법적 고지**: 이 시스템은 투자 자문이 아닌 자동 거래 도구입니다. 모든 투자 손실은 사용자 책임입니다.
2. **모의투자 우선**: 반드시 모의투자 환경에서 최소 2주 이상 검증 후 실투자 전환
3. **증권사 정책 변경**: API 스펙, 호출 제한, NXT 거래가능종목 등이 수시로 변경되므로 주기적 확인 필요
4. **시장 리스크**: AI 판단이 항상 맞지 않으며, 급등락장에서는 손실이 커질 수 있음
5. **TLS 요건**: 모든 증권사 API는 TLS 1.2 이상 필수
6. **장 운영시간**: 한국 주식시장 09:00~15:30 (공휴일/휴장일 자동 스킵 필요)
7. **슬리피지/수수료**: 백테스팅과 실매매 간 괴리가 발생할 수 있으므로 보수적으로 설정

---

## 16. 성공 지표 (KPI)

| 지표 | 목표 | 측정 방법 |
|------|------|-----------|
| 일일 수익률 | ≥ 5% | 일일 리포트 자동 계산 |
| 일일 스코어 | ≥ 30점 | 스코어링 엔진 산출 |
| 승률 | ≥ 60% | 수익 거래 / 전체 거래 |
| 최대 낙폭 (MDD) | ≤ 10% | 백테스팅 + 실거래 추적 |
| AI 판단 정확도 | ≥ 65% | ai_decision_logs 사후 검증 |
| 시스템 가동률 | ≥ 99.5% | 모니터링 |

---

## 17. 젠스파크 입력용 최종 원스톱 프롬프트

아래 프롬프트를 젠스파크 AI Developer에 그대로 붙여넣으면, 위 PRD 전체를 참고하여 개발을 시작합니다:

```
이 프로젝트는 "AutoTradeX"라는 한국 주식 자동매매 앱입니다.

[기술 스택]
- Backend: Hono (Node.js) + TypeScript
- Frontend: Next.js 14 + React 18 + TailwindCSS
- Database: SQLite (개발) / PostgreSQL (운영)
- 차트: Lightweight Charts (TradingView)
- 배포: Cloudflare Pages

[핵심 기능]
1. 증권사 API 연동 (키움증권 REST API): 로그인, 주문, 잔고조회, 실시간시세
2. AI 기반 종목 선정: 매일 주도 테마 분석 → 후보 20개 → 기술적 분석 → AI 최종 5개 선정
3. 기술적 분석: RSI, MACD, 볼린저밴드, 거래량, 이동평균선, 스토캐스틱, 캔들패턴
4. 자동 매매: 매수(AI 신뢰도 70+일 때) → 모니터링 → 수익 2~25% 구간 극대화 매도 또는 -3% 손절
5. 스코어링: 수익=가산점, 손절=감점, 일일 목표 5% 이상
6. 안전장치: 연속3회 손절 시 30분 대기, 일일-5% 시 거래종료, 단일종목 30% 비중제한
7. 기다림 로직: 적절한 종목/타이밍 없으면 거래하지 않음
8. 대시보드: 실시간 PnL, 포지션, 워치리스트, 거래이력, 리포트, AI 로그
9. 백테스팅: 과거 데이터 기반 전략 검증
10. 알림: 텔레그램/푸시로 매수/매도/손절/리포트 알림
11. 보안: AES-256-GCM API Key 암호화, argon2id 비밀번호 해싱, RS256 JWT, MFA 필수, TLS 1.2+ 강제, 인증서 피닝, 주문 무결성 검증(HMAC), 이상 거래 탐지, Rate Limiting, 감사 로그(audit_logs), 민감정보 로그 마스킹, OWASP API Top 10 대응, 긴급 대응 플로우

위 PRD 문서를 참고하여 Phase 1부터 순차적으로 전체 프로젝트를 구현해주세요.
먼저 프로젝트 구조와 DB 스키마 설계부터 시작합니다.
```

---

충분한 정보를 확보했습니다. 이제 기존 PRD에 추가할 보안 섹션을 빠짐없이 작성하겠습니다.

---

맞는 지적이에요. 돈이 오가는 앱에서 보안 빠뜨린 건 솔직히 큰 실수입니다. 아래에 기존 PRD의 **Section 10(안전장치) 뒤에 삽입할 보안 전용 섹션**을 완성했습니다. 기존 문서에 그대로 붙여넣으면 됩니다.

```markdown
---

