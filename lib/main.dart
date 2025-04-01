// lib/main.dart

import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'map/map_screen.dart';
import 'search/search_screen.dart';
import 'favorites/favorites_screen.dart';
import 'profile/profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '네비게이션 앱',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(), // 홈 화면으로 변경
    SearchScreen(),
    MapScreen(), // 가운데 버튼은 지도 화면
    FavoritesScreen(),
    ProfileScreen(),
  ];

  void _onTabTapped(int index) {
    // 가운데 버튼(인덱스 2)은 현재 위치로 이동하는 특별 기능
    if (index == 2) {
      // 여기서 현재 위치로 이동하는 로직을 구현
      print('현재 위치로 이동');
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
