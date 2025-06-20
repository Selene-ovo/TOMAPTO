// pages/car/car_account_book.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tomapto/modal/add_expense_modal.dart';
import 'package:tomapto/modal/date_picker_modal.dart';
import 'package:tomapto/services/car_expense_service.dart';
import 'package:tomapto/modal/edit_expense_modal.dart';
import 'package:tomapto/controllers/car/car_account_controller.dart';

// 오버스크롤 glow 효과 제거를 위한 커스텀 클래스
class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // 오버스크롤 효과 제거
  }
}

class CarExpenseTracker extends StatefulWidget {
  const CarExpenseTracker({super.key});

  @override
  _CarExpenseTrackerState createState() => _CarExpenseTrackerState();
}

class _CarExpenseTrackerState extends State<CarExpenseTracker> {
  late CarAccountController controller;

  @override
  void initState() {
    super.initState();
    controller = CarAccountController();
    controller.initialize(setState);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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

  // 년월 선택 모달 표시
  void _showYearMonthPicker() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder:
          (context) => YearMonthPickerModal(
            initialDate: controller.homeCurrentDate,
            onDateSelected: (DateTime newDate) {
              controller.changeHomeMonth(newDate);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder:
            (context) => ScrollConfiguration(
              behavior: NoGlowScrollBehavior(),
              child: GestureDetector(
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
                        systemOverlayStyle: const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: Brightness.dark,
                          statusBarBrightness: Brightness.light,
                        ),
                        scrolledUnderElevation: 0,
                        surfaceTintColor: Colors.transparent,
                      ),
                      body:
                          controller.isLoading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFB233B),
                                  ),
                                ),
                              )
                              : NotificationListener<
                                OverscrollIndicatorNotification
                              >(
                                onNotification: (notification) {
                                  notification.disallowIndicator();
                                  return true;
                                },
                                child: RefreshIndicator(
                                  onRefresh: () async {
                                    try {
                                      await controller.loadAllData();
                                    } catch (e) {
                                      _showErrorSnackBar('데이터를 불러오는데 실패했습니다.');
                                    }
                                  },
                                  color: const Color(0xFFFB233B),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child:
                                            controller.activeTab == 0
                                                ? _buildHomeTab()
                                                : controller.activeTab == 1
                                                ? _buildStatsTab()
                                                : _buildCalendarTab(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      bottomNavigationBar: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 20,
                        ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
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
                    if (controller.showAddExpense)
                      Positioned.fill(
                        child: Material(
                          color: Colors.black.withOpacity(0.7),
                          child: GestureDetector(
                            onTap:
                                () => controller.toggleAddExpenseModal(false),
                            child: AddExpenseModal(
                              onClose:
                                  () => controller.toggleAddExpenseModal(false),
                              onExpenseAdded: controller.onExpenseChanged,
                            ),
                          ),
                        ),
                      ),

                    // 지출 수정 모달
                    if (controller.showEditExpense &&
                        controller.selectedExpenseForEdit != null)
                      Positioned.fill(
                        child: Material(
                          color: Colors.black.withOpacity(0.7),
                          child: GestureDetector(
                            onTap:
                                () => controller.toggleEditExpenseModal(false),
                            child: EditExpenseModal(
                              expense: controller.selectedExpenseForEdit!,
                              onClose:
                                  () =>
                                      controller.toggleEditExpenseModal(false),
                              onExpenseUpdated: controller.onExpenseChanged,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  // 하단 네비게이션 아이템 위젯
  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isActive = controller.activeTab == index;
    return InkWell(
      onTap: () => controller.changeTab(index),
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
      onTap: () => controller.toggleAddExpenseModal(true),
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
    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: SingleChildScrollView(
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
                            '이 달 지출',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _showYearMonthPicker,
                        child: Text(
                          '${controller.homeCurrentDate.year}년 ${controller.homeCurrentDate.month}월',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${CarExpenseService.formatAmount(controller.homeMonthlyStats['total'] ?? 0)}원',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '전월 대비 ${(controller.homeMonthlyStats['growth_rate'] ?? 0) >= 0 ? '+' : ''}${(controller.homeMonthlyStats['growth_rate'] ?? 0).toStringAsFixed(1)}%',
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
                    controller.homeMonthlyStats['fuel'] ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryCard(
                    '정비비',
                    Icons.build,
                    Colors.orange,
                    controller.homeMonthlyStats['maintenance'] ?? 0,
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
                  if (controller.recentExpenses.isEmpty)
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
                    ...List.generate(
                      controller.recentExpenses.length > 10
                          ? 10
                          : controller.recentExpenses.length,
                      (index) =>
                          _buildExpenseItem(controller.recentExpenses[index]),
                    ),
                ],
              ),
            ),
          ],
        ),
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
    Color bgColor = controller
        .getExpenseColor(expense['expense_type'])
        .withOpacity(0.1);
    Color borderColor = controller
        .getExpenseColor(expense['expense_type'])
        .withOpacity(0.3);

    final formattedDate = controller.formatDate(
      expense['expense_date'].toString(),
    );

    return GestureDetector(
      onTap: () => controller.onExpenseItemTap(expense),
      child: Container(
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
            Icon(
              controller.getExpenseIcon(expense['expense_type']),
              color: controller.getExpenseColor(expense['expense_type']),
              size: 24,
            ),
            const SizedBox(width: 12),
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
      ),
    );
  }

  // 통계 탭 위젯
  Widget _buildStatsTab() {
    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: SingleChildScrollView(
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
                    onPressed: () => controller.changeCalendarMonth(-1),
                  ),
                  Text(
                    '${controller.calendarCurrentDate.year}년 ${controller.calendarCurrentDate.month}월',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () => controller.changeCalendarMonth(1),
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
                  if (controller.statsMonthlyStats['total'] == 0)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          '이 달 지출 내역이 없습니다.',
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
                      controller.statsMonthlyStats['fuel'] ?? 0,
                      Colors.blue,
                      (controller.statsMonthlyStats['total'] > 0)
                          ? (controller.statsMonthlyStats['fuel'] ?? 0) /
                              controller.statsMonthlyStats['total']
                          : 0,
                    ),
                    const SizedBox(height: 12),
                    _buildProgressBar(
                      '정비비',
                      controller.statsMonthlyStats['maintenance'] ?? 0,
                      Colors.orange,
                      (controller.statsMonthlyStats['total'] > 0)
                          ? (controller.statsMonthlyStats['maintenance'] ?? 0) /
                              controller.statsMonthlyStats['total']
                          : 0,
                    ),
                    const SizedBox(height: 12),
                    _buildProgressBar(
                      '보험료',
                      controller.statsMonthlyStats['insurance'] ?? 0,
                      Colors.green,
                      (controller.statsMonthlyStats['total'] > 0)
                          ? (controller.statsMonthlyStats['insurance'] ?? 0) /
                              controller.statsMonthlyStats['total']
                          : 0,
                    ),
                    if ((controller.statsMonthlyStats['other'] ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      _buildProgressBar(
                        '기타',
                        controller.statsMonthlyStats['other'] ?? 0,
                        Colors.grey,
                        (controller.statsMonthlyStats['total'] > 0)
                            ? (controller.statsMonthlyStats['other'] ?? 0) /
                                controller.statsMonthlyStats['total']
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
                    '이 달 총 지출',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${CarExpenseService.formatAmount(controller.statsMonthlyStats['total'] ?? 0)}원',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFB233B),
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '전월 대비 ${(controller.statsMonthlyStats['growth_rate'] ?? 0) >= 0 ? '+' : ''}${(controller.statsMonthlyStats['growth_rate'] ?? 0).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color:
                          (controller.statsMonthlyStats['growth_rate'] ?? 0) >=
                                  0
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
    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendar(),
            const SizedBox(height: 20),
            _buildSelectedDateExpenses(),
          ],
        ),
      ),
    );
  }

  // 달력 위젯
  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(
      controller.calendarCurrentDate.year,
      controller.calendarCurrentDate.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      controller.calendarCurrentDate.year,
      controller.calendarCurrentDate.month + 1,
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
                '${controller.calendarCurrentDate.year}년 ${controller.calendarCurrentDate.month}월',
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
                    onPressed: () => controller.changeCalendarMonth(-1),
                    splashRadius: 20,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () => controller.changeCalendarMonth(1),
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
                controller.calendarCurrentDate.year,
                controller.calendarCurrentDate.month,
                dayNumber,
              );
              final isToday =
                  currentDayDate.year == today.year &&
                  currentDayDate.month == today.month &&
                  currentDayDate.day == today.day;
              final isSelected =
                  controller.selectedDate != null &&
                  controller.selectedDate!.year == currentDayDate.year &&
                  controller.selectedDate!.month == currentDayDate.month &&
                  controller.selectedDate!.day == currentDayDate.day;

              // 지출 표시 로직
              bool hasExpense = false;
              if (controller.dailyExpenses.isNotEmpty) {
                final dayString = dayNumber.toString();
                final dayData = controller.dailyExpenses[dayString];

                if (dayData != null && dayData is Map<String, dynamic>) {
                  final total = dayData['total'];
                  final dateStr = dayData['date'];

                  if (total != null &&
                      total is num &&
                      total > 0 &&
                      dateStr != null) {
                    try {
                      final expenseDate = DateTime.parse(dateStr.toString());
                      if (expenseDate.year ==
                              controller.calendarCurrentDate.year &&
                          expenseDate.month ==
                              controller.calendarCurrentDate.month &&
                          expenseDate.day == dayNumber) {
                        hasExpense = true;
                      }
                    } catch (e) {
                      print('날짜 파싱 오류 ($dayNumber일): $e');
                    }
                  }
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
                onTap: () => controller.selectDate(currentDayDate),
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
    if (controller.selectedDate == null) {
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
        '${controller.selectedDate!.month}월 ${controller.selectedDate!.day}일';

    // 총 금액 계산
    double totalAmount = 0.0;
    for (var expense in controller.selectedDateExpenses) {
      var amount = expense['amount'];
      if (amount is int) {
        totalAmount += amount.toDouble();
      } else if (amount is double) {
        totalAmount += amount;
      } else if (amount is String) {
        totalAmount += double.tryParse(amount) ?? 0.0;
      } else {
        totalAmount += double.tryParse(amount.toString()) ?? 0.0;
      }
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
                  if (controller.selectedDateExpenses.isNotEmpty)
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
              if (controller.selectedDateExpenses.isNotEmpty)
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
                    '${controller.selectedDateExpenses.length}건',
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
          if (controller.selectedDateExpenses.isEmpty)
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
                  controller.selectedDateExpenses
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
