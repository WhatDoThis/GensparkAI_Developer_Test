// lib/providers/trading_provider.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/stock_model.dart';
import '../services/trading/trading_api_service.dart';

class TradingProvider extends ChangeNotifier {
  AccountInfo? _account;
  AccountInfo? get account => _account;

  List<WatchStock> _watchlist = [];
  List<WatchStock> get watchlist => _watchlist;
  List<WatchStock> get buyRecommended =>
      _watchlist.where((s) => s.recommendation == Recommendation.buy).toList();

  List<Position> _positions = [];
  List<Position> get positions => _positions;

  List<Trade> _trades = [];
  List<Trade> get trades => _trades;
  List<Trade> get recentTrades => _trades.take(10).toList();

  List<DailyReport> _reports = [];
  List<DailyReport> get reports => _reports;
  DailyReport? get todayReport => _reports.isNotEmpty ? _reports.first : null;

  List<PnlPoint> _pnlHistory = [];
  List<PnlPoint> get pnlHistory => _pnlHistory;

  List<AiDecisionLog> _aiLogs = [];
  List<AiDecisionLog> get aiLogs => _aiLogs;

  double get dailyProfitRate => _account?.dailyProfitRate ?? 0.0;
  double get dailyScore => todayReport?.totalScore ?? 0.0;
  double get winRate => todayReport?.winRate ?? 0.0;
  int get todayTradeCount => todayReport?.totalTrades ?? 0;

  bool _isCircuitBreaker = false;
  bool get isCircuitBreaker => _isCircuitBreaker;

  bool _isMarketOpen = false;
  bool get isMarketOpen => _isMarketOpen;

  String _marketSentiment = '반도체·2차전지 주도 — 적극매매';
  String get marketSentiment => _marketSentiment;

  // ── 백엔드 거래 상태 ────────────────────────────────────
  String _tradingStatus = 'IDLE'; // IDLE / RUNNING / STOPPED
  String get tradingStatus => _tradingStatus;
  bool get isTradingRunning => _tradingStatus == 'RUNNING';

  Map<String, dynamic> _todayStats = {};
  Map<String, dynamic> get todayStats => _todayStats;

  Map<String, dynamic> _tradingSettings = {};
  Map<String, dynamic> get tradingSettings => _tradingSettings;

  bool _isStatusLoading = false;
  bool get isStatusLoading => _isStatusLoading;

  String? _tradingError;
  String? get tradingError => _tradingError;

  Timer? _statusTimer;

  TradingProvider() {
    _loadMockData();
    _startStatusPolling();
  }

  void _startStatusPolling() {
    // 로그인 후 10초마다 거래 상태 자동 갱신
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      fetchTradingStatus();
    });
    fetchTradingStatus(); // 즉시 한번 실행
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // ── 거래 상태 조회 ─────────────────────────────────────
  Future<void> fetchTradingStatus() async {
    try {
      final data = await TradingApiService.getTradingStatus();
      _tradingStatus = data['status'] as String? ?? 'IDLE';
      _todayStats = data['today'] as Map<String, dynamic>? ?? {};
      _tradingSettings = data['config'] as Map<String, dynamic>? ?? {};
      notifyListeners();
    } catch (_) {
      // 백엔드 미연결 시 무시 (mock 데이터 유지)
    }
  }

  // ── 거래 시작 ──────────────────────────────────────────
  Future<String?> startTrading() async {
    _isStatusLoading = true;
    _tradingError = null;
    notifyListeners();
    try {
      await TradingApiService.startTrading();
      await fetchTradingStatus();
      _isStatusLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _tradingError = e.toString().replaceFirst('Exception: ', '');
      _isStatusLoading = false;
      notifyListeners();
      return _tradingError;
    }
  }

  // ── 거래 중지 ──────────────────────────────────────────
  Future<String?> stopTrading() async {
    _isStatusLoading = true;
    _tradingError = null;
    notifyListeners();
    try {
      await TradingApiService.stopTrading();
      await fetchTradingStatus();
      _isStatusLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _tradingError = e.toString().replaceFirst('Exception: ', '');
      _isStatusLoading = false;
      notifyListeners();
      return _tradingError;
    }
  }

  // ── 증권사 계좌 연동 ──────────────────────────────────
  Future<void> connectBrokerAccount({
    required String appKey,
    required String appSecret,
    required String accountNo,
    bool isMock = true,
  }) async {
    try {
      await TradingApiService.connectBroker(
        broker: 'kis',
        appKey: appKey,
        appSecret: appSecret,
        accountNo: accountNo,
        isMock: isMock,
      );
      await fetchTradingStatus();
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── 설정 초기화 ────────────────────────────────────────
  Future<String?> resetTradingSettings() async {
    _isStatusLoading = true;
    notifyListeners();
    try {
      await TradingApiService.resetSettings();
      await fetchTradingStatus();
      _isStatusLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _tradingError = e.toString().replaceFirst('Exception: ', '');
      _isStatusLoading = false;
      notifyListeners();
      return _tradingError;
    }
  }

  void _loadMockData() {
    final now = DateTime.now();

    _account = const AccountInfo(
      id: 'acc_001',
      brokerType: BrokerType.kis,
      accountNumber: '1234-56-789012',
      totalBalance: 10320000,
      availableCash: 3200000,
      investedAmount: 7120000,
      dailyProfitRate: 3.2,
      totalProfitRate: 3.2,
      tradingMode: TradingMode.paper,
      isConnected: true,
    );

    // PnL 히스토리
    final base = 10000000.0;
    final changes = [0.0, 0.5, 1.2, 0.8, 1.8, 1.4, 2.2, 1.9, 2.8, 2.4,
                     3.1, 2.9, 3.5, 3.2, 3.8, 3.4, 4.0, 3.7, 3.2, 3.2];
    _pnlHistory = List.generate(changes.length, (i) {
      final t = DateTime(now.year, now.month, now.day, 9)
          .add(Duration(minutes: i * 15));
      final val = base * (1 + changes[i] / 100);
      return PnlPoint(time: t, value: val, profitRate: changes[i]);
    });

    _watchlist = [
      WatchStock(
        id: 'w1', date: _today(), stockCode: '005930',
        stockName: '삼성전자', theme: '반도체·AI',
        totalScore: 87.4, recommendation: Recommendation.buy,
        targetPrice: 78000, stopLossPrice: 71000, currentPrice: 73400,
        entryCondition: 'RSI 38 → 반등, MACD 상향돌파',
        aiReasoning: 'HBM3 수요 급증으로 단기 모멘텀 강화. 외국인 순매수 연속 3일.',
        themeRelevance: 95, technicalScore: 82, volumeScore: 88, aiConfidence: 85,
        rsi: 38.5, macd: 0.12, macdSignal: -0.08,
        bollingerUpper: 76500, bollingerLower: 70200,
        ma5: 73100, ma20: 71800, ma60: 70200,
        volumeRatio: 2.4, stochasticK: 22.1, stochasticD: 18.7,
      ),
      WatchStock(
        id: 'w2', date: _today(), stockCode: '373220',
        stockName: 'LG에너지솔루션', theme: '2차전지',
        totalScore: 82.1, recommendation: Recommendation.buy,
        targetPrice: 425000, stopLossPrice: 388000, currentPrice: 401000,
        entryCondition: '볼린저밴드 하단 반등, 거래량 300%',
        aiReasoning: '북미 전기차 수요 회복. 기관 순매수 전환.',
        themeRelevance: 90, technicalScore: 78, volumeScore: 85, aiConfidence: 80,
        rsi: 42.3, macd: -0.05, macdSignal: -0.12,
        bollingerUpper: 432000, bollingerLower: 392000,
        ma5: 398000, ma20: 410000, ma60: 405000,
        volumeRatio: 3.1, stochasticK: 28.4, stochasticD: 24.1,
      ),
      WatchStock(
        id: 'w3', date: _today(), stockCode: '035420',
        stockName: 'NAVER', theme: 'AI·플랫폼',
        totalScore: 78.5, recommendation: Recommendation.watch,
        targetPrice: 215000, stopLossPrice: 195000, currentPrice: 204000,
        entryCondition: '5MA > 20MA 골든크로스 확인 후 진입',
        aiReasoning: 'AI 커머스 서비스 성장. 단, 매크로 불확실성 주의.',
        themeRelevance: 85, technicalScore: 74, volumeScore: 79, aiConfidence: 76,
        rsi: 52.1, macd: 0.18, macdSignal: 0.09,
        bollingerUpper: 218000, bollingerLower: 196000,
        ma5: 203000, ma20: 199000, ma60: 197000,
        volumeRatio: 1.8, stochasticK: 58.2, stochasticD: 52.7,
      ),
      WatchStock(
        id: 'w4', date: _today(), stockCode: '006400',
        stockName: '삼성SDI', theme: '2차전지',
        totalScore: 71.2, recommendation: Recommendation.watch,
        targetPrice: 325000, stopLossPrice: 295000, currentPrice: 308000,
        entryCondition: '스토캐스틱 %K 20 이하 상향돌파 대기',
        aiReasoning: '유럽 전기차 공장 가동률 상승. 아직 진입 타이밍 아님.',
        themeRelevance: 80, technicalScore: 68, volumeScore: 72, aiConfidence: 65,
        rsi: 44.8, macd: -0.22, macdSignal: -0.15,
        bollingerUpper: 330000, bollingerLower: 292000,
        ma5: 307000, ma20: 315000, ma60: 312000,
        volumeRatio: 1.4, stochasticK: 24.6, stochasticD: 30.2,
      ),
      WatchStock(
        id: 'w5', date: _today(), stockCode: '000660',
        stockName: 'SK하이닉스', theme: '반도체·AI',
        totalScore: 69.8, recommendation: Recommendation.avoid,
        targetPrice: 192000, stopLossPrice: 174000, currentPrice: 181500,
        entryCondition: '단기 과매수 — 조정 후 재진입',
        aiReasoning: 'RSI 과매수 구간. 단기 조정 가능성 높음. 관망 권고.',
        themeRelevance: 88, technicalScore: 55, volumeScore: 70, aiConfidence: 55,
        rsi: 72.4, macd: 0.35, macdSignal: 0.28,
        bollingerUpper: 194000, bollingerLower: 172000,
        ma5: 183000, ma20: 178000, ma60: 168000,
        volumeRatio: 2.2, stochasticK: 82.1, stochasticD: 77.8,
      ),
    ];

    _positions = [
      Position(
        stockCode: '005930', stockName: '삼성전자',
        quantity: 50, avgPrice: 72300, currentPrice: 73960,
        profitRate: 2.30, stopLossPrice: 70100, targetPrice: 75000,
        highestProfitRate: 2.5,
        buyTime: now.subtract(const Duration(hours: 1, minutes: 28)),
      ),
      Position(
        stockCode: '373220', stockName: 'LG에너지솔루션',
        quantity: 8, avgPrice: 398000, currentPrice: 394800,
        profitRate: -0.80, stopLossPrice: 386000, targetPrice: 420000,
        highestProfitRate: 0.8,
        buyTime: now.subtract(const Duration(hours: 2, minutes: 5)),
      ),
    ];

    _trades = [
      Trade(
        id: 't1', accountId: 'acc_001',
        stockCode: '005930', stockName: '삼성전자',
        tradeType: TradeType.buy, quantity: 50,
        price: 72300, totalAmount: 3615000,
        executedAt: now.subtract(const Duration(hours: 1, minutes: 28)),
      ),
      Trade(
        id: 't2', accountId: 'acc_001',
        stockCode: '373220', stockName: 'LG에너지솔루션',
        tradeType: TradeType.buy, quantity: 8,
        price: 398000, totalAmount: 3184000,
        executedAt: now.subtract(const Duration(hours: 2, minutes: 5)),
      ),
      Trade(
        id: 't3', accountId: 'acc_001',
        stockCode: '000660', stockName: 'SK하이닉스',
        tradeType: TradeType.sell, quantity: 15,
        price: 183500, totalAmount: 2752500,
        sellReason: SellReason.profit,
        profitRate: 4.2, score: 6.3,
        executedAt: now.subtract(const Duration(hours: 3, minutes: 15)),
      ),
      Trade(
        id: 't4', accountId: 'acc_001',
        stockCode: '035420', stockName: 'NAVER',
        tradeType: TradeType.sell, quantity: 20,
        price: 198000, totalAmount: 3960000,
        sellReason: SellReason.stopLoss,
        profitRate: -2.8, score: -4.2,
        executedAt: now.subtract(const Duration(hours: 4, minutes: 40)),
      ),
      Trade(
        id: 't5', accountId: 'acc_001',
        stockCode: '051910', stockName: 'LG화학',
        tradeType: TradeType.sell, quantity: 10,
        price: 412000, totalAmount: 4120000,
        sellReason: SellReason.trailing,
        profitRate: 6.8, score: 10.4,
        executedAt: now.subtract(const Duration(hours: 5, minutes: 10)),
      ),
      Trade(
        id: 't6', accountId: 'acc_001',
        stockCode: '055550', stockName: '신한지주',
        tradeType: TradeType.sell, quantity: 30,
        price: 48200, totalAmount: 1446000,
        sellReason: SellReason.aiDecision,
        profitRate: 2.1, score: 2.1,
        executedAt: now.subtract(const Duration(hours: 6)),
      ),
      Trade(
        id: 't7', accountId: 'acc_001',
        stockCode: '068270', stockName: '셀트리온',
        tradeType: TradeType.sell, quantity: 12,
        price: 182000, totalAmount: 2184000,
        sellReason: SellReason.stopLoss,
        profitRate: -3.0, score: -4.5,
        executedAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      Trade(
        id: 't8', accountId: 'acc_001',
        stockCode: '028260', stockName: '삼성물산',
        tradeType: TradeType.sell, quantity: 15,
        price: 152000, totalAmount: 2280000,
        sellReason: SellReason.profit,
        profitRate: 8.5, score: 14.0,
        executedAt: now.subtract(const Duration(days: 1, hours: 4)),
      ),
    ];

    _reports = List.generate(7, (i) {
      final date = now.subtract(Duration(days: i));
      final totals = [8, 5, 12, 6, 9, 4, 7];
      final profits = [6, 4, 8, 3, 7, 3, 5];
      final total = totals[i];
      final profit = profits[i];
      return DailyReport(
        id: 'r$i', date: date,
        totalTrades: total, profitTrades: profit, lossTrades: total - profit,
        winRate: profit / total * 100,
        totalProfitRate: [3.2, 5.8, -1.2, 7.4, 2.1, 4.9, 6.3][i],
        totalScore: [47.5, 62.1, -8.4, 85.2, 28.7, 54.3, 71.8][i],
        avgScorePerTrade: [5.9, 12.4, -0.7, 14.2, 3.2, 13.6, 10.3][i],
        waitCount: [3, 1, 5, 2, 4, 1, 2][i],
        marketSentiment: ['반도체·2차전지 주도', '금리 불확실성', '외국인 매도', 'AI 테마 급등', '전반적 약세', '바이오 강세', '지수 반등'][i],
        recommendations: [
          ['손절 후 재진입 타이밍 개선 필요'],
          ['목표 달성! 수익 극대화 전략 유효'],
          ['변동성 높은 날 거래 자제 권고'],
        ][i % 3],
        startBalance: 10000000.0 + i * 50000,
        endBalance: 10320000.0 - i * 30000,
      );
    });

    _aiLogs = [
      AiDecisionLog(
        id: 'ai1', decisionType: 'STOCK_SELECT',
        stockCode: '005930', stockName: '삼성전자',
        inputSummary: '반도체 테마 Top 20 → 기술적 분석 스코어 87.4',
        outputDecision: 'BUY — HBM3 수요 급증, 외국인 순매수, RSI 38 과매도 탈출',
        modelUsed: 'claude-sonnet-4', confidence: 85.0,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 28)),
      ),
      AiDecisionLog(
        id: 'ai2', decisionType: 'SELL',
        stockCode: '000660', stockName: 'SK하이닉스',
        inputSummary: '수익률 +4.2%, 고점 대비 -0.8% 하락, RSI 71',
        outputDecision: 'SELL — 트레일링 스탑 발동. 추가 상승 여력 제한적.',
        modelUsed: 'claude-sonnet-4', confidence: 78.0, wasCorrect: true,
        createdAt: now.subtract(const Duration(hours: 3, minutes: 15)),
      ),
      AiDecisionLog(
        id: 'ai3', decisionType: 'WAIT',
        stockCode: '035420', stockName: 'NAVER',
        inputSummary: '진입 조건 미충족 — 5MA < 20MA 데드크로스 상태',
        outputDecision: 'WAIT — 골든크로스 확인 전까지 진입 보류',
        modelUsed: 'claude-sonnet-4', confidence: 72.0,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 40)),
      ),
      AiDecisionLog(
        id: 'ai4', decisionType: 'BUY',
        stockCode: '051910', stockName: 'LG화학',
        inputSummary: '볼린저밴드 하단 터치 반등, 거래량 320%',
        outputDecision: 'BUY — 진입 적기. 목표가 412,000원, 손절가 386,000원',
        modelUsed: 'claude-sonnet-4', confidence: 82.0, wasCorrect: true,
        createdAt: now.subtract(const Duration(hours: 5, minutes: 30)),
      ),
      AiDecisionLog(
        id: 'ai5', decisionType: 'STOCK_SELECT',
        stockCode: 'MARKET', stockName: '시장 전체',
        inputSummary: '전일 거래량 급등 테마 분석 — 반도체, 2차전지, AI 플랫폼',
        outputDecision: '오늘 주도 테마: 반도체·AI (1위), 2차전지 (2위). 적극매매 권고.',
        modelUsed: 'claude-sonnet-4', confidence: 88.0,
        createdAt: now.subtract(const Duration(hours: 6, minutes: 30)),
      ),
    ];

    _isMarketOpen = _checkMarketOpen();
    notifyListeners();
  }

  bool _checkMarketOpen() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      return false;
    }
    final totalMin = now.hour * 60 + now.minute;
    return totalMin >= 9 * 60 && totalMin < 15 * 60 + 30;
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  void refreshData() {
    _loadMockData();
    fetchTradingStatus();
  }
}
