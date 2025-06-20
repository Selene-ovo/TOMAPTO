// controllers/car/car_account_controller.dart
import 'package:flutter/material.dart';
import 'package:tomapto/services/car_expense_service.dart';

class CarAccountController {
  // 상태 변수들
  int activeTab = 0; // 0: 홈, 1: 통계, 2: 캘린더
  bool showAddExpense = false;
  bool showEditExpense = false;
  bool isLoading = true;

  // 날짜 관련 상태
  DateTime homeCurrentDate = DateTime.now();
  DateTime calendarCurrentDate = DateTime.now();
  DateTime? selectedDate;

  // 지출 수정용 상태
  Map<String, dynamic>? selectedExpenseForEdit;

  // 데이터 상태
  List<Map<String, dynamic>> recentExpenses = [];
  Map<String, dynamic> homeMonthlyStats = {
    'total': 0,
    'fuel': 0,
    'maintenance': 0,
    'insurance': 0,
    'other': 0,
    'growth_rate': 0.0,
  };
  Map<String, dynamic> statsMonthlyStats = {
    'total': 0,
    'fuel': 0,
    'maintenance': 0,
    'insurance': 0,
    'other': 0,
    'growth_rate': 0.0,
  };
  Map<String, dynamic> dailyExpenses = {};
  List<Map<String, dynamic>> selectedDateExpenses = [];

  // setState 함수를 저장할 변수
  late Function(VoidCallback) setState;

  // 컨트롤러 초기화
  void initialize(Function(VoidCallback) setStateFunction) {
    setState = setStateFunction;
    loadAllData();
  }

  // 날짜 포맷팅 함수
  String formatDate(String isoDateString) {
    try {
      DateTime date = DateTime.parse(isoDateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      print('날짜 파싱 오류: $e');
      return isoDateString.split('T')[0];
    }
  }

  // 모든 데이터 로드
  Future<void> loadAllData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Future.wait([
        loadRecentExpenses(),
        loadHomeMonthlyStats(),
        loadStatsMonthlyStats(),
        loadDailyExpenses(),
      ]);
    } catch (e) {
      print('데이터 로드 오류: $e');
      // 에러 처리는 UI에서 할 수 있도록 에러를 다시 던집니다
      rethrow;
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 최근 지출 내역 로드
  Future<void> loadRecentExpenses() async {
    try {
      final expenses = await CarExpenseService.getRecentExpenses(limit: 10);
      setState(() {
        recentExpenses = expenses;
      });
    } catch (e) {
      print('최근 지출 로드 오류: $e');
      rethrow;
    }
  }

  // 홈 탭 월간 통계 로드
  Future<void> loadHomeMonthlyStats() async {
    try {
      final stats = await CarExpenseService.getMonthlyStats(
        year: homeCurrentDate.year,
        month: homeCurrentDate.month,
      );
      setState(() {
        homeMonthlyStats = stats;
      });
    } catch (e) {
      rethrow;
    }
  }

  // 통계 탭 월간 통계 로드
  Future<void> loadStatsMonthlyStats() async {
    try {
      final stats = await CarExpenseService.getMonthlyStats(
        year: calendarCurrentDate.year,
        month: calendarCurrentDate.month,
      );
      setState(() {
        statsMonthlyStats = stats;
      });
    } catch (e) {
      rethrow;
    }
  }

  // 일별 지출 로드 (캘린더용)
  Future<void> loadDailyExpenses() async {
    try {
      final dailyData = await CarExpenseService.getDailyExpenses(
        year: calendarCurrentDate.year,
        month: calendarCurrentDate.month,
      );
      if (dailyData.isNotEmpty) {}

      // 항상 상태를 업데이트 (탭 조건 제거)
      setState(() {
        dailyExpenses = dailyData;
      });

      // 선택된 날짜가 없으며, 현재 월이 오늘과 같다면 오늘을 선택 (캘린더 탭인 경우에만)
      if (activeTab == 2 && selectedDate == null) {
        final today = DateTime.now();
        if (calendarCurrentDate.year == today.year &&
            calendarCurrentDate.month == today.month) {
          selectDate(today);
        }
      }
    } catch (e) {
      print('일별 지출 로드 오류: $e');
      setState(() {
        dailyExpenses = {};
      });
      rethrow;
    }
  }

  // 특정 날짜의 지출 내역 로드
  Future<void> loadExpensesForDate(DateTime date) async {
    try {
      final expenses = await CarExpenseService.getExpensesForDate(date);
      setState(() {
        selectedDateExpenses = expenses;
      });
    } catch (e) {
      print('특정 날짜 지출 로드 오류: $e');
      setState(() {
        selectedDateExpenses = [];
      });
      rethrow;
    }
  }

  // 지출 추가/수정 완료 후 데이터 새로고침
  Future<void> onExpenseChanged() async {
    await loadRecentExpenses();
    await loadHomeMonthlyStats();

    // 현재 활성 탭에 따라 추가 데이터 로드
    if (activeTab == 1) {
      await loadStatsMonthlyStats();
    } else if (activeTab == 2) {
      // 캘린더 탭인 경우 일별 지출과 선택된 날짜 지출 모두 새로고침
      await loadDailyExpenses();
      if (selectedDate != null) {
        await loadExpensesForDate(selectedDate!);
      }
    }

    // 모든 탭에 대해 강제로 데이터 새로고침 (캘린더 탭이 아니어도)
    // 사용자가 다른 탭에서 수정한 후 캘린더 탭으로 돌아왔을 때를 대비
    if (activeTab != 1) {
      await loadStatsMonthlyStats();
    }
    if (activeTab != 2) {
      // activeTab이 2가 아닌 경우에도 일별 지출 데이터를 강제로 새로고침
      final currentActiveTab = activeTab; // 현재 탭 저장
      activeTab = 2; // 임시로 캘린더 탭으로 변경
      await loadDailyExpenses();
      activeTab = currentActiveTab; // 원래 탭으로 복원

      if (selectedDate != null) {
        await loadExpensesForDate(selectedDate!);
      }
    }
  }

  // 홈 탭 년월 변경
  void changeHomeMonth(DateTime newDate) {
    setState(() {
      homeCurrentDate = newDate;
    });
    loadHomeMonthlyStats();
  }

  // 캘린더/통계 탭 년월 변경
  void changeCalendarMonth(int direction) {
    setState(() {
      calendarCurrentDate = DateTime(
        calendarCurrentDate.year,
        calendarCurrentDate.month + direction,
        1,
      );
      selectedDate = null;
      selectedDateExpenses = [];

      // 캘린더 탭에서 월 변경 시 즉시 일별 지출 데이터 완전 초기화
      dailyExpenses = {}; // 이전 월 데이터 즉시 제거
    });

    // 다음 프레임에서 데이터 로드 (위젯 재빌드 완료 후)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (activeTab == 1) {
        loadStatsMonthlyStats();
      } else if (activeTab == 2) {
        loadDailyExpenses();
      }
    });
  }

  // 날짜 선택 처리
  void selectDate(DateTime date) {
    setState(() {
      selectedDate = date;
    });
    loadExpensesForDate(date);
  }

  // 탭 변경 처리
  void changeTab(int index) {
    setState(() {
      activeTab = index;

      // 캘린더 탭으로 전환할 때 일별 지출 데이터 로드
      if (index == 2) {
        loadDailyExpenses();
        if (selectedDate == null) {
          final today = DateTime.now();
          if (calendarCurrentDate.year == today.year &&
              calendarCurrentDate.month == today.month) {
            selectDate(today);
          }
        }
      }
    });
  }

  // 지출 추가 모달 표시/숨김
  void toggleAddExpenseModal(bool show) {
    setState(() {
      showAddExpense = show;
    });
  }

  // 지출 수정 모달 표시/숨김
  void toggleEditExpenseModal(bool show, [Map<String, dynamic>? expense]) {
    setState(() {
      showEditExpense = show;
      selectedExpenseForEdit = expense;
    });
  }

  // 지출 항목 클릭 처리
  void onExpenseItemTap(Map<String, dynamic> expense) {
    toggleEditExpenseModal(true, expense);
  }

  // 지출 유형에 따른 아이콘 반환
  IconData getExpenseIcon(String type) {
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
  Color getExpenseColor(String type) {
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

  void dispose() {}
}
