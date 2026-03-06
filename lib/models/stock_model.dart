// lib/models/stock_model.dart
import 'package:flutter/material.dart';

enum Recommendation { buy, watch, avoid }
enum TradeType { buy, sell }
enum SellReason { profit, stopLoss, trailing, aiDecision, marketClose }
enum BrokerType { kiwoom, kis }
enum TradingMode { paper, live }

/// 워치리스트 종목
class WatchStock {
  final String id;
  final String date;
  final String stockCode;
  final String stockName;
  final String theme;
  final double totalScore;
  final Recommendation recommendation;
  final int targetPrice;
  final int stopLossPrice;
  final int currentPrice;
  final String entryCondition;
  final String aiReasoning;
  final double themeRelevance;
  final double technicalScore;
  final double volumeScore;
  final double aiConfidence;
  final double rsi;
  final double macd;
  final double macdSignal;
  final double bollingerUpper;
  final double bollingerLower;
  final double ma5;
  final double ma20;
  final double ma60;
  final double volumeRatio;
  final double stochasticK;
  final double stochasticD;

  const WatchStock({
    required this.id,
    required this.date,
    required this.stockCode,
    required this.stockName,
    required this.theme,
    required this.totalScore,
    required this.recommendation,
    required this.targetPrice,
    required this.stopLossPrice,
    required this.currentPrice,
    required this.entryCondition,
    required this.aiReasoning,
    required this.themeRelevance,
    required this.technicalScore,
    required this.volumeScore,
    required this.aiConfidence,
    required this.rsi,
    required this.macd,
    required this.macdSignal,
    required this.bollingerUpper,
    required this.bollingerLower,
    required this.ma5,
    required this.ma20,
    required this.ma60,
    required this.volumeRatio,
    required this.stochasticK,
    required this.stochasticD,
  });

  double get profitRateToTarget =>
      ((targetPrice - currentPrice) / currentPrice) * 100;
  double get riskRateToStop =>
      ((stopLossPrice - currentPrice) / currentPrice) * 100;

  Color get recommendationColor {
    switch (recommendation) {
      case Recommendation.buy:
        return const Color(0xFF1A8754);
      case Recommendation.watch:
        return const Color(0xFFE37400);
      case Recommendation.avoid:
        return const Color(0xFFD93025);
    }
  }

  String get recommendationLabel {
    switch (recommendation) {
      case Recommendation.buy:
        return '매수';
      case Recommendation.watch:
        return '관망';
      case Recommendation.avoid:
        return '회피';
    }
  }
}

/// 거래 이력
class Trade {
  final String id;
  final String accountId;
  final String stockCode;
  final String stockName;
  final TradeType tradeType;
  final int quantity;
  final int price;
  final int totalAmount;
  final SellReason? sellReason;
  final double? profitRate;
  final double? score;
  final String? aiDecisionLog;
  final DateTime executedAt;

  const Trade({
    required this.id,
    required this.accountId,
    required this.stockCode,
    required this.stockName,
    required this.tradeType,
    required this.quantity,
    required this.price,
    required this.totalAmount,
    this.sellReason,
    this.profitRate,
    this.score,
    this.aiDecisionLog,
    required this.executedAt,
  });

  bool get isProfit => (profitRate ?? 0) > 0;

  String get sellReasonLabel {
    switch (sellReason) {
      case SellReason.profit:
        return '목표달성';
      case SellReason.stopLoss:
        return '손절';
      case SellReason.trailing:
        return '트레일링';
      case SellReason.aiDecision:
        return 'AI판단';
      case SellReason.marketClose:
        return '장마감';
      default:
        return '-';
    }
  }
}

/// 포지션 (현재 보유 종목)
class Position {
  final String stockCode;
  final String stockName;
  final int quantity;
  final int avgPrice;
  final int currentPrice;
  final double profitRate;
  final int stopLossPrice;
  final int targetPrice;
  final double highestProfitRate;
  final DateTime buyTime;

  const Position({
    required this.stockCode,
    required this.stockName,
    required this.quantity,
    required this.avgPrice,
    required this.currentPrice,
    required this.profitRate,
    required this.stopLossPrice,
    required this.targetPrice,
    required this.highestProfitRate,
    required this.buyTime,
  });

  int get profitAmount => (currentPrice - avgPrice) * quantity;
  int get totalValue => currentPrice * quantity;
  bool get isProfit => profitRate >= 0;
}

/// 일일 리포트
class DailyReport {
  final String id;
  final DateTime date;
  final int totalTrades;
  final int profitTrades;
  final int lossTrades;
  final double winRate;
  final double totalProfitRate;
  final double totalScore;
  final double avgScorePerTrade;
  final int waitCount;
  final String marketSentiment;
  final List<String> recommendations;
  final double startBalance;
  final double endBalance;

  const DailyReport({
    required this.id,
    required this.date,
    required this.totalTrades,
    required this.profitTrades,
    required this.lossTrades,
    required this.winRate,
    required this.totalProfitRate,
    required this.totalScore,
    required this.avgScorePerTrade,
    required this.waitCount,
    required this.marketSentiment,
    required this.recommendations,
    required this.startBalance,
    required this.endBalance,
  });

  bool get metDailyTarget => totalProfitRate >= 5.0;
}

/// 계좌 정보
class AccountInfo {
  final String id;
  final BrokerType brokerType;
  final String accountNumber;
  final double totalBalance;
  final double availableCash;
  final double investedAmount;
  final double dailyProfitRate;
  final double totalProfitRate;
  final TradingMode tradingMode;
  final bool isConnected;

  const AccountInfo({
    required this.id,
    required this.brokerType,
    required this.accountNumber,
    required this.totalBalance,
    required this.availableCash,
    required this.investedAmount,
    required this.dailyProfitRate,
    required this.totalProfitRate,
    required this.tradingMode,
    required this.isConnected,
  });

  String get brokerName {
    switch (brokerType) {
      case BrokerType.kiwoom:
        return '키움증권';
      case BrokerType.kis:
        return '한국투자증권';
    }
  }

  String get tradingModeLabel {
    switch (tradingMode) {
      case TradingMode.paper:
        return '모의투자';
      case TradingMode.live:
        return '실투자';
    }
  }
}

/// AI 판단 로그
class AiDecisionLog {
  final String id;
  final String decisionType;
  final String stockCode;
  final String stockName;
  final String inputSummary;
  final String outputDecision;
  final String modelUsed;
  final double confidence;
  final bool? wasCorrect;
  final DateTime createdAt;

  const AiDecisionLog({
    required this.id,
    required this.decisionType,
    required this.stockCode,
    required this.stockName,
    required this.inputSummary,
    required this.outputDecision,
    required this.modelUsed,
    required this.confidence,
    this.wasCorrect,
    required this.createdAt,
  });

  Color get decisionColor {
    switch (decisionType) {
      case 'BUY':
        return const Color(0xFF1A8754);
      case 'SELL':
        return const Color(0xFFD93025);
      case 'WAIT':
        return const Color(0xFFE37400);
      default:
        return const Color(0xFF1A73E8);
    }
  }

  String get decisionLabel {
    switch (decisionType) {
      case 'STOCK_SELECT':
        return '종목선정';
      case 'BUY':
        return '매수';
      case 'SELL':
        return '매도';
      case 'WAIT':
        return '관망';
      default:
        return decisionType;
    }
  }
}

/// PnL 차트 데이터 포인트
class PnlPoint {
  final DateTime time;
  final double value;
  final double profitRate;

  const PnlPoint({
    required this.time,
    required this.value,
    required this.profitRate,
  });
}
