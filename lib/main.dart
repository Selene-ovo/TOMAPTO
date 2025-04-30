import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tomapto/pages/map/naver_map.dart';

// 네이버 맵 초기화 메서드 선언
Future<void> init({
  String? clientId,
  Function(NAuthFailedException ex)? onAuthFailed,
}) async {
  // FlutterNaverMap 인스턴스를 생성하고 init 메서드 호출
  await FlutterNaverMap().init(clientId: clientId, onAuthFailed: onAuthFailed);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  await dotenv.load(fileName: ".env");

  try {
    // 네이버 맵 초기화 - 새로 선언한 init 메서드 사용
    await init(
      clientId: dotenv.env['NAVER_API_KEY'] ?? '',
      onAuthFailed: (NAuthFailedException ex) {
        print('네이버 맵 인증 실패: ${ex.message}');
      },
    );
    print('네이버 맵 초기화 성공');
  } catch (e) {
    print('네이버 맵 초기화 중 오류 발생: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      home: const NaverMapPage(),
    );
  }
}
