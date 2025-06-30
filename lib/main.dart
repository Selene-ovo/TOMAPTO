import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:provider/provider.dart';
import 'package:tomapto/controllers/map/transit_provider.dart';
import 'package:tomapto/pages/intro.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");

    await FlutterNaverMap().init(
      clientId: dotenv.env['NAVER_API_KEY'] ?? '',
      onAuthFailed: (NAuthFailedException ex) {
        print('네이버 맵 인증 실패: ${ex.message}');
      },
    );
    print('네이버 맵 초기화 성공');
  } catch (e) {
    print('앱 초기화 중 오류: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TransitProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.light(
            surface: Colors.white,
            secondary: Color(0xFF2196F3),
          ),
          splashColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          progressIndicatorTheme: ProgressIndicatorThemeData(
            color: Color(0xFFFB233B),
            circularTrackColor: Colors.grey.withOpacity(0.2),
          ),
          bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: Colors.white,
            modalBackgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Color(0xFF4C9EFC),
            selectionColor: Color(0xFF4C9EFC).withOpacity(0.2),
            selectionHandleColor: Color(0xFF4C9EFC),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return Color(0xFF388E3C);
                }
                return Color(0xFF4CAF50);
              }),
              foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
              overlayColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return Colors.green.withOpacity(0.1);
                }
                return Colors.transparent;
              }),
              splashFactory: NoSplash.splashFactory,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return Color(0xFF363636);
                }
                return Color(0xFF363636);
              }),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return Color(0xFF363636).withOpacity(0.3);
                }
                return Colors.transparent;
              }),
            ),
          ),
        ),
        home: IntroPage(),
      ),
    );
  }
}
