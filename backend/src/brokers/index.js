/**
 * Broker Factory — 브로커 인스턴스 생성/관리
 *
 * 현재 지원: 'kis' (한국투자증권)
 * 추후 추가 예시:
 *   case 'kiwoom': return new KiwoomBroker({ accountNo, isMock });
 *   case 'samsung': return new SamsungBroker({ accountNo, isMock });
 */

const KisBroker = require('./kis/kis.broker');

/**
 * 브로커 식별자 목록 (지원 예정 포함)
 * 새 증권사 추가 시 여기에만 등록하면 됩니다.
 */
const SUPPORTED_BROKERS = {
  kis: { name: '한국투자증권', implemented: true },
  // kiwoom: { name: '키움증권', implemented: false },
  // samsung: { name: '삼성증권', implemented: false },
};

/**
 * 브로커 인스턴스 생성
 * @param {string} brokerKey  - 'kis' 등
 * @param {{ accountNo: string, isMock: boolean }} options
 * @returns {BaseBroker}
 */
function createBroker(brokerKey, { accountNo, isMock }) {
  const meta = SUPPORTED_BROKERS[brokerKey];
  if (!meta) {
    throw new Error(`지원하지 않는 브로커: ${brokerKey}`);
  }
  if (!meta.implemented) {
    throw new Error(`${meta.name}은 아직 구현되지 않았습니다`);
  }

  switch (brokerKey) {
    case 'kis':
      return new KisBroker({ accountNo, isMock });
    default:
      throw new Error(`브로커 팩토리 미구현: ${brokerKey}`);
  }
}

/** 현재 구현된 브로커 목록 */
function getImplementedBrokers() {
  return Object.entries(SUPPORTED_BROKERS)
    .filter(([, v]) => v.implemented)
    .map(([k, v]) => ({ key: k, name: v.name }));
}

module.exports = { createBroker, getImplementedBrokers, SUPPORTED_BROKERS };
