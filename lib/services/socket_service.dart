import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class SocketService {
  // 싱글톤 인스턴스
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  // 소켓 객체
  IO.Socket? _socket;

  // 이벤트 스트림 컨트롤러
  final _friendRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _friendAcceptController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _locationUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _locationSharingStartedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _locationSharingStoppedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 이벤트 스트림 게터
  Stream<Map<String, dynamic>> get onFriendRequest =>
      _friendRequestController.stream;
  Stream<Map<String, dynamic>> get onFriendAccept =>
      _friendAcceptController.stream;
  Stream<Map<String, dynamic>> get onLocationUpdate =>
      _locationUpdateController.stream;
  Stream<Map<String, dynamic>> get onLocationSharingStarted =>
      _locationSharingStartedController.stream;
  Stream<Map<String, dynamic>> get onLocationSharingStopped =>
      _locationSharingStoppedController.stream;

  // 소켓 서버 URL 가져오기
  String _getSocketUrl() {
    String baseUrl = dotenv.env['SOCKET_URL'] ?? 'http://localhost:8080';
    String? localIp = dotenv.env['LOCAL_IP'];

    // 안드로이드 에뮬레이터에서 실행 중인 경우
    if (Platform.isAndroid) {
      // localhost를 사용 중이고 LOCAL_IP가 설정되어 있다면
      if (baseUrl.contains('localhost') &&
          localIp != null &&
          localIp.isNotEmpty) {
        // localhost를 LOCAL_IP로 대체
        return baseUrl.replaceAll('localhost', localIp);
      }

      // 에뮬레이터 특정 주소 처리
      if (baseUrl.contains('localhost')) {
        return baseUrl.replaceAll('localhost', '10.0.2.2');
      }
    }

    // 다른 플랫폼이거나 이미 localhost가 아닌 경우 원래 URL 반환
    return baseUrl;
  }

  // 소켓 연결 초기화
  Future<void> initSocket() async {
    if (_socket != null) {
      print('소켓이 이미 초기화되어 있습니다.');
      return;
    }

    try {
      // 토큰 가져오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다.');
        return;
      }

      final socketUrl = _getSocketUrl();
      print('소켓 서버 연결 시도: $socketUrl');

      // 소켓 객체 생성 및 설정
      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      // 소켓 이벤트 리스너 설정
      _setupSocketListeners();

      // 소켓 연결
      _socket!.connect();
    } catch (e) {
      print('소켓 초기화 오류: $e');
    }
  }

  // 소켓 이벤트 리스너 설정
  void _setupSocketListeners() {
    _socket!.on('connect', (_) {
      print('소켓 연결 성공! ID: ${_socket!.id}');
    });

    _socket!.on('disconnect', (_) {
      print('소켓 연결 해제!');
    });

    _socket!.on('error', (error) {
      print('소켓 오류: $error');
    });

    // 친구 요청 이벤트
    _socket!.on('friend_request', (data) {
      print('친구 요청 수신: $data');
      _friendRequestController.add(Map<String, dynamic>.from(data));
    });

    // 친구 수락 이벤트
    _socket!.on('friend_accept', (data) {
      print('친구 수락 수신: $data');
      _friendAcceptController.add(Map<String, dynamic>.from(data));
    });

    // 위치 업데이트 이벤트
    _socket!.on('location_update', (data) {
      print('위치 업데이트 수신: $data');
      _locationUpdateController.add(Map<String, dynamic>.from(data));
    });

    // 위치 공유 시작 이벤트
    _socket!.on('location_sharing_started', (data) {
      print('위치 공유 시작 수신: $data');
      _locationSharingStartedController.add(Map<String, dynamic>.from(data));
    });

    // 위치 공유 종료 이벤트
    _socket!.on('location_sharing_stopped', (data) {
      print('위치 공유 종료 수신: $data');
      _locationSharingStoppedController.add(Map<String, dynamic>.from(data));
    });
  }

  // 친구 요청 전송
  void sendFriendRequest(String recipientId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('send_friend_request', {'recipient_id': recipientId});
  }

  // 친구 요청 수락
  void acceptFriendRequest(String requestId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('accept_friend_request', {'request_id': requestId});
  }

  // 친구 요청 거절
  void rejectFriendRequest(String requestId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('reject_friend_request', {'request_id': requestId});
  }

  // 위치 공유 시작 (durationMinutes가 null이면 무제한 공유)
  void startLocationSharing(String friendId, int? durationMinutes) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    // 소켓으로 위치 공유 시작 이벤트 전송
    _socket!.emit('start_location_sharing', {
      'friend_id': friendId,
      'duration_minutes': durationMinutes, // null일 경우 무제한
    });
  }

  // 위치 공유 종료
  void stopLocationSharing(String friendId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    // 소켓으로 위치 공유 종료 이벤트 전송
    _socket!.emit('stop_location_sharing', {'friend_id': friendId});
  }

  // 위치 업데이트 전송
  void sendLocationUpdate(
    double latitude,
    double longitude,
    double? heading,
    double? accuracy,
  ) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('update_location', {
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'accuracy': accuracy,
    });
  }

  // 소켓 연결 해제
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      print('소켓 연결 해제 완료');
    }
  }

  // 자원 해제
  void dispose() {
    disconnect();
    _friendRequestController.close();
    _friendAcceptController.close();
    _locationUpdateController.close();
    _locationSharingStartedController.close();
    _locationSharingStoppedController.close();
  }

  // 연결 상태 확인
  bool get isConnected => _socket?.connected ?? false;
}
