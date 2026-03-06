/**
 * KisBroker — 한국투자증권 UAPI 구현체
 *
 * 참고 API 문서 (Excel):
 *   - OAuth인증.xlsx
 *   - [국내주식] 기본시세.xlsx
 *   - [국내주식] 주문_계좌.xlsx
 *
 * ── TR_ID 목록 ────────────────────────────────────────────────
 * 현재가 조회          FHKST01010100   (실전/모의 동일)
 * 일봉 OHLCV          FHKST03010100   (실전/모의 동일)
 * 호가/예상체결        FHKST01010200   (실전/모의 동일)
 * 잔고조회             실전 TTTC8434R  / 모의 VTTC8434R
 * 매수가능조회         실전 TTTC8908R  / 모의 VTTC8908R
 * 매도가능수량조회     실전 TTTC8408R  / 모의 미지원
 * 현금매수             실전 TTTC0012U  / 모의 VTTC0012U
 * 현금매도             실전 TTTC0011U  / 모의 VTTC0011U
 * 주문정정취소         실전 TTTC0013U  / 모의 VTTC0013U
 * 일별체결조회(3개월내) 실전 TTTC0081R / 모의 VTTC0081R
 * ─────────────────────────────────────────────────────────────
 */

const BaseBroker = require('../base.broker');

// ── KIS 도메인 ────────────────────────────────────────────────
const KIS_BASE_REAL = 'https://openapi.koreainvestment.com:9443';
const KIS_BASE_MOCK = 'https://openapivts.koreainvestment.com:29443';

// ── TR_ID 매핑 ────────────────────────────────────────────────
const TR = {
  PRICE:        { real: 'FHKST01010100', mock: 'FHKST01010100' },
  OHLCV:        { real: 'FHKST03010100', mock: 'FHKST03010100' },
  ORDERBOOK:    { real: 'FHKST01010200', mock: 'FHKST01010200' },
  BALANCE:      { real: 'TTTC8434R',     mock: 'VTTC8434R'     },
  BUYABLE:      { real: 'TTTC8908R',     mock: 'VTTC8908R'     },
  SELLABLE:     { real: 'TTTC8408R',     mock: null             }, // 모의 미지원
  ORDER_BUY:    { real: 'TTTC0012U',     mock: 'VTTC0012U'     },
  ORDER_SELL:   { real: 'TTTC0011U',     mock: 'VTTC0011U'     },
  ORDER_MODIFY: { real: 'TTTC0013U',     mock: 'VTTC0013U'     },
  DAILY_ORDERS: { real: 'TTTC0081R',     mock: 'VTTC0081R'     },
};

class KisBroker extends BaseBroker {
  constructor({ accountNo, isMock }) {
    super({ accountNo, isMock });
    this.base = isMock ? KIS_BASE_MOCK : KIS_BASE_REAL;
  }

  // ── 내부 헬퍼: TR_ID 선택 ──────────────────────────────────
  _trId(key) {
    const entry = TR[key];
    if (!entry) throw new Error(`알 수 없는 TR 키: ${key}`);
    const id = this.isMock ? entry.mock : entry.real;
    if (!id) throw new Error(`${key} TR_ID는 ${this.isMock ? '모의투자' : '실전투자'} 미지원`);
    return id;
  }

  // ── 내부 헬퍼: 공통 헤더 ──────────────────────────────────
  _headers(accessToken, appKey, appSecret, trId, extra = {}) {
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': `Bearer ${accessToken}`,
      'appkey':     appKey,
      'appsecret':  appSecret,
      'tr_id':      trId,
      'custtype':   'P',
      ...extra,
    };
  }

  // ── 내부 헬퍼: 계좌번호 분리 ──────────────────────────────
  // KIS 계좌번호 체계: 앞 8자리(CANO) + 뒤 2자리(ACNT_PRDT_CD)
  _splitAccountNo() {
    const no = this.accountNo.replace(/-/g, '');
    return {
      cano:       no.slice(0, 8),
      acntPrdtCd: no.slice(8) || '01',
    };
  }

  // ── 인증: 토큰 발급 ───────────────────────────────────────
  async fetchToken({ appKey, appSecret }) {
    const resp = await fetch(`${this.base}/oauth2/tokenP`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        grant_type: 'client_credentials',
        appkey:     appKey,
        appsecret:  appSecret,
      }),
    });
    if (!resp.ok) {
      const txt = await resp.text();
      throw new Error(`KIS 토큰 발급 실패 [${resp.status}]: ${txt}`);
    }
    const d = await resp.json();
    return {
      accessToken: d.access_token,
      expiresAt:   new Date(d.access_token_token_expired).toISOString(),
      tokenType:   d.token_type || 'Bearer',
    };
  }

  // ── 인증: 토큰 폐기 ───────────────────────────────────────
  async revokeToken({ accessToken, appKey, appSecret }) {
    await fetch(`${this.base}/oauth2/revokeP`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ appkey: appKey, appsecret: appSecret, token: accessToken }),
    }).catch(() => {}); // 폐기 실패는 무시
  }

  // ── Hashkey 생성 (POST 주문 보안용, 선택적) ────────────────
  async _generateHashkey(body, appKey, appSecret) {
    try {
      const resp = await fetch(`${this.base}/uapi/hashkey`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'appkey':    appKey,
          'appsecret': appSecret,
        },
        body: JSON.stringify(body),
      });
      const d = await resp.json();
      return d.HASH || '';
    } catch {
      return '';
    }
  }

  // ── 현재가 조회 ───────────────────────────────────────────
  async getCurrentPrice({ accessToken, appKey, appSecret, code }) {
    const params = new URLSearchParams({
      FID_COND_MRKT_DIV_CODE: 'J',
      FID_INPUT_ISCD: code,
    });
    const resp = await fetch(
      `${this.base}/uapi/domestic-stock/v1/quotations/inquire-price?${params}`,
      { headers: this._headers(accessToken, appKey, appSecret, this._trId('PRICE')) }
    );
    if (!resp.ok) throw new Error(`현재가 조회 실패 [${resp.status}]`);
    const d = await resp.json();
    if (d.rt_cd !== '0') throw new Error(`현재가 API 오류: ${d.msg1}`);
    const o = d.output || {};
    return {
      code,
      name:           o.hts_kor_isnm  || '',
      currentPrice:   parseInt(o.stck_prpr  || 0),
      openPrice:      parseInt(o.stck_oprc  || 0),
      highPrice:      parseInt(o.stck_hgpr  || 0),
      lowPrice:       parseInt(o.stck_lwpr  || 0),
      prevClosePrice: parseInt(o.stck_sdpr  || 0),
      changeRate:     parseFloat(o.prdy_ctrt  || 0),
      changeAmount:   parseInt(o.prdy_vrss   || 0),
      volume:         parseInt(o.acml_vol    || 0),
      tradingValue:   parseInt(o.acml_tr_pbmn || 0),
      per:            parseFloat(o.per || 0),
      pbr:            parseFloat(o.pbr || 0),
      isMock:         this.isMock,
    };
  }

  // ── 일봉 OHLCV 조회 ───────────────────────────────────────
  async getDailyOhlcv({ accessToken, appKey, appSecret, code, days = 60 }) {
    const endDate   = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const startDate = new Date(Date.now() - days * 86400000)
      .toISOString().slice(0, 10).replace(/-/g, '');

    const params = new URLSearchParams({
      fid_cond_mrkt_div_code: 'J',
      fid_input_iscd:         code,
      fid_input_date_1:       startDate,
      fid_input_date_2:       endDate,
      fid_period_div_code:    'D',
      fid_org_adj_prc:        '0',
    });
    const resp = await fetch(
      `${this.base}/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice?${params}`,
      { headers: this._headers(accessToken, appKey, appSecret, this._trId('OHLCV')) }
    );
    if (!resp.ok) throw new Error(`OHLCV 조회 실패 [${resp.status}]`);
    const d = await resp.json();
    if (d.rt_cd !== '0') throw new Error(`OHLCV API 오류: ${d.msg1}`);
    return (d.output2 || []).map(o => ({
      date:   o.stck_bsop_date,
      open:   parseInt(o.stck_oprc || 0),
      high:   parseInt(o.stck_hgpr || 0),
      low:    parseInt(o.stck_lwpr || 0),
      close:  parseInt(o.stck_clpr || 0),
      volume: parseInt(o.acml_vol  || 0),
    })).reverse();
  }

  // ── 호가 조회 ─────────────────────────────────────────────
  async getOrderbook({ accessToken, appKey, appSecret, code }) {
    const params = new URLSearchParams({
      FID_COND_MRKT_DIV_CODE: 'J',
      FID_INPUT_ISCD: code,
    });
    const resp = await fetch(
      `${this.base}/uapi/domestic-stock/v1/quotations/inquire-asking-price-exp-ccn?${params}`,
      { headers: this._headers(accessToken, appKey, appSecret, this._trId('ORDERBOOK')) }
    );
    if (!resp.ok) throw new Error(`호가 조회 실패 [${resp.status}]`);
    const d = await resp.json();
    if (d.rt_cd !== '0') throw new Error(`호가 API 오류: ${d.msg1}`);
    const o = d.output1 || {};
    return {
      code,
      asks: [1,2,3,4,5].map(i => ({
        price:    parseInt(o[`askp${i}`]      || 0),
        quantity: parseInt(o[`askp_rsqn${i}`] || 0),
      })).filter(a => a.price > 0),
      bids: [1,2,3,4,5].map(i => ({
        price:    parseInt(o[`bidp${i}`]      || 0),
        quantity: parseInt(o[`bidp_rsqn${i}`] || 0),
      })).filter(b => b.price > 0),
      isMock: this.isMock,
    };
  }

  // ── 잔고/예수금 조회 ──────────────────────────────────────
  async getBalance({ accessToken, appKey, appSecret }) {
    const { cano, acntPrdtCd } = this._splitAccountNo();
    const params = new URLSearchParams({
      CANO: cano, ACNT_PRDT_CD: acntPrdtCd,
      AFHR_FLPR_YN: 'N', OFL_YN: '', INQR_DVSN: '02',
      UNPR_DVSN: '01', FUND_STTL_ICLD_YN: 'N',
      FNCG_AMT_AUTO_RDPT_YN: 'N', PRCS_DVSN: '01',
      CTX_AREA_FK100: '', CTX_AREA_NK100: '',
    });
    const resp = await fetch(
      `${this.base}/uapi/domestic-stock/v1/trading/inquire-balance?${params}`,
      { headers: this._headers(accessToken, appKey, appSecret, this._trId('BALANCE')) }
    );
    if (!resp.ok) throw new Error(`잔고 조회 실패 [${resp.status}]`);
    const d = await resp.json();
    if (d.rt_cd !== '0') throw new Error(`잔고 API 오류: ${d.msg1}`);
    const o2 = (d.output2 || [])[0] || {};
    return {
      availableCash:  parseInt(o2.dnca_tot_amt        || 0), // 예수금 총금액
      totalBalance:   parseInt(o2.tot_evlu_amt         || 0), // 총평가금액
      purchaseAmount: parseInt(o2.pchs_amt_smtl_amt    || 0), // 매입금액합계
      evalProfitLoss: parseInt(o2.evlu_pfls_smtl_amt   || 0), // 평가손익합계
      isMock:         this.isMock,
    };
  }

  // ── 매수 가능 금액/수량 조회 ──────────────────────────────
  // 현금 매매이므로 nrcvb_buy_amt(미수없는매수금액) 사용
  async getBuyableAmount({ accessToken, appKey, appSecret, code = '', price = '', ordDvsn = '01' }) {
    const { cano, acntPrdtCd } = this._splitAccountNo();
    const params = new URLSearchParams({
      CANO: cano, ACNT_PRDT_CD: acntPrdtCd,
      PDNO: code, ORD_UNPR: price, ORD_DVSN: ordDvsn,
      CMA_EVLU_AMT_ICLD_YN: 'N', OVRS_ICLD_YN: 'N',
    });
    const resp = await fetch(
      `${this.base}/uapi/domestic-stock/v1/trading/inquire-psbl-order?${params}`,
      { headers: this._headers(accessToken, appKey, appSecret, this._trId('BUYABLE')) }
    );
    if (!resp.ok) throw new Error(`매수가능 조회 실패 [${resp.status}]`);
    const d = await resp.json();
    if (d.rt_cd !== '0') throw new Error(`매수가능 API 오류: ${d.msg1}`);
    const o = d.output || {};
    return {
      availableCash: parseInt(o.ord_psbl_cash   || 0), // 예수금 기준 주문가능금액
      buyableAmount: parseInt(o.nrcvb_buy_amt    || 0), // 미수없는 매수금액 (현금만 사용)
      buyableQty:    parseInt(o.nrcvb_buy_qty    || 0), // 미수없는 매수수량
      isMock:        this.isMock,
    };
  }

  // ── 매도 가능 수량 조회 (모의투자 미지원) ─────────────────
  async getSellableQty({ accessToken, appKey, appSecret, code }) {
    if (this.isMock) {
      // 모의투자: TR 미지원 → 잔고조회에서 해당 종목 찾기
      return { sellableQty: 0, avgBuyPrice: 0, currentPrice: 0, isMock: true };
    }
    const { cano, acntPrdtCd } = this._splitAccountNo();
    const params = new URLSearchParams({
      CANO: cano, ACNT_PRDT_CD: acntPrdtCd, PDNO: code,
    });
    const resp = await fetch(
      `${this.base}/uapi/domestic-stock/v1/trading/inquire-psbl-sell?${params}`,
      { headers: this._headers(accessToken, appKey, appSecret, this._trId('SELLABLE')) }
    );
    if (!resp.ok) throw new Error(`매도가능 조회 실패 [${resp.status}]`);
    const d = await resp.json();
    if (d.rt_cd !== '0') throw new Error(`매도가능 API 오류: ${d.msg1}`);
    const o = d.output1 || {};
    return {
      sellableQty:  parseInt(o.ord_psbl_qty  || 0),
      avgBuyPrice:  parseFloat(o.pchs_avg_pric || 0),
      currentPrice: parseInt(o.now_pric       || 0),
      isMock:       false,
    };
  }

  // ── 현금 주문 (매수/매도) ─────────────────────────────────
  // ordDvsn: '00'=지정가, '01'=시장가 (기본: 지정가)
  async placeOrder({ accessToken, appKey, appSecret, code, orderType, quantity, price, ordDvsn = '00' }) {
    const { cano, acntPrdtCd } = this._splitAccountNo();
    const isBuy = orderType === 'BUY';
    const trId  = this._trId(isBuy ? 'ORDER_BUY' : 'ORDER_SELL');

    const body = {
      CANO:         cano,
      ACNT_PRDT_CD: acntPrdtCd,
      PDNO:         code,
      ORD_DVSN:     ordDvsn,
      ORD_QTY:      String(quantity),
      ORD_UNPR:     ordDvsn === '01' ? '0' : String(price), // 시장가는 '0'
    };
    // 매도 시 SLL_TYPE 추가 (01: 일반매도)
    if (!isBuy) body.SLL_TYPE = '01';

    const hashkey = await this._generateHashkey(body, appKey, appSecret);
    const resp = await fetch(
      `${this.base}/uapi/domestic-stock/v1/trading/order-cash`,
      {
        method: 'POST',
        headers: this._headers(accessToken, appKey, appSecret, trId, { hashkey }),
        body: JSON.stringify(body),
      }
    );
    if (!resp.ok) throw new Error(`주문 실패 [${resp.status}]`);
    const d = await resp.json();
    if (d.rt_cd !== '0') throw new Error(`주문 API 오류: ${d.msg1}`);
    const out = d.output || {};
    return {
      orderId:   out.ODNO     || String(Date.now()),
      branchNo:  out.KRX_FWDG_ORD_ORGNO || '',
      orderTime: out.ORD_TMD  || '',
      isMock:    this.isMock,
    };
  }

  // ── 주문 정정/취소 ────────────────────────────────────────
  // rvseOrCncl: '01'=정정, '02'=취소
  async modifyOrCancelOrder({
    accessToken, appKey, appSecret,
    orgOrderId, branchNo, rvseOrCncl = '02',
    qty, price = '0', ordDvsn = '00',
  }) {
    const { cano, acntPrdtCd } = this._splitAccountNo();
    const body = {
      CANO:               cano,
      ACNT_PRDT_CD:       acntPrdtCd,
      KRX_FWDG_ORD_ORGNO: branchNo,
      ORGN_ODNO:          orgOrderId,
      ORD_DVSN:           ordDvsn,
      RVSE_CNCL_DVSN_CD:  rvseOrCncl,
      ORD_QTY:            String(qty),
      ORD_UNPR:           String(price),
      QTY_ALL_ORD_YN:     'Y', // 잔량 전부
    };
    const hashkey = await this._generateHashkey(body, appKey, appSecret);
    const resp = await fetch(
      `${this.base}/uapi/domestic-stock/v1/trading/order-rvsecncl`,
      {
        method: 'POST',
        headers: this._headers(accessToken, appKey, appSecret, this._trId('ORDER_MODIFY'), { hashkey }),
        body: JSON.stringify(body),
      }
    );
    if (!resp.ok) throw new Error(`정정/취소 실패 [${resp.status}]`);
    const d = await resp.json();
    if (d.rt_cd !== '0') throw new Error(`정정/취소 API 오류: ${d.msg1}`);
    const out = d.output || {};
    return { orderId: out.ODNO || '', isMock: this.isMock };
  }

  // ── 일별 주문 체결 조회 (3개월 이내) ─────────────────────
  async getDailyOrders({
    accessToken, appKey, appSecret,
    startDate, endDate,
    sllBuyDvsnCd = '00', // '00'=전체, '01'=매도, '02'=매수
  }) {
    const { cano, acntPrdtCd } = this._splitAccountNo();
    const params = new URLSearchParams({
      CANO: cano, ACNT_PRDT_CD: acntPrdtCd,
      INQR_STRT_DT:      startDate,
      INQR_END_DT:        endDate,
      SLL_BUY_DVSN_CD:    sllBuyDvsnCd,
      INQR_DVSN:          '00', // 역순
      PDNO:               '',
      CCLD_DVSN:          '01', // 체결만
      ORD_GNO_BRNO:       '',
      ODNO:               '',
      INQR_DVSN_1:        '',
      INQR_DVSN_3:        '01', // 현금만
      EXCG_ID_DVSN_CD:    'KRX',
      CTX_AREA_FK100:     '',
      CTX_AREA_NK100:     '',
    });
    const resp = await fetch(
      `${this.base}/uapi/domestic-stock/v1/trading/inquire-daily-ccld?${params}`,
      { headers: this._headers(accessToken, appKey, appSecret, this._trId('DAILY_ORDERS')) }
    );
    if (!resp.ok) throw new Error(`일별체결 조회 실패 [${resp.status}]`);
    const d = await resp.json();
    if (d.rt_cd !== '0') throw new Error(`일별체결 API 오류: ${d.msg1}`);
    return (d.output1 || []).map(o => ({
      orderId:   o.odno,
      code:      o.pdno,
      name:      o.prdt_name,
      orderType: o.sll_buy_dvsn_cd === '01' ? 'SELL' : 'BUY',
      ordQty:    parseInt(o.ord_qty    || 0),
      ordPrice:  parseInt(o.ord_unpr   || 0),
      execQty:   parseInt(o.tot_ccld_qty || 0),
      execPrice: parseInt(o.avg_prvs   || 0),
      status:    o.ord_stts === '체결' ? 'FILLED' : 'CANCELLED',
      ordTime:   o.ord_tmd,
    }));
  }
}

module.exports = KisBroker;
