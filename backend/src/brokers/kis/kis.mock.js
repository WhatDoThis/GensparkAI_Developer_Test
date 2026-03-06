/**
 * KIS Mock Data Factory
 * 개발/테스트 환경에서 KIS API 없이도 동작하는 목업 데이터 생성
 * 실전 API 실패 시 폴백으로도 사용
 */

const MOCK_NAMES = {
  '005930': '삼성전자',  '000660': 'SK하이닉스', '035420': 'NAVER',
  '035720': '카카오',    '005380': '현대차',     '051910': 'LG화학',
  '006400': '삼성SDI',   '028260': '삼성물산',   '068270': '셀트리온',
  '207940': '삼성바이오로직스', '000270': '기아',   '105560': 'KB금융',
  '055550': '신한지주',  '316140': '우리금융',   '086790': '하나금융',
  '003550': 'LG',       '018260': '삼성에스디에스', '009150': '삼성전기',
  '066570': 'LG전자',   '032830': '삼성생명',
};

/** 종목코드 기반 시드 → 결정론적 가격 생성 */
function _seed(code) {
  return code.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
}

function stockPrice(code) {
  const seed = _seed(code);
  const base = 10000 + (seed % 90000);
  const change = (Math.random() - 0.5) * base * 0.04;
  const current = Math.round(base + change);
  return {
    code,
    name:           MOCK_NAMES[code] || `종목${code}`,
    currentPrice:   current,
    openPrice:      Math.round(base * 0.998),
    highPrice:      Math.round(base * 1.02),
    lowPrice:       Math.round(base * 0.97),
    prevClosePrice: base,
    changeRate:     parseFloat((change / base * 100).toFixed(2)),
    changeAmount:   Math.round(change),
    volume:         Math.round(Math.random() * 1000000 + 100000),
    tradingValue:   Math.round(current * (Math.random() * 1000000 + 100000)),
    per:            parseFloat((10 + Math.random() * 20).toFixed(1)),
    pbr:            parseFloat((0.5 + Math.random() * 3).toFixed(2)),
    isMock:         true,
  };
}

function dailyOhlcv(code, days = 60) {
  const seed = _seed(code);
  let price = 10000 + (seed % 90000);
  const result = [];
  for (let i = days; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const dateStr = d.toISOString().slice(0, 10).replace(/-/g, '');
    const change = (Math.random() - 0.48) * price * 0.03;
    const open  = Math.round(price);
    const close = Math.round(price + change);
    const high  = Math.round(Math.max(open, close) * (1 + Math.random() * 0.01));
    const low   = Math.round(Math.min(open, close) * (1 - Math.random() * 0.01));
    result.push({ date: dateStr, open, high, low, close, volume: Math.round(Math.random() * 500000 + 50000) });
    price = close;
  }
  return result;
}

function orderbook(code) {
  const p = stockPrice(code).currentPrice;
  return {
    code,
    asks: Array.from({ length: 5 }, (_, i) => ({
      price:    Math.round(p * (1 + (i + 1) * 0.001)),
      quantity: Math.round(Math.random() * 5000 + 100),
    })),
    bids: Array.from({ length: 5 }, (_, i) => ({
      price:    Math.round(p * (1 - (i + 1) * 0.001)),
      quantity: Math.round(Math.random() * 5000 + 100),
    })),
    isMock: true,
  };
}

function balance() {
  return {
    availableCash:  10000000,
    totalBalance:   12000000,
    purchaseAmount:  2000000,
    evalProfitLoss:   100000,
    isMock: true,
  };
}

function buyableAmount() {
  return { availableCash: 10000000, buyableAmount: 10000000, buyableQty: 0, isMock: true };
}

function placeOrder({ code, orderType, quantity, price }) {
  return {
    orderId:   `MOCK_${Date.now()}`,
    branchNo:  '00000',
    orderTime: new Date().toTimeString().slice(0, 8).replace(/:/g, ''),
    isMock:    true,
    // 목업은 즉시 체결 처리
    filledQty:   quantity,
    filledPrice: price,
  };
}

const DEFAULT_POOL = Object.keys(MOCK_NAMES);

module.exports = { stockPrice, dailyOhlcv, orderbook, balance, buyableAmount, placeOrder, DEFAULT_POOL, MOCK_NAMES };
