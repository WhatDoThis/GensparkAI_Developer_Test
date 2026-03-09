// lib/screens/trading_setup/trading_setup_screen.dart
// 거래 설정 화면 — 4단계 스텝 위저드
// Step 1: 증권사 계좌 연동
// Step 2: 자금 설정 (일일 예산 + 손실 마지노선)
// Step 3: 시간 + TERM + 거래 횟수 설정
// Step 4: AI 설정 + 확인 및 시작

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_theme.dart';
import '../../services/trading/trading_api_service.dart';

class TradingSetupScreen extends StatefulWidget {
  const TradingSetupScreen({super.key});

  @override
  State<TradingSetupScreen> createState() => _TradingSetupScreenState();
}

class _TradingSetupScreenState extends State<TradingSetupScreen> {
  int _step = 0; // 0~3
  bool _isLoading = false;
  String? _errorMsg;

  // 백엔드에서 로드한 현재 설정
  Map<String, dynamic> _settings = {};
  List<dynamic> _brokerAccounts = [];

  // Step 1: 계좌 연동
  final _appKeyCtrl = TextEditingController();
  final _appSecretCtrl = TextEditingController();
  final _accountNoCtrl = TextEditingController();
  String _selectedBroker = 'kis';
  bool _isMock = true;
  String? _connectedAccountId;

  // Step 2: 자금
  final _budgetCtrl = TextEditingController();
  final _lossFloorCtrl = TextEditingController();

  // Step 3: 시간/TERM/횟수
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 10);
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 50);
  int _termSeconds = 60;
  int _maxTrades = 0; // 0=무제한

  // Step 4: AI 설정
  int _minConfidence = 70;
  double _targetProfitRate = 0.015; // Q1: 기본 1.5%
  double _stopLossRate = 0.01;      // Q1: 기본 1%
  List<String> _aiSources = ['broker_api', 'krx'];

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _appKeyCtrl.dispose();
    _appSecretCtrl.dispose();
    _accountNoCtrl.dispose();
    _budgetCtrl.dispose();
    _lossFloorCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        TradingApiService.getSettings(),
        TradingApiService.getBrokerAccounts(),
      ]);
      final settings = results[0] as Map<String, dynamic>;
      final accounts = results[1] as List<dynamic>;

      setState(() {
        _settings = settings;
        _brokerAccounts = accounts;

        // 기존 설정값 복원
        if (settings['daily_budget'] != null && settings['daily_budget'] != 0) {
          _budgetCtrl.text = (settings['daily_budget'] as num).toInt().toString();
        }
        if (settings['loss_floor'] != null && settings['loss_floor'] != 0) {
          _lossFloorCtrl.text = (settings['loss_floor'] as num).toInt().toString();
        }
        _termSeconds = (settings['term_seconds'] as int?) ?? 60;
        _maxTrades = (settings['max_trades'] as int?) ?? 0;
        _minConfidence = (settings['min_confidence_score'] as int?) ?? 70;
        _targetProfitRate = (settings['target_profit_rate'] as num?)?.toDouble() ?? 0.015;
        _stopLossRate = (settings['stop_loss_rate'] as num?)?.toDouble() ?? 0.01;
        _connectedAccountId = settings['broker_account_id'] as String?;

        if (settings['trading_start_time'] != null) {
          final parts = (settings['trading_start_time'] as String).split(':');
          _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
        if (settings['trading_end_time'] != null) {
          final parts = (settings['trading_end_time'] as String).split(':');
          _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }

        // 이미 계좌 연동됐으면 Step 2부터
        if (_connectedAccountId != null && accounts.isNotEmpty) {
          _step = 1;
        }
      });
    } catch (e) {
      // 백엔드 미연결 시 기본값으로 계속 진행 가능
      setState(() {
        _errorMsg = null; // 에러 배너 숨김 — 오프라인 모드로 진행
        _settings = {}; // 빈 설정으로 시작
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.accent,
            surface: AppTheme.cardBackground,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final mins = picked.hour * 60 + picked.minute;
    if (isStart) {
      if (mins < 9 * 60 + 10) {
        _showError('거래 시작은 09:10 이후로 설정하세요');
        return;
      }
      setState(() => _startTime = picked);
    } else {
      if (mins > 14 * 60 + 50) {
        _showError('거래 종료는 14:50 이전으로 설정하세요');
        return;
      }
      setState(() => _endTime = picked);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.loss,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Step 1: 계좌 연동 ───────────────────────────────────
  Future<void> _connectBroker() async {
    if (_appKeyCtrl.text.isEmpty || _appSecretCtrl.text.isEmpty || _accountNoCtrl.text.isEmpty) {
      _showError('모든 항목을 입력하세요');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final result = await TradingApiService.connectBroker(
        broker: _selectedBroker,
        appKey: _appKeyCtrl.text.trim(),
        appSecret: _appSecretCtrl.text.trim(),
        accountNo: _accountNoCtrl.text.trim(),
        isMock: _isMock,
      );
      setState(() {
        _connectedAccountId = result['accountId'] as String?;
        _step = 1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계좌가 연동되었습니다 ✓'), backgroundColor: AppTheme.profit),
        );
      }
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      setState(() => _errorMsg = errStr.contains('SocketException') || errStr.contains('TimeoutException')
          ? '백엔드 서버 연결 실패\n백엔드가 실행 중인지 확인하세요 (포트 3000)'
          : errStr);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Step 2~4: 설정 저장 ─────────────────────────────────
  Future<void> _saveAndNext() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final budget = double.tryParse(_budgetCtrl.text) ?? 0;
      final lossFloor = double.tryParse(_lossFloorCtrl.text) ?? 0;

      if (_step == 1) {
        if (budget <= 0) { _showError('일일 예산을 입력하세요'); return; }
        if (lossFloor < 0 || lossFloor >= budget) {
          _showError('손실 마지노선은 0 이상, 일일 예산 미만이어야 합니다'); return;
        }
      }

      await TradingApiService.saveSettings({
        if (_connectedAccountId != null) 'broker_account_id': _connectedAccountId,
        if (_step >= 1) 'daily_budget': budget,
        if (_step >= 1) 'loss_floor': lossFloor,
        if (_step >= 2) 'trading_start_time': _fmt(_startTime),
        if (_step >= 2) 'trading_end_time': _fmt(_endTime),
        if (_step >= 2) 'term_seconds': _termSeconds,
        if (_step >= 2) 'max_trades': _maxTrades,
        if (_step >= 3) 'min_confidence_score': _minConfidence,
        if (_step >= 3) 'target_profit_rate': _targetProfitRate,
        if (_step >= 3) 'stop_loss_rate': _stopLossRate,
        if (_step >= 3) 'ai_sources': _aiSources,
      });

      if (_step < 3) {
        setState(() => _step++);
      } else {
        // 마지막 단계 → 거래 시작
        await TradingApiService.startTrading();
        if (mounted) {
          Navigator.of(context).pop(true); // true = 시작됨
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('자동 거래가 시작되었습니다! 🚀'),
              backgroundColor: AppTheme.profit,
            ),
          );
        }
      }
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      setState(() => _errorMsg = errStr.contains('SocketException') || errStr.contains('TimeoutException')
          ? '백엔드 서버 연결 실패\n서버가 실행 중인지 확인하세요 (포트 3000)'
          : errStr);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('거래 설정'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (_settings['status'] == 'RUNNING' || _settings['status'] == 'IDLE' || _settings.isNotEmpty)
            TextButton(
              onPressed: _confirmReset,
              child: Text('초기화', style: TextStyle(color: AppTheme.loss)),
            ),
        ],
      ),
      body: _isLoading && _settings.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMsg != null) _buildErrorBanner(),
                        _buildStepContent(),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['계좌 연동', '자금 설정', '시간/TERM', 'AI 설정'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: AppTheme.cardBackground,
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? AppTheme.profit
                        : isActive ? AppTheme.accent
                        : AppTheme.background,
                    border: Border.all(
                      color: isActive ? AppTheme.accent
                          : isDone ? AppTheme.profit
                          : AppTheme.textTertiary,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${i + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : AppTheme.textTertiary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            )),
                  ),
                ),
                const SizedBox(height: 4),
                Text(steps[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive ? AppTheme.accent
                          : isDone ? AppTheme.profit
                          : AppTheme.textTertiary,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    )),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.loss.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.loss.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.loss, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMsg!, style: TextStyle(color: AppTheme.loss, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _buildStep1BrokerConnect();
      case 1: return _buildStep2BudgetSettings();
      case 2: return _buildStep3TimeSettings();
      case 3: return _buildStep4AISettings();
      default: return const SizedBox();
    }
  }

  // ── Step 1: 증권사 계좌 연동 ────────────────────────────
  Widget _buildStep1BrokerConnect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('증권사 계좌 연동', '한국투자증권 API 키를 입력하세요'),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('API 키 발급 방법', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _guideItem('1', 'https://apiportal.koreainvestment.com 접속'),
              _guideItem('2', '로그인 → My API → 앱 신청'),
              _guideItem('3', '실거래: 실전투자 앱 신청 / 모의투자: 모의투자 앱 신청'),
              _guideItem('4', 'App Key / App Secret 복사'),
              _guideItem('5', '계좌번호는 하이픈 없이 숫자만 입력 (예: 5012345601)'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 브로커 선택 (KIS 단독, 추후 증권사 추가 예정)
        _label('증권사'),
        const SizedBox(height: 8),
        Row(
          children: [
            _brokerChip('kis', '한국투자증권', Icons.account_balance),
          ],
        ),
        const SizedBox(height: 16),

        // 거래 환경
        _label('거래 환경'),
        const SizedBox(height: 8),
        Row(
          children: [
            _envChip(true, '모의투자', '실제 돈 없음'),
            const SizedBox(width: 8),
            _envChip(false, '실거래', '실제 돈 사용'),
          ],
        ),
        const SizedBox(height: 20),

        _inputField(_appKeyCtrl, 'App Key', '발급받은 App Key 입력', obscure: true),
        const SizedBox(height: 12),
        _inputField(_appSecretCtrl, 'App Secret', '발급받은 App Secret 입력', obscure: true),
        const SizedBox(height: 12),
        _inputField(_accountNoCtrl, '계좌번호', '숫자만 입력 (예: 5012345601)',
            keyboardType: TextInputType.number),
        const SizedBox(height: 8),

        // 기존 연동 계좌
        if (_brokerAccounts.isNotEmpty) ...[
          const SizedBox(height: 16),
          _label('이미 연동된 계좌'),
          const SizedBox(height: 8),
          ..._brokerAccounts.map((a) => _accountTile(a)),
        ],
      ],
    );
  }

  Widget _guideItem(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$num. ', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _brokerChip(String value, String label, IconData icon) {
    final isSelected = _selectedBroker == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedBroker = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.textTertiary),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: isSelected ? AppTheme.accent : AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _envChip(bool isMockVal, String label, String sub) {
    final isSelected = _isMock == isMockVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isMock = isMockVal),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isMockVal ? AppTheme.accent : AppTheme.loss).withValues(alpha: 0.15)
                : AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? (isMockVal ? AppTheme.accent : AppTheme.loss)
                  : AppTheme.textTertiary,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                color: isSelected
                    ? (isMockVal ? AppTheme.accent : AppTheme.loss)
                    : AppTheme.textSecondary,
                fontSize: 13, fontWeight: FontWeight.bold,
              )),
              Text(sub, style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountTile(Map a) {
    final isActive = a['is_active'] == true || a['is_active'] == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppTheme.profit.withValues(alpha: 0.5) : AppTheme.textTertiary,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle,
              color: isActive ? AppTheme.profit : AppTheme.textTertiary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a['broker']?.toString().toUpperCase()} - ${a['account_no']}',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(a['is_mock'] == true ? '모의투자' : '실거래',
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _connectedAccountId = a['id'] as String?;
                _step = 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('사용', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: 자금 설정 ────────────────────────────────────
  Widget _buildStep2BudgetSettings() {
    final budget = double.tryParse(_budgetCtrl.text) ?? 0;
    final lossFloor = double.tryParse(_lossFloorCtrl.text) ?? 0;
    final riskAmount = budget - lossFloor;
    final riskRate = budget > 0 ? (riskAmount / budget * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('자금 설정', '오늘 거래에 사용할 금액과 손실 한도를 설정하세요'),
        const SizedBox(height: 20),

        _inputField(_budgetCtrl, '일일 거래 예산 (원)', '예: 50000',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 4),
        Text('계좌 예수금 중 오늘 거래에 사용할 금액',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
        const SizedBox(height: 16),

        _inputField(_lossFloorCtrl, '손실 마지노선 (원)', '예: 30000',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 4),
        Text('거래 중 잔고가 이 금액 이하로 떨어지면 당일 거래 자동 중단',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),

        // 리스크 시각화
        if (budget > 0) ...[
          const SizedBox(height: 24),
          _label('리스크 분석'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _riskRow('거래 예산', budget, AppTheme.textPrimary),
                const SizedBox(height: 8),
                _riskRow('손실 마지노선', lossFloor, AppTheme.textSecondary),
                const Divider(height: 16),
                _riskRow(
                  '최대 허용 손실',
                  riskAmount,
                  riskRate > 50 ? AppTheme.loss : AppTheme.warning,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: budget > 0 ? (lossFloor / budget).clamp(0.0, 1.0) : 0,
                    minHeight: 8,
                    backgroundColor: AppTheme.loss.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(AppTheme.profit),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('손실 허용 ${riskRate.toStringAsFixed(0)}%',
                        style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    Text('보호 자금 ${(100 - riskRate).toStringAsFixed(0)}%',
                        style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _riskRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text('${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  // ── Step 3: 시간/TERM/횟수 ──────────────────────────────
  Widget _buildStep3TimeSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('시간 및 거래 설정', '거래 시간, 분석 주기, 최대 횟수를 설정하세요'),
        const SizedBox(height: 20),

        _label('거래 시간 (장중 09:10 ~ 14:50 범위)'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _timePickerTile('시작 시간', _fmt(_startTime), () => _pickTime(true))),
            const SizedBox(width: 12),
            Expanded(child: _timePickerTile('종료 시간', _fmt(_endTime), () => _pickTime(false))),
          ],
        ),
        const SizedBox(height: 8),
        Text('※ 09:00~09:10 및 15:20~15:30 단일가 시간 제외',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),

        const SizedBox(height: 24),
        _label('분석 주기 (TERM) — 거래 후 다음 분석까지 대기 시간'),
        const SizedBox(height: 10),
        _termSelector(),
        const SizedBox(height: 4),
        Text('현재: $_termSeconds초 → 1회 거래 후 $_termSeconds초 대기 후 재분석',
            style: TextStyle(color: AppTheme.accent, fontSize: 11)),

        const SizedBox(height: 24),
        _label('최대 거래 횟수'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.textTertiary),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _maxTrades,
                    dropdownColor: AppTheme.cardBackground,
                    style: TextStyle(color: AppTheme.textPrimary),
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('무제한')),
                      ...[1, 2, 3, 5, 10, 20, 30, 50].map(
                        (v) => DropdownMenuItem(value: v, child: Text('$v회')),
                      ),
                    ],
                    onChanged: (v) => setState(() => _maxTrades = v ?? 0),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('이익/손실 무관하게 총 거래 횟수 제한 (0=시간 내 무제한)',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
      ],
    );
  }

  Widget _timePickerTile(String label, String time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.textTertiary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, color: AppTheme.accent, size: 16),
                const SizedBox(width: 6),
                Text(time, style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _termSelector() {
    final options = [1, 5, 10, 30, 60, 120, 300];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((sec) {
        final isSelected = _termSeconds == sec;
        final label = sec < 60 ? '${sec}초' : '${sec ~/ 60}분';
        return GestureDetector(
          onTap: () => setState(() => _termSeconds = sec),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.textTertiary),
            ),
            child: Text(label, style: TextStyle(
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
          ),
        );
      }).toList(),
    );
  }

  // ── Step 4: AI 설정 + 확인 ──────────────────────────────
  Widget _buildStep4AISettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('AI 분석 설정', '매매 신호 기준과 AI 분석 소스를 설정하세요'),
        const SizedBox(height: 20),

        _label('AI 신뢰도 최소 기준 ($_minConfidence점 이상만 매수)'),
        const SizedBox(height: 8),
        Slider(
          value: _minConfidence.toDouble(),
          min: 50, max: 90, divisions: 8,
          label: '$_minConfidence',
          activeColor: AppTheme.accent,
          onChanged: (v) => setState(() => _minConfidence = v.toInt()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('50 (공격적)', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
            Text('90 (보수적)', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
          ],
        ),

        const SizedBox(height: 20),
        _label('목표 수익률 (${(_targetProfitRate * 100).toStringAsFixed(1)}%)'),
        Slider(
          value: _targetProfitRate,
          min: 0.005, max: 0.05, divisions: 9,
          label: '${(_targetProfitRate * 100).toStringAsFixed(1)}%',
          activeColor: AppTheme.profit,
          onChanged: (v) => setState(() => _targetProfitRate = double.parse(v.toStringAsFixed(3))),
        ),
        Text('0.5% ~ 5% (Q1: 현실적 단기 수익, 기본 1.5%)',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),

        const SizedBox(height: 16),
        _label('손절 기준 (${(_stopLossRate * 100).toStringAsFixed(1)}%)'),
        Slider(
          value: _stopLossRate,
          min: 0.005, max: 0.03, divisions: 5,
          label: '-${(_stopLossRate * 100).toStringAsFixed(1)}%',
          activeColor: AppTheme.loss,
          onChanged: (v) => setState(() => _stopLossRate = double.parse(v.toStringAsFixed(3))),
        ),
        Text('0.5% ~ 3% (Q1: 손절은 목표수익보다 작게, 기본 1%)',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),

        const SizedBox(height: 20),
        _label('AI 분석 데이터 소스 (Q4)'),
        const SizedBox(height: 8),
        _aiSourceSelector(),

        // 최종 요약
        const SizedBox(height: 24),
        _buildSummaryCard(),
      ],
    );
  }

  Widget _aiSourceSelector() {
    final sources = {
      'broker_api': ('한국투자증권 API', '실시간 시세/호가/체결', Icons.api, true),
      'krx': ('한국거래소(KRX)', '공시/종목정보', Icons.business, true),
      'web_search': ('AI 웹 검색', 'Genspark 뉴스/정보 검색', Icons.search, false),
    };
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: sources.entries.map((entry) {
        final (label, sub, icon, required) = entry.value;
        final isSelected = _aiSources.contains(entry.key);
        return GestureDetector(
          onTap: required ? null : () {
            setState(() {
              if (isSelected) _aiSources.remove(entry.key);
              else _aiSources.add(entry.key);
            });
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppTheme.accent : AppTheme.textTertiary,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isSelected ? Icons.check_circle : icon,
                    size: 16,
                    color: isSelected ? AppTheme.accent : AppTheme.textTertiary),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(
                        color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(sub, style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
                  ],
                ),
                if (required)
                  Text(' (필수)', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard() {
    final budget = double.tryParse(_budgetCtrl.text) ?? 0;
    final lossFloor = double.tryParse(_lossFloorCtrl.text) ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accent.withValues(alpha: 0.15), AppTheme.cardBackground],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text('거래 설정 요약', style: TextStyle(
                  color: AppTheme.accent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow('계좌', _connectedAccountId != null ? '연동됨 ✓' : '미연동', _connectedAccountId != null ? AppTheme.profit : AppTheme.loss),
          _summaryRow('일일 예산', budget > 0 ? '${budget.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원' : '미설정', budget > 0 ? AppTheme.textPrimary : AppTheme.loss),
          _summaryRow('손실 마지노선', lossFloor >= 0 ? '${lossFloor.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원' : '미설정', AppTheme.textPrimary),
          _summaryRow('거래 시간', '${_fmt(_startTime)} ~ ${_fmt(_endTime)}', AppTheme.textPrimary),
          _summaryRow('분석 주기(TERM)', _termSeconds < 60 ? '${_termSeconds}초' : '${_termSeconds ~/ 60}분', AppTheme.textPrimary),
          _summaryRow('최대 거래 횟수', _maxTrades == 0 ? '무제한' : '$_maxTrades회', AppTheme.textPrimary),
          _summaryRow('목표 수익', '${(_targetProfitRate * 100).toStringAsFixed(1)}%', AppTheme.profit),
          _summaryRow('손절 기준', '-${(_stopLossRate * 100).toStringAsFixed(1)}%', AppTheme.loss),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }

  // ── 하단 버튼 ────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLastStep = _step == 3;
    final btnLabel = _step == 0
        ? '계좌 연동하기'
        : isLastStep ? '거래 시작 🚀' : '다음 단계';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_step == 0 ? _connectBroker : _saveAndNext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep ? AppTheme.profit : AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(btnLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            if (_step > 0) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _step--),
                child: Text('이전 단계', style: TextStyle(color: AppTheme.textTertiary)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: Text('설정 초기화', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('모든 거래 설정이 초기화됩니다. 계속하시겠습니까?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소', style: TextStyle(color: AppTheme.textTertiary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('초기화', style: TextStyle(color: AppTheme.loss))),
        ],
      ),
    );
    if (confirm == true) {
      await TradingApiService.resetSettings();
      setState(() { _step = 0; _settings = {}; });
      _loadCurrentSettings();
    }
  }

  // ── 공통 위젯 ─────────────────────────────────────────────
  Widget _sectionTitle(String title, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(sub, style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
    ],
  );

  Widget _label(String text) =>
      Text(text, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600));

  Widget _inputField(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppTheme.textTertiary),
        hintStyle: TextStyle(color: AppTheme.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.textTertiary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.textTertiary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.accent),
        ),
        filled: true,
        fillColor: AppTheme.cardBackground,
      ),
    );
  }
}
