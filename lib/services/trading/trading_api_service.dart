// lib/services/trading/trading_api_service.dart
// 거래 설정 API 서비스 — 백엔드 연동

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/api_auth_service.dart';

class TradingApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await ApiAuthService.getStoredToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  // ── 증권사 계좌 연동 ──────────────────────────────────
  static Future<Map<String, dynamic>> connectBroker({
    required String broker,
    required String appKey,
    required String appSecret,
    required String accountNo,
    bool isMock = true,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/broker/connect'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'broker': broker,
        'appKey': appKey,
        'appSecret': appSecret,
        'accountNo': accountNo,
        'isMock': isMock,
      }),
    ).timeout(ApiConfig.timeout);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) throw Exception(body['error'] ?? '연동 실패');
    return body;
  }

  // ── 연동 계좌 목록 ────────────────────────────────────
  static Future<List<dynamic>> getBrokerAccounts() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/broker/accounts'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['accounts'] as List? ?? [];
  }

  // ── 거래 설정 조회 ────────────────────────────────────
  static Future<Map<String, dynamic>> getSettings() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/trading/settings'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['settings'] as Map<String, dynamic>? ?? {};
  }

  // ── 거래 설정 저장 ────────────────────────────────────
  static Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> settings) async {
    final resp = await http.put(
      Uri.parse('$baseUrl/api/trading/settings'),
      headers: await _authHeaders(),
      body: jsonEncode(settings),
    ).timeout(ApiConfig.timeout);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) {
      final errors = body['errors'] as List?;
      throw Exception(errors?.join('\n') ?? body['error'] ?? '설정 저장 실패');
    }
    return body['settings'] as Map<String, dynamic>? ?? {};
  }

  // ── 거래 시작 ─────────────────────────────────────────
  static Future<Map<String, dynamic>> startTrading() async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/trading/start'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 400) throw Exception(body['error'] ?? '시작 실패');
    return body;
  }

  // ── 거래 중지 ─────────────────────────────────────────
  static Future<void> stopTrading({String reason = '수동 중지'}) async {
    await http.post(
      Uri.parse('$baseUrl/api/trading/stop'),
      headers: await _authHeaders(),
      body: jsonEncode({'reason': reason}),
    ).timeout(ApiConfig.timeout);
  }

  // ── 거래 설정 초기화 ──────────────────────────────────
  static Future<void> resetSettings() async {
    await http.post(
      Uri.parse('$baseUrl/api/trading/reset'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
  }

  // ── 거래 상태 조회 ────────────────────────────────────
  static Future<Map<String, dynamic>> getTradingStatus() async {
    final resp = await http.get(
      Uri.parse('$baseUrl/api/trading/status'),
      headers: await _authHeaders(),
    ).timeout(ApiConfig.timeout);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
