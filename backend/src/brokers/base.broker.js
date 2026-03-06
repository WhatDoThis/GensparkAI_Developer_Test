/**
 * BaseBroker — 증권사 브로커 공통 인터페이스
 *
 * 새로운 증권사를 추가할 때 이 클래스를 상속받아 구현하세요.
 * 예: class KiwoomBroker extends BaseBroker { ... }
 *
 * ──────────────────────────────────────────────────────────────
 * 현재 구현체: KisBroker (한국투자증권)
 * 추후 추가 예정: KiwoomBroker (키움증권), etc.
 * ──────────────────────────────────────────────────────────────
 */

class BaseBroker {
  constructor({ accountNo, isMock }) {
    if (new.target === BaseBroker) {
      throw new Error('BaseBroker는 직접 인스턴스화할 수 없습니다. 구현체를 사용하세요.');
    }
    this.accountNo = accountNo;
    this.isMock = !!isMock;
  }

  // ── 인증 ──────────────────────────────────────────────────

  /**
   * OAuth 액세스 토큰 발급
   * @param {{ appKey: string, appSecret: string }} credentials
   * @returns {Promise<{ accessToken: string, expiresAt: string, tokenType: string }>}
   */
  async fetchToken(credentials) {
    throw new Error(`${this.constructor.name}.fetchToken() 미구현`);
  }

  /**
   * 액세스 토큰 폐기
   * @param {{ accessToken: string, appKey: string, appSecret: string }} params
   * @returns {Promise<void>}
   */
  async revokeToken(params) {
    throw new Error(`${this.constructor.name}.revokeToken() 미구현`);
  }

  // ── 시세 ──────────────────────────────────────────────────

  /**
   * 주식 현재가 조회
   * @param {{ accessToken: string, appKey: string, appSecret: string, code: string }} params
   * @returns {Promise<StockPrice>}
   */
  async getCurrentPrice(params) {
    throw new Error(`${this.constructor.name}.getCurrentPrice() 미구현`);
  }

  /**
   * 일봉 OHLCV 조회 (기술적 지표 계산용)
   * @param {{ accessToken: string, appKey: string, appSecret: string, code: string, days: number }} params
   * @returns {Promise<OhlcvBar[]>}
   */
  async getDailyOhlcv(params) {
    throw new Error(`${this.constructor.name}.getDailyOhlcv() 미구현`);
  }

  /**
   * 호가 조회
   * @param {{ accessToken: string, appKey: string, appSecret: string, code: string }} params
   * @returns {Promise<Orderbook>}
   */
  async getOrderbook(params) {
    throw new Error(`${this.constructor.name}.getOrderbook() 미구현`);
  }

  // ── 계좌 ──────────────────────────────────────────────────

  /**
   * 계좌 잔고 / 예수금 조회
   * @param {{ accessToken: string, appKey: string, appSecret: string }} params
   * @returns {Promise<{ availableCash: number, totalBalance: number, purchaseAmount: number }>}
   */
  async getBalance(params) {
    throw new Error(`${this.constructor.name}.getBalance() 미구현`);
  }

  /**
   * 매수 가능 금액/수량 조회
   * @param {{ accessToken: string, appKey: string, appSecret: string, code: string, price: string, ordDvsn: string }} params
   * @returns {Promise<{ availableCash: number, buyableAmount: number, buyableQty: number }>}
   */
  async getBuyableAmount(params) {
    throw new Error(`${this.constructor.name}.getBuyableAmount() 미구현`);
  }

  /**
   * 매도 가능 수량 조회
   * @param {{ accessToken: string, appKey: string, appSecret: string, code: string }} params
   * @returns {Promise<{ sellableQty: number, avgBuyPrice: number, currentPrice: number }>}
   */
  async getSellableQty(params) {
    throw new Error(`${this.constructor.name}.getSellableQty() 미구현`);
  }

  // ── 주문 ──────────────────────────────────────────────────

  /**
   * 현금 주문 (매수/매도)
   * @param {{ accessToken: string, appKey: string, appSecret: string, code: string,
   *           orderType: 'BUY'|'SELL', quantity: number, price: number, ordDvsn: string }} params
   * @returns {Promise<{ orderId: string, status: string }>}
   */
  async placeOrder(params) {
    throw new Error(`${this.constructor.name}.placeOrder() 미구현`);
  }

  /**
   * 주문 정정/취소
   * @param {{ accessToken: string, appKey: string, appSecret: string, orgOrderId: string,
   *           branchNo: string, rvseOrCncl: 'RVSE'|'CNCL', qty: number, price: number }} params
   * @returns {Promise<{ orderId: string }>}
   */
  async modifyOrCancelOrder(params) {
    throw new Error(`${this.constructor.name}.modifyOrCancelOrder() 미구현`);
  }

  /**
   * 일별 주문 체결 조회
   * @param {{ accessToken: string, appKey: string, appSecret: string,
   *           startDate: string, endDate: string, sllBuyDvsnCd: string }} params
   * @returns {Promise<OrderExecution[]>}
   */
  async getDailyOrders(params) {
    throw new Error(`${this.constructor.name}.getDailyOrders() 미구현`);
  }
}

/**
 * @typedef {Object} StockPrice
 * @property {string} code
 * @property {string} name
 * @property {number} currentPrice
 * @property {number} openPrice
 * @property {number} highPrice
 * @property {number} lowPrice
 * @property {number} prevClosePrice
 * @property {number} changeRate
 * @property {number} changeAmount
 * @property {number} volume
 * @property {boolean} isMock
 */

/**
 * @typedef {Object} OhlcvBar
 * @property {string} date   YYYYMMDD
 * @property {number} open
 * @property {number} high
 * @property {number} low
 * @property {number} close
 * @property {number} volume
 */

/**
 * @typedef {Object} Orderbook
 * @property {string} code
 * @property {{ price: number, quantity: number }[]} asks  매도호가
 * @property {{ price: number, quantity: number }[]} bids  매수호가
 * @property {boolean} isMock
 */

/**
 * @typedef {Object} OrderExecution
 * @property {string} orderId
 * @property {string} code
 * @property {string} name
 * @property {string} orderType  'BUY'|'SELL'
 * @property {number} ordQty
 * @property {number} ordPrice
 * @property {number} execQty
 * @property {number} execPrice
 * @property {string} status     'FILLED'|'PARTIAL'|'CANCELLED'|'PENDING'
 * @property {string} ordTime    HHmmss
 */

module.exports = BaseBroker;
