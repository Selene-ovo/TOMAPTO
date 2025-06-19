// lib/modal/add_expense_modal.dart
import 'package:flutter/material.dart';
import 'package:tomapto/modal/date_picker_modal.dart';

class AddExpenseModal extends StatefulWidget {
  final Function onClose;

  const AddExpenseModal({super.key, required this.onClose});

  @override
  _AddExpenseModalState createState() => _AddExpenseModalState();
}

class _AddExpenseModalState extends State<AddExpenseModal> {
  String _selectedType = 'fuel';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

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
          constraints: const BoxConstraints(maxHeight: 530, maxWidth: 400),
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
                              '지출 추가',
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

                    // 추가 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // 지출 추가 로직
                          // TODO: 서버에 데이터 전송
                          // 데이터: _selectedType, _amountController.text, _descriptionController.text, _selectedDate

                          widget.onClose();
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
                        child: const Text(
                          '추가',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ),
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
