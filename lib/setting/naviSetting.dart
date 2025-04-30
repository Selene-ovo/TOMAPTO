import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationSettingsScreen extends StatefulWidget {
  const NavigationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NavigationSettingsScreen> createState() => _NavigationSettingsScreenState();
}

class _NavigationSettingsScreenState extends State<NavigationSettingsScreen> {
  // 버튼 상태 관리
  String _selectedMapType = '일반지도';
  String _selectedNightMode = '자동';
  String _selectedMapView = '3D';
  
  // 토글 상태 관리
  bool _showTrafficInfo = true;
  bool _showVehicleInfo = true;
  bool _showBuildingEntrance = true;
  
  // 저장 중 상태
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    // 앱이 시작될 때 저장된 설정 불러오기
    _loadSettings();
  }
  
  // 설정 불러오기
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      // 기본값이 있는 getString 사용
      _selectedMapType = prefs.getString('nav_map_type') ?? '일반지도';
      _selectedNightMode = prefs.getString('nav_night_mode') ?? '자동';
      _selectedMapView = prefs.getString('nav_map_view') ?? '3D';
      
      // 기본값이 있는 getBool 사용
      _showTrafficInfo = prefs.getBool('nav_show_traffic') ?? true;
      _showVehicleInfo = prefs.getBool('nav_show_vehicle') ?? true;
      _showBuildingEntrance = prefs.getBool('nav_show_building') ?? true;
    });
  }
  
  // 설정 저장하기
  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });
    
    final prefs = await SharedPreferences.getInstance();
    
    // 설정값 저장
    await prefs.setString('nav_map_type', _selectedMapType);
    await prefs.setString('nav_night_mode', _selectedNightMode);
    await prefs.setString('nav_map_view', _selectedMapView);
    
    await prefs.setBool('nav_show_traffic', _showTrafficInfo);
    await prefs.setBool('nav_show_vehicle', _showVehicleInfo);
    await prefs.setBool('nav_show_building', _showBuildingEntrance);
    
    // 저장 완료 후 상태 업데이트
    setState(() {
      _isSaving = false;
    });
    
    // 저장 완료 알림
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정이 저장되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '내비게이션',
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
                      color: Color(0xFFFF3B30),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('지도'),
                  _buildMapTypeSelector(),
                ],
              ),
            ),
            
            const SizedBox(height: 1), // 1픽셀 구분선
            
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('야간모드'),
                  _buildNightModeSelector(),
                ],
              ),
            ),
            
            const SizedBox(height: 1), // 1픽셀 구분선
            
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('지도 뷰모드'),
                  _buildMapViewSelector(),
                ],
              ),
            ),
            
            const SizedBox(height: 1), // 1픽셀 구분선
            
            Container(
              color: Colors.white,
              child: _buildSwitchRow('노면 색깔 유도선 표시'),
            ),
            
            const SizedBox(height: 1), // 1픽셀 구분선
            
            Container(
              color: Colors.white,
              child: _buildSwitchRow('지도 위에 차로정보 표시'),
            ),
            
            const SizedBox(height: 1), // 1픽셀 구분선
            
            Container(
              color: Colors.white,
              child: _buildSwitchRow('건물 입체 표현'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
  
  Widget _buildMapTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSelectButton('일반지도', _selectedMapType == '일반지도', () {
          setState(() {
            _selectedMapType = '일반지도';
          });
        }),
        _buildSelectButton('위성지도', _selectedMapType == '위성지도', () {
          setState(() {
            _selectedMapType = '위성지도';
          });
        }),
      ],
    );
  }
  
  Widget _buildNightModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSelectButton('자동', _selectedNightMode == '자동', () {
          setState(() {
            _selectedNightMode = '자동';
          });
        }, width: 110),
        _buildSelectButton('항상', _selectedNightMode == '항상', () {
          setState(() {
            _selectedNightMode = '항상';
          });
        }, width: 110),
        _buildSelectButton('사용 안함', _selectedNightMode == '사용 안함', () {
          setState(() {
            _selectedNightMode = '사용 안함';
          });
        }, width: 110),
      ],
    );
  }
  
  Widget _buildMapViewSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSelectButton('3D', _selectedMapView == '3D', () {
          setState(() {
            _selectedMapView = '3D';
          });
        }, width: 110),
        _buildSelectButton('2D', _selectedMapView == '2D', () {
          setState(() {
            _selectedMapView = '2D';
          });
        }, width: 110),
        _buildSelectButton('평북고정', _selectedMapView == '평북고정', () {
          setState(() {
            _selectedMapView = '평북고정';
          });
        }, width: 110),
      ],
    );
  }
  
  Widget _buildSelectButton(String text, bool isSelected, VoidCallback onTap, {double width = 150}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 45,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF3B30) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF3B30) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSwitchRow(String title) {
    bool switchValue;
    
    if (title == '노면 색깔 유도선 표시') {
      switchValue = _showTrafficInfo;
    } else if (title == '지도 위에 차로정보 표시') {
      switchValue = _showVehicleInfo;
    } else {
      switchValue = _showBuildingEntrance;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
          CupertinoSwitch(
            value: switchValue,
            onChanged: (value) {
              setState(() {
                if (title == '노면 색깔 유도선 표시') {
                  _showTrafficInfo = value;
                } else if (title == '지도 위에 차로정보 표시') {
                  _showVehicleInfo = value;
                } else {
                  _showBuildingEntrance = value;
                }
              });
            },
            activeColor: const Color(0xFFFF3B30),
          ),
        ],
      ),
    );
  }
}
