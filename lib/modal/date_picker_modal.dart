// lib/modal/date_picker_modal.dart
import 'package:flutter/material.dart';

class DatePickerModal extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const DatePickerModal({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  _DatePickerModalState createState() => _DatePickerModalState();
}

class _DatePickerModalState extends State<DatePickerModal> {
  late DateTime selectedDate;
  late PageController _pageController;
  late int currentYear;
  late int currentMonth;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    currentYear = selectedDate.year;
    currentMonth = selectedDate.month;
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 월 이름 반환
  String getMonthName(int month) {
    const months = [
      '1월',
      '2월',
      '3월',
      '4월',
      '5월',
      '6월',
      '7월',
      '8월',
      '9월',
      '10월',
      '11월',
      '12월',
    ];
    return months[month - 1];
  }

  // 요일 이름 반환
  String getWeekdayName(int weekday) {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return weekdays[weekday % 7];
  }

  // 해당 월의 일 수 반환
  int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  // 해당 월 1일의 요일 반환 (일요일: 0, 월요일: 1, ...)
  int getFirstWeekday(int year, int month) {
    return DateTime(year, month, 1).weekday % 7;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '날짜 선택',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 년/월 선택 및 네비게이션
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 16),
                      onPressed: () {
                        setState(() {
                          if (currentMonth == 1) {
                            currentMonth = 12;
                            currentYear--;
                          } else {
                            currentMonth--;
                          }
                        });
                      },
                    ),
                    Text(
                      '$currentYear년 ${getMonthName(currentMonth)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      onPressed: () {
                        setState(() {
                          if (currentMonth == 12) {
                            currentMonth = 1;
                            currentYear++;
                          } else {
                            currentMonth++;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 요일 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _weekdayHeader('일', Colors.red),
                    _weekdayHeader('월'),
                    _weekdayHeader('화'),
                    _weekdayHeader('수'),
                    _weekdayHeader('목'),
                    _weekdayHeader('금'),
                    _weekdayHeader('토', Colors.blue),
                  ],
                ),
                const SizedBox(height: 10),

                // 달력 그리드
                _buildCalendarGrid(),

                const SizedBox(height: 20),

                // 확인 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onDateSelected(selectedDate);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFB233B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '${selectedDate.month}월 ${selectedDate.day}일 선택',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _weekdayHeader(String text, [Color color = Colors.black]) {
    return SizedBox(
      width: 35,
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

  Widget _buildCalendarGrid() {
    final daysInMonth = getDaysInMonth(currentYear, currentMonth);
    final firstWeekday = getFirstWeekday(currentYear, currentMonth);
    final totalCells = ((daysInMonth + firstWeekday) / 7).ceil() * 7;
    final numberOfWeeks = (totalCells / 7).ceil();

    return Column(
      children: List.generate(numberOfWeeks, (weekIndex) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (dayIndex) {
              final cellIndex = weekIndex * 7 + dayIndex;
              final dayNumber = cellIndex - firstWeekday + 1;
              final isValidDay = dayNumber > 0 && dayNumber <= daysInMonth;

              if (!isValidDay) {
                return const SizedBox(width: 35, height: 35);
              }

              final dayDate = DateTime(currentYear, currentMonth, dayNumber);
              final isSelected =
                  selectedDate.year == currentYear &&
                  selectedDate.month == currentMonth &&
                  selectedDate.day == dayNumber;
              final isToday =
                  DateTime.now().year == currentYear &&
                  DateTime.now().month == currentMonth &&
                  DateTime.now().day == dayNumber;

              // 요일에 따른 색상
              final weekday = dayIndex;
              Color textColor = Colors.black;
              if (weekday == 0) textColor = Colors.red; // 일요일
              if (weekday == 6) textColor = Colors.blue; // 토요일

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDate = dayDate;
                  });
                },
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? const Color(0xFFFB233B)
                            : isToday
                            ? const Color(0xFFFB233B).withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        isToday && !isSelected
                            ? Border.all(
                              color: const Color(0xFFFB233B),
                              width: 1,
                            )
                            : null,
                  ),
                  child: Center(
                    child: Text(
                      dayNumber.toString(),
                      style: TextStyle(
                        color:
                            isSelected
                                ? Colors.white
                                : isToday
                                ? const Color(0xFFFB233B)
                                : textColor,
                        fontWeight:
                            isSelected || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
