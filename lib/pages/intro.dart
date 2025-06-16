import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tomapto/services/friends_real_time_service.dart';
import 'package:tomapto/services/socket_service.dart';
import 'package:tomapto/services/token_service.dart';
import 'package:tomapto/pages/map/naver_map.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. 위치 권한 확인 및 요청
      await _checkLocationPermissions();

      // 2. 로그인 상태 확인 및 서비스 초기화
      await _initLocationServiceIfLoggedIn();

      // 3. 모든 초기화 완료 후 메인 페이지로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    const NaverMapPage(),
            transitionDuration: Duration.zero, // 애니메이션 없음
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    } catch (e) {
      print('앱 초기화 중 오류: $e');
      // 일반적인 오류는 그냥 메인 페이지로 이동
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    const NaverMapPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    }
  }

  Future<void> _checkLocationPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        print('위치 권한이 영구적으로 거부되었습니다. 앱을 종료합니다.');
        exit(0);
      }

      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('위치 서비스가 비활성화되어 있습니다.');
        // 위치 서비스 비활성화는 앱 종료하지 않고 계속 진행
      }
    } on TimeoutException {
      print('위치 권한 요청 시간 초과. 앱을 종료합니다.');
      exit(0);
    } catch (e) {
      if (e is SocketException) {
        print('네트워크 오류로 인한 위치 권한 확인 실패. 앱을 종료합니다.');
        exit(0);
      }
      print('위치 권한 확인 오류: $e');
      // 기타 오류는 앱 계속 진행
    }
  }

  Future<void> _initLocationServiceIfLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final rememberMe = prefs.getBool('remember_me') ?? false;
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      // 로그인 상태인 경우에만 위치 추적 서비스 시작 (DB 저장용)
      if (token != null && (rememberMe || isLoggedIn)) {
        // 토큰 유효성 검사
        if (TokenService.isTokenExpired(token)) {
          print('토큰이 만료되었습니다.');
          // 토큰 만료는 앱 종료하지 않고 계속 진행
          return;
        }

        try {
          final locationService = RealTimeLocationService();
          if (!locationService.isRunning) {
            print('앱 시작 시 위치 서비스 초기화 중...');
            await locationService.startLocationUpdates();
            print('위치 추적 서비스 시작됨 (DB 저장용) - 공유는 활성화되지 않음');
          }
        } catch (e) {
          if (e is SocketException || e is TimeoutException) {
            print('네트워크 오류로 인한 위치 서비스 초기화 실패. 앱을 종료합니다.');
            exit(0);
          }
          print('위치 서비스 초기화 오류: $e');
          // 기타 위치 서비스 오류는 계속 진행
        }

        try {
          // 소켓 서비스 초기화
          final socketService = SocketService();
          await socketService.initSocket();
          print('소켓 서비스 초기화 완료');
        } catch (e) {
          if (e is SocketException || e is TimeoutException) {
            print('네트워크 오류로 인한 소켓 초기화 실패. 앱을 종료합니다.');
            exit(0);
          }
          print('소켓 초기화 오류: $e');
          // 기타 소켓 오류는 계속 진행
        }
      }
    } on TimeoutException {
      print('서비스 초기화 시간 초과. 앱을 종료합니다.');
      exit(0);
    } catch (e) {
      if (e is SocketException) {
        print('네트워크 오류로 인한 서비스 초기화 실패. 앱을 종료합니다.');
        exit(0);
      }
      print('서비스 초기화 오류: $e');
      // 기타 오류는 계속 진행
    }
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기의 30% 사용 (다양한 기기 대응)
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth * 0.30; // 화면 너비의 30%

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: logoSize,
          height: logoSize,
          child: Image.asset(
            'assets/icons/intro_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
