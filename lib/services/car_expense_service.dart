// lib/services/car_expense_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class CarExpenseService {
  static String getApiBaseUrl() {
    String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
    String? localIp = dotenv.env['LOCAL_IP'];

    if (kDebugMode && Platform.isAndroid) {
      if (baseUrl.contains('localhost') &&
          localIp != null &&
          localIp.isNotEmpty) {
        return baseUrl.replaceAll('localhost', localIp);
      }

      if (baseUrl.contains('localhost')) {
        return baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }

    return baseUrl;
  }

  // 토큰 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 날짜 포맷팅 함수 (ISO 문자열을 YYYY-MM-DD로 변환)
  static String formatDateForDisplay(String isoDateString) {
    try {
      DateTime date = DateTime.parse(isoDateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      print('날짜 파싱 오류: $e');
      // T가 포함된 ISO 문자열인 경우 앞부분만 반환
      return isoDateString.split('T')[0];
    }
  }

  // 지출 추가
  static Future<Map<String, dynamic>> addExpense({
    required String expenseType,
    required double amount,
    required String description,
    required DateTime expenseDate,
  }) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      print('지출 추가 API 호출: $apiBaseUrl/car-expenses');

      final response = await http.post(
        Uri.parse('$apiBaseUrl/car-expenses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'expense_type': expenseType,
          'amount': amount,
          'description': description,
          'expense_date':
              '${expenseDate.year}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}',
        }),
      );

      print('지출 추가 API 응답 코드: ${response.statusCode}');
      print('지출 추가 API 응답 데이터: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode != 201) {
        throw Exception(responseData['message'] ?? '지출 추가에 실패했습니다.');
      }

      return responseData;
    } catch (e) {
      print('지출 추가 API 호출 오류: $e');
      rethrow;
    }
  }

  // 최근 지출 내역 조회
  static Future<List<Map<String, dynamic>>> getRecentExpenses({
    int limit = 10,
  }) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final response = await http.get(
        Uri.parse('$apiBaseUrl/car-expenses/recent?limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('최근 지출 조회 API 응답 코드: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? '지출 내역을 가져오는데 실패했습니다.');
      }

      return List<Map<String, dynamic>>.from(responseData['data']);
    } catch (e) {
      print('최근 지출 조회 API 호출 오류: $e');
      rethrow;
    }
  }

  // 특정 날짜의 지출 내역 조회 (새로 추가)
  static Future<List<Map<String, dynamic>>> getExpensesForDate(
    DateTime date,
  ) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final response = await http.get(
        Uri.parse('$apiBaseUrl/car-expenses/date/$dateString'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('특정 날짜 지출 조회 API 응답 코드: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          responseData['message'] ?? '해당 날짜의 지출 내역을 가져오는데 실패했습니다.',
        );
      }

      return List<Map<String, dynamic>>.from(responseData['data']);
    } catch (e) {
      print('특정 날짜 지출 조회 API 호출 오류: $e');
      rethrow;
    }
  }

  // 월간 통계 조회
  static Future<Map<String, dynamic>> getMonthlyStats({
    int? year,
    int? month,
  }) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final now = DateTime.now();
      final targetYear = year ?? now.year;
      final targetMonth = month ?? now.month;

      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/car-expenses/monthly?year=$targetYear&month=$targetMonth',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('월간 통계 조회 API 응답 코드: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? '월간 통계를 가져오는데 실패했습니다.');
      }

      return responseData['data'];
    } catch (e) {
      print('월간 통계 조회 API 호출 오류: $e');
      rethrow;
    }
  }

  // 일별 지출 조회 (캘린더용)
  static Future<Map<String, dynamic>> getDailyExpenses({
    int? year,
    int? month,
  }) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final now = DateTime.now();
      final targetYear = year ?? now.year;
      final targetMonth = month ?? now.month;

      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/car-expenses/daily?year=$targetYear&month=$targetMonth',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('일별 지출 조회 API 응답 코드: ${response.statusCode}');
      print('일별 지출 조회 API 응답 본문: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? '일별 지출을 가져오는데 실패했습니다.');
      }

      print('파싱된 일별 지출 데이터: ${responseData['data']}');
      return responseData['data'];
    } catch (e) {
      print('일별 지출 조회 API 호출 오류: $e');
      rethrow;
    }
  }

  // 카테고리별 통계 조회
  static Future<Map<String, dynamic>> getCategoryStats({
    int? year,
    int? month,
  }) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      final now = DateTime.now();
      final targetYear = year ?? now.year;
      final targetMonth = month ?? now.month;

      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/car-expenses/stats?year=$targetYear&month=$targetMonth',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('카테고리별 통계 조회 API 응답 코드: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? '카테고리별 통계를 가져오는데 실패했습니다.');
      }

      return responseData['data'];
    } catch (e) {
      print('카테고리별 통계 조회 API 호출 오류: $e');
      rethrow;
    }
  }

  // 지출 삭제
  static Future<Map<String, dynamic>> deleteExpense(int expenseId) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      print('지출 삭제 API 호출: $apiBaseUrl/car-expenses/$expenseId');

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/car-expenses/$expenseId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('지출 삭제 API 응답 코드: ${response.statusCode}');

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? '지출 삭제에 실패했습니다.');
      }

      return responseData;
    } catch (e) {
      print('지출 삭제 API 호출 오류: $e');
      rethrow;
    }
  }

  // 지출 수정
  static Future<Map<String, dynamic>> updateExpense({
    required int expenseId,
    required String expenseType,
    required double amount,
    required String description,
    required DateTime expenseDate,
  }) async {
    try {
      final apiBaseUrl = getApiBaseUrl();
      final token = await getToken();

      if (token == null) {
        throw Exception('인증 토큰이 없습니다.');
      }

      print('지출 수정 API 호출: $apiBaseUrl/car-expenses/$expenseId');

      final response = await http.put(
        Uri.parse('$apiBaseUrl/car-expenses/$expenseId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'expense_type': expenseType,
          'amount': amount,
          'description': description,
          'expense_date':
              '${expenseDate.year}-${expenseDate.month.toString().padLeft(2, '0')}-${expenseDate.day.toString().padLeft(2, '0')}',
        }),
      );

      print('지출 수정 API 응답 코드: ${response.statusCode}');
      print('지출 수정 API 응답 데이터: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? '지출 수정에 실패했습니다.');
      }

      return responseData;
    } catch (e) {
      print('지출 수정 API 호출 오류: $e');
      rethrow;
    }
  }

  // 금액 포맷팅 유틸리티 (개선된 버전)
  static String formatAmount(dynamic amount) {
    if (amount == null) return '0';

    double numAmount = 0.0;

    try {
      if (amount is String) {
        numAmount = double.tryParse(amount) ?? 0.0;
      } else if (amount is double) {
        numAmount = amount;
      } else if (amount is int) {
        numAmount = amount.toDouble();
      } else {
        // 다른 타입인 경우 문자열로 변환 후 파싱 시도
        numAmount = double.tryParse(amount.toString()) ?? 0.0;
      }
    } catch (e) {
      print('금액 파싱 오류: $e, 입력값: $amount (타입: ${amount.runtimeType})');
      return '0';
    }

    // 정수로 변환 (소수점 제거)
    int intAmount = numAmount.round();

    String numStr = intAmount.toString();
    String result = '';
    int count = 0;

    for (int i = numStr.length - 1; i >= 0; i--) {
      result = numStr[i] + result;
      count++;
      if (count % 3 == 0 && i > 0) {
        result = ',$result';
      }
    }

    return result;
  }

  // 지출 유형 한글 변환
  static String getExpenseTypeDisplayName(String type) {
    switch (type) {
      case 'fuel':
        return '주유비';
      case 'maintenance':
        return '정비비';
      case 'insurance':
        return '보험료';
      case 'other':
        return '기타';
      default:
        return '기타';
    }
  }
}
