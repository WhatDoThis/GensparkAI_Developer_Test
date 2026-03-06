/**
 * Technical Indicators Engine
 * Q1: 현실적인 수익 목표 기준 데이터 생성
 * RSI, MACD, 볼린저밴드, 스토캐스틱, 이동평균
 */

// ── 이동평균 ──────────────────────────────────────────────
function sma(closes, period) {
  if (closes.length < period) return null;
  const slice = closes.slice(-period);
  return slice.reduce((a, b) => a + b, 0) / period;
}

function ema(closes, period) {
  if (closes.length < period) return null;
  const k = 2 / (period + 1);
  let emaVal = closes.slice(0, period).reduce((a, b) => a + b, 0) / period;
  for (let i = period; i < closes.length; i++) {
    emaVal = closes[i] * k + emaVal * (1 - k);
  }
  return emaVal;
}

// ── RSI ───────────────────────────────────────────────────
function rsi(closes, period = 14) {
  if (closes.length < period + 1) return null;
  let gains = 0, losses = 0;
  for (let i = closes.length - period; i < closes.length; i++) {
    const diff = closes[i] - closes[i - 1];
    if (diff > 0) gains += diff;
    else losses -= diff;
  }
  const avgGain = gains / period;
  const avgLoss = losses / period;
  if (avgLoss === 0) return 100;
  const rs = avgGain / avgLoss;
  return parseFloat((100 - 100 / (1 + rs)).toFixed(2));
}

// ── MACD ──────────────────────────────────────────────────
function macd(closes, fast = 12, slow = 26, signal = 9) {
  if (closes.length < slow + signal) return null;
  const fastEma = ema(closes, fast);
  const slowEma = ema(closes, slow);
  if (!fastEma || !slowEma) return null;
  const macdLine = fastEma - slowEma;

  // Signal line: EMA of MACD values (simplified)
  const macdValues = [];
  for (let i = slow; i <= closes.length; i++) {
    const fe = ema(closes.slice(0, i), fast);
    const se = ema(closes.slice(0, i), slow);
    if (fe && se) macdValues.push(fe - se);
  }
  const signalLine = ema(macdValues, signal);
  const histogram = signalLine ? macdLine - signalLine : null;

  return {
    macd: parseFloat(macdLine.toFixed(2)),
    signal: signalLine ? parseFloat(signalLine.toFixed(2)) : null,
    histogram: histogram ? parseFloat(histogram.toFixed(2)) : null,
    crossover: histogram !== null ? (histogram > 0 ? 'BULLISH' : 'BEARISH') : null,
  };
}

// ── 볼린저밴드 ────────────────────────────────────────────
function bollingerBands(closes, period = 20, stdDev = 2) {
  if (closes.length < period) return null;
  const slice = closes.slice(-period);
  const mid = slice.reduce((a, b) => a + b, 0) / period;
  const variance = slice.reduce((sum, v) => sum + Math.pow(v - mid, 2), 0) / period;
  const std = Math.sqrt(variance);
  const upper = mid + stdDev * std;
  const lower = mid - stdDev * std;
  const current = closes[closes.length - 1];
  const bandwidth = ((upper - lower) / mid) * 100;
  const pctB = lower === upper ? 0.5 : (current - lower) / (upper - lower);

  return {
    upper: parseFloat(upper.toFixed(0)),
    middle: parseFloat(mid.toFixed(0)),
    lower: parseFloat(lower.toFixed(0)),
    bandwidth: parseFloat(bandwidth.toFixed(2)),
    pctB: parseFloat(pctB.toFixed(3)),
    signal: pctB < 0.2 ? 'OVERSOLD' : pctB > 0.8 ? 'OVERBOUGHT' : 'NEUTRAL',
  };
}

// ── 스토캐스틱 ────────────────────────────────────────────
function stochastic(highs, lows, closes, kPeriod = 14, dPeriod = 3) {
  if (closes.length < kPeriod) return null;
  const slice_h = highs.slice(-kPeriod);
  const slice_l = lows.slice(-kPeriod);
  const current = closes[closes.length - 1];
  const highestHigh = Math.max(...slice_h);
  const lowestLow = Math.min(...slice_l);
  const k = highestHigh === lowestLow ? 50
    : ((current - lowestLow) / (highestHigh - lowestLow)) * 100;

  // D line: 최근 3개 K의 평균 (simplified)
  const kValues = [];
  for (let i = kPeriod; i <= closes.length; i++) {
    const hh = Math.max(...highs.slice(i - kPeriod, i));
    const ll = Math.min(...lows.slice(i - kPeriod, i));
    const c = closes[i - 1];
    kValues.push(hh === ll ? 50 : ((c - ll) / (hh - ll)) * 100);
  }
  const d = kValues.length >= dPeriod
    ? kValues.slice(-dPeriod).reduce((a, b) => a + b, 0) / dPeriod
    : k;

  return {
    k: parseFloat(k.toFixed(2)),
    d: parseFloat(d.toFixed(2)),
    signal: k < 20 ? 'OVERSOLD' : k > 80 ? 'OVERBOUGHT' : 'NEUTRAL',
  };
}

// ── 거래량 분석 ───────────────────────────────────────────
function volumeAnalysis(volumes, current) {
  if (volumes.length < 5) return null;
  const avgVol = volumes.slice(-20).reduce((a, b) => a + b, 0) / Math.min(volumes.length, 20);
  const ratio = current / avgVol;
  return {
    avgVolume: Math.round(avgVol),
    currentVolume: current,
    ratio: parseFloat(ratio.toFixed(2)),
    signal: ratio > 2 ? 'SURGE' : ratio > 1.5 ? 'HIGH' : ratio < 0.5 ? 'LOW' : 'NORMAL',
  };
}

// ── 전체 지표 계산 ────────────────────────────────────────
function calculateAll(ohlcvList) {
  if (!ohlcvList || ohlcvList.length < 20) return null;

  const closes = ohlcvList.map(d => d.close);
  const highs = ohlcvList.map(d => d.high);
  const lows = ohlcvList.map(d => d.low);
  const volumes = ohlcvList.map(d => d.volume);
  const current = closes[closes.length - 1];

  const rsiVal = rsi(closes);
  const macdVal = macd(closes);
  const bbVal = bollingerBands(closes);
  const stochVal = stochastic(highs, lows, closes);
  const volVal = volumeAnalysis(volumes, volumes[volumes.length - 1]);
  const ma5 = sma(closes, 5);
  const ma20 = sma(closes, 20);
  const ma60 = sma(closes, 60);
  const ema12 = ema(closes, 12);

  // 복합 신호 점수 계산 (0~100)
  let score = 50;
  const signals = [];

  if (rsiVal !== null) {
    if (rsiVal < 30) { score += 15; signals.push('RSI 과매도(매수신호)'); }
    else if (rsiVal > 70) { score -= 15; signals.push('RSI 과매수(매도신호)'); }
    else if (rsiVal < 45) { score += 7; }
    else if (rsiVal > 55) { score -= 7; }
  }

  if (macdVal?.crossover === 'BULLISH') { score += 12; signals.push('MACD 골든크로스'); }
  else if (macdVal?.crossover === 'BEARISH') { score -= 12; signals.push('MACD 데드크로스'); }

  if (bbVal) {
    if (bbVal.signal === 'OVERSOLD') { score += 10; signals.push('볼린저밴드 하단(반등 가능)'); }
    else if (bbVal.signal === 'OVERBOUGHT') { score -= 10; signals.push('볼린저밴드 상단(조정 가능)'); }
  }

  if (stochVal) {
    if (stochVal.signal === 'OVERSOLD' && stochVal.k > stochVal.d) { score += 8; signals.push('스토캐스틱 과매도 반전'); }
    else if (stochVal.signal === 'OVERBOUGHT' && stochVal.k < stochVal.d) { score -= 8; signals.push('스토캐스틱 과매수 반전'); }
  }

  if (ma5 && ma20) {
    if (ma5 > ma20 && current > ma20) { score += 8; signals.push('단기 이평 상승 배열'); }
    else if (ma5 < ma20) { score -= 8; signals.push('단기 이평 하락 배열'); }
  }

  if (volVal?.signal === 'SURGE') { score += 5; signals.push('거래량 급증'); }

  score = Math.max(0, Math.min(100, Math.round(score)));

  return {
    current,
    score,
    signals,
    rsi: rsiVal,
    macd: macdVal,
    bollingerBands: bbVal,
    stochastic: stochVal,
    volume: volVal,
    movingAverages: {
      ma5: ma5 ? Math.round(ma5) : null,
      ma20: ma20 ? Math.round(ma20) : null,
      ma60: ma60 ? Math.round(ma60) : null,
      ema12: ema12 ? Math.round(ema12) : null,
    },
    trend: score >= 65 ? 'BULLISH' : score <= 35 ? 'BEARISH' : 'SIDEWAYS',
  };
}

module.exports = { calculateAll, rsi, macd, bollingerBands, stochastic, sma, ema };
