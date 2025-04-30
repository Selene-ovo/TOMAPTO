// mapSetting.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapSettingsScreen extends StatefulWidget {
  const MapSettingsScreen({Key? key}) : super(key: key);

  @override
  State<MapSettingsScreen> createState() => _MapSettingsScreenState();
}

class _MapSettingsScreenState extends State<MapSettingsScreen> {
  // 선택된 글자 크기 (0: 작게, 1: 보통, 2: 크게)
  int _selectedFontSize = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 저장된 설정 불러오기
    _loadSettings();
  }

  // 설정 불러오기
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _selectedFontSize = prefs.getInt('map_font_size') ?? 1;
    });
  }

  // 설정 저장하기
  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('map_font_size', _selectedFontSize);
    
    setState(() {
      _isSaving = false;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('지도 설정이 저장되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '지도',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () {
            // 뒤로 가기 전에 설정 저장
            _saveSettings().then((_) {
              Navigator.pop(context);
            });
          },
        ),
        // 저장 버튼 추가
        actions: [
          _isSaving
              ? Container(
                  padding: const EdgeInsets.all(10),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveSettings,
                  child: const Text(
                    '저장',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 2),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '지도 글자 크기',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    _buildFontSizeOption(0, '가', 14),
                    const SizedBox(width: 16),
                    _buildFontSizeOption(1, '가', 16),
                    const SizedBox(width: 16),
                    _buildFontSizeOption(2, '가', 18),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeOption(int index, String text, double fontSize) {
    bool isSelected = _selectedFontSize == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFontSize = index;
        });
      },
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          color: isSelected ? Colors.red : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}