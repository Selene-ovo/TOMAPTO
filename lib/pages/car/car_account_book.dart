// pages/car/car_account_book.dart
import 'package:flutter/material.dart';
import 'package:tomapto/modal/add_expense_modal.dart';
import 'package:tomapto/services/car_expense_service.dart';

class CarExpenseTracker extends StatefulWidget {
  const CarExpenseTracker({super.key});

  @override
  _CarExpenseTrackerState createState() => _CarExpenseTrackerState();
}

class _CarExpenseTrackerState extends State<CarExpenseTracker> {
  int _activeTab = 0; // 0: 홈, 1: 통계, 2: 캘린더
  bool _showAddExpense = false;
  bool _isLoading = true;

  // 캘린더 관련 상태
  DateTime _currentDate = DateTime.now();
  DateTime? _selectedDate;

  // 데이터 상태
  List<Map<String, dynamic>> _recentExpenses = [];
  Map<String, dynamic> _monthlyStats = {
    'total': 0,
    'fuel': 0,
    'maintenance': 0,
    'insurance': 0,
    'other': 0,
    'growth_rate': 0.0,
  };
  Map<String, dynamic> _dailyExpenses = {};
  List<Map<String, dynamic>> _selectedDateExpenses = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // 날짜 포맷팅 함수 - ISO 문자열을 일반 날짜로 변환
  String _formatDate(String isoDateString) {
    try {
      DateTime date = DateTime.parse(isoDateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      print('날짜 파싱 오류: $e');
      return isoDateString.split('T')[0]; // T가 있으면 앞부분만 반환
    }
  }

  // 모든 데이터 로드
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadRecentExpenses(),
        _loadMonthlyStats(),
        _loadDailyExpenses(),
      ]);
    } catch (e) {
      print('데이터 로드 오류: $e');
      _showErrorSnackBar('데이터를 불러오는데 실패했습니다.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 최근 지출 내역 로드
  Future<void> _loadRecentExpenses() async {
    try {
      final expenses = await CarExpenseService.getRecentExpenses(limit: 10);
      setState(() {
        _recentExpenses = expenses;
      });
    } catch (e) {
      print('최근 지출 로드 오류: $e');
    }
  }

  // 월간 통계 로드
  Future<void> _loadMonthlyStats() async {
    try {
      final stats = await CarExpenseService.getMonthlyStats(
        year: _currentDate.year,
        month: _currentDate.month,
      );
      print('받아온 월간 통계 데이터: $stats');
      setState(() {
        _monthlyStats = stats;
      });
    } catch (e) {
      print('월간 통계 로드 오류: $e');
    }
  }

  // 일별 지출 로드 (캘린더용)
  Future<void> _loadDailyExpenses() async {
    try {
      final dailyData = await CarExpenseService.getDailyExpenses(
        year: _currentDate.year,
        month: _currentDate.month,
      );

      print('=== 일별 지출 데이터 디버깅 ===');
      print('API 응답 데이터: $dailyData');
      print('데이터 타입: ${dailyData.runtimeType}');
      if (dailyData.isNotEmpty) {
        print(
          '첫 번째 키의 데이터: ${dailyData.keys.first} -> ${dailyData[dailyData.keys.first]}',
        );
      }
      print('===========================');

      setState(() {
        _dailyExpenses = dailyData;
      });

      // 캘린더 탭이 활성화되어 있고, 선택된 날짜가 없으며, 현재 월이 오늘과 같다면 오늘을 선택
      if (_activeTab == 2 && _selectedDate == null) {
        final today = DateTime.now();
        if (_currentDate.year == today.year &&
            _currentDate.month == today.month) {
          _selectDate(today);
        }
      }
    } catch (e) {
      print('일별 지출 로드 오류: $e');

      // 에러 발생 시 테스트 데이터 사용 (실제 지출이 있는 날짜들을 기반으로)
      final today = DateTime.now();
      if (_currentDate.year == today.year &&
          _currentDate.month == today.month) {
        // 최근 지출에서 날짜를 추출하여 캘린더에 표시
        Map<String, dynamic> testDailyData = {};

        for (var expense in _recentExpenses) {
          try {
            final expenseDate = _formatDate(expense['expense_date'].toString());
            final expenseDateTime = DateTime.parse(expenseDate);

            if (expenseDateTime.year == _currentDate.year &&
                expenseDateTime.month == _currentDate.month) {
              final day = expenseDateTime.day.toString();
              final amount =
                  double.tryParse(expense['amount'].toString()) ?? 0.0;

              if (testDailyData.containsKey(day)) {
                testDailyData[day]['total'] += amount;
                testDailyData[day]['count'] += 1;
              } else {
                testDailyData[day] = {'total': amount, 'count': 1};
              }
            }
          } catch (dateError) {
            print('날짜 파싱 오류: $dateError');
          }
        }

        print('최근 지출에서 생성한 일별 데이터: $testDailyData');

        setState(() {
          _dailyExpenses = testDailyData;
        });
      }
    }
  }

  // 특정 날짜의 지출 내역 로드
  Future<void> _loadExpensesForDate(DateTime date) async {
    try {
      // 새로운 API를 사용하여 특정 날짜의 지출만 가져오기
      final expenses = await CarExpenseService.getExpensesForDate(date);

      setState(() {
        _selectedDateExpenses = expenses;
      });
    } catch (e) {
      print('특정 날짜 지출 로드 오류: $e');
      // 오류 발생 시 빈 리스트로 설정
      setState(() {
        _selectedDateExpenses = [];
      });
    }
  }

  // 지출 추가 완료 후 데이터 새로고침
  Future<void> _onExpenseAdded() async {
    await _loadAllData();
    // 선택된 날짜가 있으면 해당 날짜의 지출도 새로고침
    if (_selectedDate != null) {
      await _loadExpensesForDate(_selectedDate!);
    }
  }

  // 이전/다음 달로 이동
  void _changeMonth(int direction) {
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month + direction,
        1,
      );
      _selectedDate = null; // 선택된 날짜 초기화
      _selectedDateExpenses = [];
    });
    _loadMonthlyStats();
    _loadDailyExpenses();
  }

  // 날짜 선택 처리
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadExpensesForDate(date);
  }

  // 에러 메시지 표시
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 지출 유형에 따른 아이콘 반환
  IconData _getExpenseIcon(String type) {
    switch (type) {
      case 'fuel':
        return Icons.local_gas_station;
      case 'maintenance':
        return Icons.build;
      case 'insurance':
        return Icons.shield;
      default:
        return Icons.receipt_long;
    }
  }

  // 지출 유형에 따른 색상 반환
  Color _getExpenseColor(String type) {
    switch (type) {
      case 'fuel':
        return Colors.blue;
      case 'maintenance':
        return Colors.orange;
      case 'insurance':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          // 메인 스캐폴드
          Scaffold(
            backgroundColor: Colors.grey[50],
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              title: const Text(
                '차계부',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Pretendard',
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
            ),
            body:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFFB233B),
                        ),
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadAllData,
                      color: const Color(0xFFFB233B),
                      child: Column(
                        children: [
                          Expanded(
                            child:
                                _activeTab == 0
                                    ? _buildHomeTab()
                                    : _activeTab == 1
                                    ? _buildStatsTab()
                                    : _buildCalendarTab(),
                          ),
                        ],
                      ),
                    ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBackButton(),
                        _buildAddButton(),
                        _buildNavItem(0, Icons.directions_car, '홈'),
                        _buildNavItem(1, Icons.pie_chart, '통계'),
                        _buildNavItem(2, Icons.calendar_today, '캘린더'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 지출 추가 모달
          if (_showAddExpense)
            Positioned.fill(
              child: Material(
                color: Colors.black.withOpacity(0.7),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAddExpense = false;
                    });
                  },
                  child: AddExpenseModal(
                    onClose: () {
                      setState(() {
                        _showAddExpense = false;
                      });
                    },
                    onExpenseAdded: _onExpenseAdded,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 하단 네비게이션 아이템 위젯
  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isActive = _activeTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = index;
          // 캘린더 탭으로 처음 이동할 때 오늘 날짜를 기본 선택
          if (index == 2 && _selectedDate == null) {
            final today = DateTime.now();
            // 현재 표시된 월과 오늘이 같은 월인지 확인
            if (_currentDate.year == today.year &&
                _currentDate.month == today.month) {
              _selectDate(today);
            }
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFFB233B) : Colors.grey,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFFB233B) : Colors.grey,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Pretendard',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 뒤로가기 버튼 위젯
  Widget _buildBackButton() {
    return InkWell(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: const Color(0xFFFB233B).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back, color: Color(0xFFFB233B), size: 18),
      ),
    );
  }

  // 추가 버튼 위젯
  Widget _buildAddButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _showAddExpense = true;
        });
      },
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: const Color(0xFFFB233B).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Color(0xFFFB233B), size: 18),
      ),
    );
  }

  // 홈 탭 위젯
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 월간 요약
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFB233B), Color(0xFFFF5C5C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          '이번 달 지출',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_monthlyStats['month'] ?? DateTime.now().month}월 ${_monthlyStats['year'] ?? DateTime.now().year}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${CarExpenseService.formatAmount(_monthlyStats['total'] ?? 0)}원',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '전월 대비 ${(_monthlyStats['growth_rate'] ?? 0) >= 0 ? '+' : ''}${(_monthlyStats['growth_rate'] ?? 0).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 카테고리별 요약
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  '주유비',
                  Icons.local_gas_station,
                  Colors.blue,
                  _monthlyStats['fuel'] ?? 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryCard(
                  '정비비',
                  Icons.build,
                  Colors.orange,
                  _monthlyStats['maintenance'] ?? 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 최근 지출 내역
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '최근 지출',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 12),
                if (_recentExpenses.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '아직 지출 내역이 없습니다.\n+ 버튼을 눌러 지출을 추가해보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
                  )
                else
                  // 최대 10개의 최근 지출 표시
                  ...List.generate(
                    _recentExpenses.length > 10 ? 10 : _recentExpenses.length,
                    (index) => _buildExpenseItem(_recentExpenses[index]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 카테고리 카드 위젯
  Widget _buildCategoryCard(
    String title,
    IconData icon,
    Color color,
    dynamic amount,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${CarExpenseService.formatAmount(amount)}원',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Pretendard',
            ),
          ),
        ],
      ),
    );
  }

  // 지출 항목 위젯
  Widget _buildExpenseItem(Map<String, dynamic> expense) {
    Color bgColor = _getExpenseColor(expense['expense_type']).withOpacity(0.1);
    Color borderColor = _getExpenseColor(
      expense['expense_type'],
    ).withOpacity(0.3);

    // 날짜 포맷팅
    final formattedDate = _formatDate(expense['expense_date'].toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아이콘
          Icon(
            _getExpenseIcon(expense['expense_type']),
            color: _getExpenseColor(expense['expense_type']),
            size: 24,
          ),
          const SizedBox(width: 12),

          // 설명과 날짜 (확장 가능)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense['description'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 금액 (고정 너비)
          Container(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              '${CarExpenseService.formatAmount(expense['amount'])}원',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Pretendard',
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 통계 탭 위젯
  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 월 선택 헤더
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_currentDate.year}년 ${_currentDate.month}월',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 월별 지출 분석
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '월별 지출 분석',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 16),
                if (_monthlyStats['total'] == 0)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '이번 달 지출 내역이 없습니다.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
                  )
                else ...[
                  _buildProgressBar(
                    '주유비',
                    _monthlyStats['fuel'] ?? 0,
                    Colors.blue,
                    (_monthlyStats['total'] > 0)
                        ? (_monthlyStats['fuel'] ?? 0) / _monthlyStats['total']
                        : 0,
                  ),
                  const SizedBox(height: 12),
                  _buildProgressBar(
                    '정비비',
                    _monthlyStats['maintenance'] ?? 0,
                    Colors.orange,
                    (_monthlyStats['total'] > 0)
                        ? (_monthlyStats['maintenance'] ?? 0) /
                            _monthlyStats['total']
                        : 0,
                  ),
                  const SizedBox(height: 12),
                  _buildProgressBar(
                    '보험료',
                    _monthlyStats['insurance'] ?? 0,
                    Colors.green,
                    (_monthlyStats['total'] > 0)
                        ? (_monthlyStats['insurance'] ?? 0) /
                            _monthlyStats['total']
                        : 0,
                  ),
                  if ((_monthlyStats['other'] ?? 0) > 0) ...[
                    const SizedBox(height: 12),
                    _buildProgressBar(
                      '기타',
                      _monthlyStats['other'] ?? 0,
                      Colors.grey,
                      (_monthlyStats['total'] > 0)
                          ? (_monthlyStats['other'] ?? 0) /
                              _monthlyStats['total']
                          : 0,
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 월간 요약
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            child: Column(
              children: [
                const Text(
                  '이번 달 총 지출',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${CarExpenseService.formatAmount(_monthlyStats['total'] ?? 0)}원',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFB233B),
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '전월 대비 ${(_monthlyStats['growth_rate'] ?? 0) >= 0 ? '+' : ''}${(_monthlyStats['growth_rate'] ?? 0).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color:
                        (_monthlyStats['growth_rate'] ?? 0) >= 0
                            ? Colors.red
                            : Colors.green,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 프로그레스 바 위젯
  Widget _buildProgressBar(
    String label,
    dynamic amount,
    Color color,
    double progress,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontFamily: 'Pretendard',
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${CarExpenseService.formatAmount(amount)}원',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 캘린더 탭 위젯
  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalendar(),
          const SizedBox(height: 20),
          _buildSelectedDateExpenses(),
        ],
      ),
    );
  }

  // 달력 위젯
  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    final lastDayOfMonth = DateTime(
      _currentDate.year,
      _currentDate.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday;
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 달력 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentDate.year}년 ${_currentDate.month}월',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Pretendard',
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    onPressed: () => _changeMonth(-1),
                    splashRadius: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () => _changeMonth(1),
                    splashRadius: 20,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 요일 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _weekdayLabel('일', Colors.red),
              _weekdayLabel('월'),
              _weekdayLabel('화'),
              _weekdayLabel('수'),
              _weekdayLabel('목'),
              _weekdayLabel('금'),
              _weekdayLabel('토', Colors.blue),
            ],
          ),
          const SizedBox(height: 8),

          // 날짜 그리드
          _buildCalendarGrid(
            firstDayOfMonth,
            lastDayOfMonth,
            firstWeekday,
            today,
          ),
        ],
      ),
    );
  }

  // 달력 그리드 생성
  Widget _buildCalendarGrid(
    DateTime firstDay,
    DateTime lastDay,
    int firstWeekday,
    DateTime today,
  ) {
    final totalDays = lastDay.day + (firstWeekday == 7 ? 0 : firstWeekday);
    final totalWeeks = (totalDays / 7).ceil();

    return Column(
      children: List.generate(totalWeeks, (weekIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (dayIndex) {
              final dayNumber =
                  weekIndex * 7 +
                  dayIndex +
                  1 -
                  (firstWeekday == 7 ? 0 : firstWeekday);
              final isThisMonth = dayNumber > 0 && dayNumber <= lastDay.day;

              if (!isThisMonth) {
                return const SizedBox(width: 40, height: 40);
              }

              final currentDayDate = DateTime(
                _currentDate.year,
                _currentDate.month,
                dayNumber,
              );
              final isToday =
                  currentDayDate.year == today.year &&
                  currentDayDate.month == today.month &&
                  currentDayDate.day == today.day;
              final isSelected =
                  _selectedDate != null &&
                  _selectedDate!.year == currentDayDate.year &&
                  _selectedDate!.month == currentDayDate.month &&
                  _selectedDate!.day == currentDayDate.day;

              // 해당 날짜에 지출이 있는지 확인 - _dailyExpenses에서 확인
              final dayString = dayNumber.toString();
              final dayData = _dailyExpenses[dayString];
              bool hasExpense = false;

              if (dayData != null) {
                if (dayData is Map) {
                  final total = dayData['total'];
                  hasExpense = (total != null && total > 0);
                  // 캘린더가 처음 렌더링될 때만 로그 출력 (과도한 로그 방지)
                  if (weekIndex == 0 && dayIndex == 0) {
                    print(
                      '캘린더 렌더링 - 지출이 있는 날짜들: ${_dailyExpenses.keys.toList()}',
                    );
                  }
                } else {
                  // dayData가 Map이 아닌 경우 (혹시 다른 형태로 올 수 있음)
                  print('예상과 다른 데이터 형태: ${dayData.runtimeType}');
                }
              }

              // 요일에 따른 색상
              Color dayColor = Colors.black;
              if (dayIndex == 0) dayColor = Colors.red;
              if (dayIndex == 6) dayColor = Colors.blue;

              return _dayCell(
                date: currentDayDate,
                day: dayNumber,
                isToday: isToday,
                isSelected: isSelected,
                hasExpense: hasExpense,
                textColor: dayColor,
                onTap: () => _selectDate(currentDayDate),
              );
            }),
          ),
        );
      }),
    );
  }

  // 요일 레이블 위젯
  Widget _weekdayLabel(String text, [Color color = Colors.black]) {
    return SizedBox(
      width: 40,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          fontFamily: 'Pretendard',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // 날짜 셀 위젯
  Widget _dayCell({
    required DateTime date,
    required int day,
    bool isToday = false,
    bool isSelected = false,
    bool hasExpense = false,
    Color textColor = Colors.black,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFFFB233B)
                  : isToday
                  ? const Color(0xFFFB233B).withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border:
              isToday && !isSelected
                  ? Border.all(color: const Color(0xFFFB233B), width: 1)
                  : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 날짜 숫자
            Text(
              day.toString(),
              style: TextStyle(
                color:
                    isSelected
                        ? Colors.white
                        : isToday
                        ? const Color(0xFFFB233B)
                        : textColor,
                fontWeight:
                    isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
                fontFamily: 'Pretendard',
              ),
            ),
            // 지출 표시 점 - 위치를 우상단으로 이동
            if (hasExpense)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFFFB233B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 선택된 날짜의 지출 목록
  Widget _buildSelectedDateExpenses() {
    if (_selectedDate == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.calendar_today, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '날짜를 선택하여 지출 내역을 확인하세요',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final selectedDateString =
        '${_selectedDate!.month}월 ${_selectedDate!.day}일';

    // 총 금액 계산 개선 - 타입 변환 보장
    double totalAmount = 0.0;
    for (var expense in _selectedDateExpenses) {
      var amount = expense['amount'];

      if (amount is int) {
        totalAmount += amount.toDouble();
      } else if (amount is double) {
        totalAmount += amount;
      } else if (amount is String) {
        totalAmount += double.tryParse(amount) ?? 0.0;
      } else {
        // 다른 타입인 경우 문자열로 변환 후 파싱
        totalAmount += double.tryParse(amount.toString()) ?? 0.0;
      }
    }

    // 총 금액이 0이 아닐 때만 로그 출력
    if (totalAmount > 0) {
      print(
        '선택된 날짜의 총 지출: ${CarExpenseService.formatAmount(totalAmount.round())}원 (${_selectedDateExpenses.length}건)',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$selectedDateString 지출',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  if (_selectedDateExpenses.isNotEmpty)
                    Text(
                      '총 ${CarExpenseService.formatAmount(totalAmount.round())}원',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFB233B),
                        fontFamily: 'Pretendard',
                      ),
                    ),
                ],
              ),
              if (_selectedDateExpenses.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB233B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedDateExpenses.length}건',
                    style: const TextStyle(
                      color: Color(0xFFFB233B),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 지출 목록
          if (_selectedDateExpenses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '선택한 날짜에 지출 내역이 없습니다',
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'Pretendard',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children:
                  _selectedDateExpenses
                      .map(
                        (expense) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildExpenseItem(expense),
                        ),
                      )
                      .toList(),
            ),
        ],
      ),
    );
  }
}
