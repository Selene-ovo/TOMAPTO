// lib/modal/edit_expense_modal.dart
import 'package:flutter/material.dart';
import 'package:tomapto/modal/date_picker_modal.dart';
import 'package:tomapto/services/car_expense_service.dart';

class EditExpenseModal extends StatefulWidget {
  final Map<String, dynamic> expense; // 수정할 지출 데이터
  final Function onClose;
  final Function? onExpenseUpdated; // 지출 수정/삭제 완료 후 콜백

  const EditExpenseModal({
    super.key,
    required this.expense,
    required this.onClose,
    this.onExpenseUpdated,
  });

  @override
  _EditExpenseModalState createState() => _EditExpenseModalState();
}

class _EditExpenseModalState extends State<EditExpenseModal> {
  String _selectedType = 'fuel';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // 기존 지출 데이터로 폼 초기화
  void _initializeData() {
    final expense = widget.expense;

    _selectedType = expense['expense_type'] ?? 'fuel';

    // 금액 처리 - 소수점 제거
    final amount = expense['amount'];
    if (amount != null) {
      if (amount is int) {
        _amountController.text = amount.toString();
      } else if (amount is double) {
        _amountController.text = amount.round().toString(); // 반올림 후 정수로 변환
      } else if (amount is String) {
        final parsedAmount = double.tryParse(amount) ?? 0.0;
        _amountController.text =
            parsedAmount.round().toString(); // 반올림 후 정수로 변환
      } else {
        final parsedAmount = double.tryParse(amount.toString()) ?? 0.0;
        _amountController.text =
            parsedAmount.round().toString(); // 반올림 후 정수로 변환
      }
    } else {
      _amountController.text = '0';
    }

    _descriptionController.text = expense['description'] ?? '';

    // 날짜 파싱
    try {
      final dateString = expense['expense_date']?.toString() ?? '';
      if (dateString.isNotEmpty) {
        // YYYY-MM-DD 형식의 날짜 파싱
        if (dateString.contains('T')) {
          _selectedDate = DateTime.parse(dateString);
        } else {
          // YYYY-MM-DD 형식인 경우
          final parts = dateString.split('-');
          if (parts.length == 3) {
            _selectedDate = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
        }
      }
    } catch (e) {
      print('날짜 파싱 오류: $e');
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // 날짜 선택 모달 표시
  void _showDatePicker() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder:
          (context) => DatePickerModal(
            initialDate: _selectedDate,
            onDateSelected: (DateTime newDate) {
              setState(() {
                _selectedDate = newDate;
              });
            },
          ),
    );
  }

  // 날짜를 월/일 형식으로 포맷팅
  String _formatDateToMonthDay(DateTime date) {
    return '${date.month}/${date.day}';
  }

  // 입력 유효성 검사
  bool _validateInputs() {
    if (_amountController.text.trim().isEmpty) {
      _showErrorSnackBar('금액을 입력해주세요.');
      return false;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('유효한 금액을 입력해주세요.');
      return false;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showErrorSnackBar('설명을 입력해주세요.');
      return false;
    }

    return true;
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

  // 성공 메시지 표시
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 지출 수정 처리
  Future<void> _updateExpense() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text.trim());
      final description = _descriptionController.text.trim();
      final expenseId = widget.expense['expense_id'];

      // CarExpenseService의 updateExpense 메서드 사용
      await CarExpenseService.updateExpense(
        expenseId: expenseId,
        expenseType: _selectedType,
        amount: amount,
        description: description,
        expenseDate: _selectedDate,
      );

      _showSuccessSnackBar('지출이 성공적으로 수정되었습니다.');

      // 부모 위젯에 지출 수정 완료 알림
      if (widget.onExpenseUpdated != null) {
        widget.onExpenseUpdated!();
      }

      widget.onClose();
    } catch (e) {
      _showErrorSnackBar('지출 수정에 실패했습니다: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 지출 삭제 처리
  Future<void> _deleteExpense() async {
    // 삭제 확인 다이얼로그
    final bool confirmDelete =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text(
                  '지출 삭제',
                  style: TextStyle(fontFamily: 'Pretendard'),
                ),
                content: const Text(
                  '이 지출을 정말 삭제하시겠습니까?\n삭제된 지출은 복구할 수 없습니다.',
                  style: TextStyle(fontFamily: 'Pretendard'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      '취소',
                      style: TextStyle(fontFamily: 'Pretendard'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      '삭제',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!confirmDelete) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final expenseId = widget.expense['expense_id'];
      await CarExpenseService.deleteExpense(expenseId);

      _showSuccessSnackBar('지출이 성공적으로 삭제되었습니다.');

      // 부모 위젯에 지출 삭제 완료 알림
      if (widget.onExpenseUpdated != null) {
        widget.onExpenseUpdated!();
      }

      widget.onClose();
    } catch (e) {
      _showErrorSnackBar('지출 삭제에 실패했습니다: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 모달 내부 클릭 시 포커스 해제 (키보드 닫기)
        FocusScope.of(context).unfocus();
      },
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          constraints: const BoxConstraints(maxHeight: 580, maxWidth: 400),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더 (제목 + 날짜 + 닫기 버튼)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '지출 수정',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Pretendard',
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 날짜 버튼
                            GestureDetector(
                              onTap: _showDatePicker,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatDateToMonthDay(_selectedDate),
                                    style: const TextStyle(
                                      color: Color(0xFF363636),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Pretendard',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Color(0xFF363636),
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => widget.onClose(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // 종류 선택
                    const Text(
                      '종류',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTypeButton(
                          'fuel',
                          '주유비',
                          Icons.local_gas_station,
                        ),
                        const SizedBox(width: 8),
                        _buildTypeButton('maintenance', '정비비', Icons.build),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTypeButton('insurance', '보험료', Icons.shield),
                        const SizedBox(width: 8),
                        _buildTypeButton('other', '기타', Icons.receipt_long),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // 금액 입력
                    _buildTextField(
                      '금액',
                      '금액을 입력하세요',
                      _amountController,
                      TextInputType.number,
                    ),
                    const SizedBox(height: 15),

                    // 설명 입력
                    _buildTextField(
                      '설명',
                      '예: 주유 - 셀프주유소',
                      _descriptionController,
                    ),
                    const SizedBox(height: 20),

                    // 수정/삭제 버튼 행
                    Row(
                      children: [
                        // 삭제 버튼
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _deleteExpense,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      '삭제',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Pretendard',
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 수정 버튼
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateExpense,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFB233B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      '수정',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Pretendard',
                                      ),
                                    ),
                          ),
                        ),
                      ],
                    ),

                    // 고정된 하단 여백
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon) {
    bool isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFFFB233B) : Colors.grey[300]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color:
                isSelected
                    ? const Color(0xFFFB233B).withOpacity(0.1)
                    : Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFFFB233B) : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFB233B) : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller, [
    TextInputType? keyboardType,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Pretendard',
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFB233B), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }
}
