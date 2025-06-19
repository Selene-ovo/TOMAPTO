// pages/car/car_account_book.dart
import 'package:flutter/material.dart';
import 'package:tomapto/modal/add_expense_modal.dart';

class CarExpenseTracker extends StatefulWidget {
  const CarExpenseTracker({super.key});

  @override
  _CarExpenseTrackerState createState() => _CarExpenseTrackerState();
}

class _CarExpenseTrackerState extends State<CarExpenseTracker> {
  int _activeTab = 0; // 0: 홈, 1: 통계, 2: 캘린더
  bool _showAddExpense = false;

  // 샘플 데이터
  final List<Map<String, dynamic>> _recentExpenses = [
    {
      'id': 1,
      'type': 'fuel',
      'amount': 65000,
      'date': '2025-06-15',
      'description': '주유 - 셀프주유소',
      'mileage': 45320,
    },
    {
      'id': 2,
      'type': 'maintenance',
      'amount': 120000,
      'date': '2025-06-10',
      'description': '엔진오일 교환',
      'mileage': 45100,
    },
    {
      'id': 3,
      'type': 'insurance',
      'amount': 83000,
      'date': '2025-06-01',
      'description': '자동차보험료',
      'mileage': null,
    },
    {
      'id': 4,
      'type': 'fuel',
      'amount': 58000,
      'date': '2025-05-28',
      'description': '주유 - GS칼텍스',
      'mileage': 44950,
    },
  ];

  final Map<String, int> _monthlyStats = {
    'total': 326000,
    'fuel': 123000,
    'maintenance': 120000,
    'insurance': 83000,
    'other': 0,
  };

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

  // 금액 포맷팅
  String _formatNumber(int num) {
    String numStr = num.toString();
    String result = '';
    int count = 0;

    for (int i = numStr.length - 1; i >= 0; i--) {
      result = numStr[i] + result;
      count++;
      if (count % 3 == 0 && i > 0) {
        result = ',$result';
      }
    }

    return result;
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
            body: Column(
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

          // 지출 추가 모달 - 분리된 파일에서 import
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
                      '6월 2025',
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
                  '${_formatNumber(_monthlyStats['total']!)}원',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '전월 대비 +12.3%',
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
                  _monthlyStats['fuel']!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCategoryCard(
                  '정비비',
                  Icons.build,
                  Colors.orange,
                  _monthlyStats['maintenance']!,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '최근 지출',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // 전체 내역 보기
                      },
                      child: const Text(
                        '전체보기',
                        style: TextStyle(
                          color: Color(0xFFFB233B),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  _recentExpenses.length > 3 ? 3 : _recentExpenses.length,
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
    int amount,
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
            '${_formatNumber(amount)}원',
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
    Color bgColor = _getExpenseColor(expense['type']).withOpacity(0.1);
    Color borderColor = _getExpenseColor(expense['type']).withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getExpenseIcon(expense['type']),
                color: _getExpenseColor(expense['type']),
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense['description'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expense['date'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatNumber(expense['amount'])}원',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Pretendard',
                ),
              ),
              if (expense['mileage'] != null)
                Text(
                  '${_formatNumber(expense['mileage'])}km',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontFamily: 'Pretendard',
                  ),
                ),
            ],
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
                _buildProgressBar(
                  '주유비',
                  _monthlyStats['fuel']!,
                  Colors.blue,
                  0.38,
                ),
                const SizedBox(height: 12),
                _buildProgressBar(
                  '정비비',
                  _monthlyStats['maintenance']!,
                  Colors.orange,
                  0.37,
                ),
                const SizedBox(height: 12),
                _buildProgressBar(
                  '보험료',
                  _monthlyStats['insurance']!,
                  Colors.green,
                  0.25,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 연비 분석
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
                  '연비 분석',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '12.4km/L',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFB233B),
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '평균 연비',
                  style: TextStyle(
                    color: Colors.grey,
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
    int amount,
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
                    '${_formatNumber(amount)}원',
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
          _buildCalendarExpenseList(),
        ],
      ),
    );
  }

  // 달력 위젯
  Widget _buildCalendar() {
    // 현재 날짜 정보
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    final currentDay = now.day;

    // 이번 달 첫 날과 마지막 날
    final firstDayOfMonth = DateTime(currentYear, currentMonth, 1);
    final lastDayOfMonth = DateTime(currentYear, currentMonth + 1, 0);

    // 이번 달 1일의 요일 (0: 일요일, 1: 월요일, ...)
    final firstWeekday = firstDayOfMonth.weekday;

    // 달력에 표시할 총 일 수 (이전 달 + 이번 달)
    final totalDays =
        lastDayOfMonth.day + (firstWeekday == 7 ? 0 : firstWeekday);

    // 주 수 계산
    final totalWeeks = (totalDays / 7).ceil();

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
                '$currentYear년 $currentMonth월',
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
                    onPressed: () {
                      // 이전 달로 이동
                    },
                    splashRadius: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () {
                      // 다음 달로 이동
                    },
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
          Column(
            children: List.generate(totalWeeks, (weekIndex) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (dayIndex) {
                  final dayNumber =
                      weekIndex * 7 +
                      dayIndex +
                      1 -
                      (firstWeekday == 7 ? 0 : firstWeekday);

                  // 이번 달에 속하는 날짜인지 확인
                  final isThisMonth =
                      dayNumber > 0 && dayNumber <= lastDayOfMonth.day;

                  // 오늘 날짜인지 확인
                  final isToday = isThisMonth && dayNumber == currentDay;

                  // 해당 날짜에 지출이 있는지 확인 (샘플 데이터 기준)
                  final hasExpense =
                      isThisMonth &&
                      _recentExpenses.any((expense) {
                        final date = expense['date'] as String;
                        final day = int.tryParse(date.split('-').last) ?? 0;
                        return day == dayNumber;
                      });

                  // 요일에 따른 색상 결정
                  Color dayColor = Colors.black;
                  if (dayIndex == 0) dayColor = Colors.red; // 일요일
                  if (dayIndex == 6) dayColor = Colors.blue; // 토요일

                  return _dayCell(
                    day: dayNumber,
                    isThisMonth: isThisMonth,
                    isToday: isToday,
                    hasExpense: hasExpense,
                    textColor: dayColor,
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }

  // 요일 레이블 위젯
  Widget _weekdayLabel(String text, [Color color = Colors.black]) {
    return SizedBox(
      width: 30,
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
    required int day,
    required bool isThisMonth,
    bool isToday = false,
    bool hasExpense = false,
    Color textColor = Colors.black,
  }) {
    return Container(
      width: 30,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFFB233B) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 날짜 숫자
          Text(
            isThisMonth ? day.toString() : '',
            style: TextStyle(
              color: isToday ? Colors.white : textColor,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
              fontFamily: 'Pretendard',
            ),
          ),
          // 지출 표시 점
          if (hasExpense && !isToday)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFFB233B),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  // 선택 날짜 지출 목록
  Widget _buildCalendarExpenseList() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '6월 15일 지출',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Pretendard',
                ),
              ),
              Text(
                '${_formatNumber(_recentExpenses[0]['amount'])}원',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFB233B),
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 해당 날짜의 지출 항목 표시
          _buildExpenseItem(_recentExpenses[0]),
        ],
      ),
    );
  }
}
