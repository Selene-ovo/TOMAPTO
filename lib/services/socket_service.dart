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

  // 기존 이벤트 스트림 컨트롤러
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
  final _friendStatusChangeController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 새로운 따라가기 관련 이벤트 스트림 컨트롤러
  final _followRequestReceivedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _followRequestRespondedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _followRequestCancelledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _followStoppedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 기존 이벤트 스트림 게터
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
  Stream<Map<String, dynamic>> get onFriendStatusChange =>
      _friendStatusChangeController.stream;

  // 새로운 따라가기 관련 이벤트 스트림 게터
  Stream<Map<String, dynamic>> get onFollowRequestReceived =>
      _followRequestReceivedController.stream;
  Stream<Map<String, dynamic>> get onFollowRequestResponded =>
      _followRequestRespondedController.stream;
  Stream<Map<String, dynamic>> get onFollowRequestCancelled =>
      _followRequestCancelledController.stream;
  Stream<Map<String, dynamic>> get onFollowStopped =>
      _followStoppedController.stream;

  // 소켓 객체 직접 접근 (이벤트 리스너 추가용)
  IO.Socket? get socket => _socket;

  // 소켓 서버 URL 가져오기
  String _getSocketUrl() {
    String socketUrl = dotenv.env['SOCKET_URL'] ?? '';

    if (socketUrl.isEmpty) {
      String baseUrl =
          dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080/api';
      socketUrl = baseUrl.replaceAll('/api', '');

      String? localIp = dotenv.env['LOCAL_IP'];

      if (Platform.isAndroid) {
        if (socketUrl.contains('localhost') &&
            localIp != null &&
            localIp.isNotEmpty) {
          socketUrl = socketUrl.replaceAll('localhost', localIp);
        }

        if (socketUrl.contains('localhost')) {
          socketUrl = socketUrl.replaceAll('localhost', '10.0.2.2');
        }
      }
    }

    print('소켓 URL: $socketUrl');
    return socketUrl;
  }

  // 소켓 연결 초기화
  Future<void> initSocket() async {
    if (_socket != null && _socket!.connected) {
      print('소켓이 이미 연결되어 있습니다.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print('로그인이 필요합니다.');
        return;
      }

      final socketUrl = _getSocketUrl();
      print('소켓 서버 연결 시도: $socketUrl');

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .setAuth({'token': token})
            .enableForceNew()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(3000)
            .setTimeout(30000)
            .build(),
      );

      _setupSocketListeners();
      _socket!.connect();

      print('소켓 연결 초기화 성공');
    } catch (e) {
      print('소켓 초기화 오류: $e');
    }
  }

  // 소켓 이벤트 리스너 설정
  void _setupSocketListeners() {
    _socket!.on('connect', (_) {
      print('소켓 연결 성공! ID: ${_socket!.id}');
    });

    _socket!.on('connect_error', (error) {
      print('소켓 연결 오류: $error');
    });

    _socket!.on('connect_timeout', (_) {
      print('소켓 연결 시간 초과');
    });

    _socket!.on('disconnect', (_) {
      print('소켓 연결 해제!');
    });

    _socket!.on('error', (error) {
      print('소켓 오류: $error');
    });

    // 기존 이벤트들
    _socket!.on('friend_request', (data) {
      print('친구 요청 수신: $data');
      _friendRequestController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('friend_accept', (data) {
      print('친구 수락 수신: $data');
      _friendAcceptController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('location_update', (data) {
      print('위치 업데이트 수신: $data');
      _locationUpdateController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('location_sharing_started', (data) {
      print('위치 공유 시작 수신: $data');
      _locationSharingStartedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('location_sharing_stopped', (data) {
      print('위치 공유 종료 수신: $data');
      _locationSharingStoppedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('friend_status_change', (data) {
      print('친구 상태 변경 수신: $data');
      _friendStatusChangeController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('connect_success', (data) {
      print('연결 성공 이벤트: $data');
    });

    // 새로운 따라가기 관련 이벤트들
    _socket!.on('follow_request_received', (data) {
      print('따라가기 요청 수신: $data');
      _followRequestReceivedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('follow_request_responded', (data) {
      print('따라가기 요청 응답 수신: $data');
      _followRequestRespondedController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('follow_request_cancelled', (data) {
      print('따라가기 요청 취소 수신: $data');
      _followRequestCancelledController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('follow_stopped', (data) {
      print('따라가기 중단 수신: $data');
      _followStoppedController.add(Map<String, dynamic>.from(data));
    });
  }

  // 친구 요청 전송
  void sendFriendRequest(String recipientId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('send_friend_request', {'recipient_id': recipientId});
    print('친구 요청 전송: $recipientId');
  }

  // 친구 요청 수락
  void acceptFriendRequest(dynamic requestId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    String stringRequestId = requestId?.toString() ?? '';
    if (stringRequestId.isEmpty) {
      print('유효하지 않은 요청 ID입니다.');
      return;
    }

    _socket!.emit('accept_friend_request', {'request_id': stringRequestId});
    print('친구 요청 수락: $stringRequestId');
  }

  // 친구 요청 거절
  void rejectFriendRequest(dynamic requestId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    String stringRequestId = requestId?.toString() ?? '';
    if (stringRequestId.isEmpty) {
      print('유효하지 않은 요청 ID입니다.');
      return;
    }

    _socket!.emit('reject_friend_request', {'request_id': stringRequestId});
    print('친구 요청 거절: $stringRequestId');
  }

  // 위치 공유 시작 - unidirectional 플래그 추가
  void startLocationSharing(String friendId, int? durationMinutes) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('start_location_sharing', {
      'friend_id': friendId,
      'duration_minutes': durationMinutes,
      'unidirectional': true, // 🔥 개별 제어는 단방향으로
      'direction': 'me_to_friend', // 내가 친구에게 공유
    });

    print('단방향 위치 공유 시작: $friendId, 기간: ${durationMinutes ?? "무제한"}');
  }

  // 위치 공유 종료 - unidirectional 플래그 추가
  void stopLocationSharing(String friendId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('stop_location_sharing', {
      'friend_id': friendId,
      'unidirectional': true, // 🔥 개별 제어는 단방향으로
    });

    print('단방향 위치 공유 종료: $friendId');
  }

  // 따라가기 요청 전송
  void sendFollowRequest(String friendId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('send_follow_request', {'friend_id': friendId});
    print('따라가기 요청 전송: $friendId');
  }

  // 따라가기 요청 응답
  void respondToFollowRequest(int requestId, String response) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('respond_follow_request', {
      'request_id': requestId,
      'response': response, // 'accept' or 'reject'
    });
    print('따라가기 요청 응답: $requestId, 응답: $response');
  }

  // 따라가기 요청 취소
  void cancelFollowRequest(String friendId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('cancel_follow_request', {'friend_id': friendId});
    print('따라가기 요청 취소: $friendId');
  }

  // 따라가기 중단
  void stopFollowing(String friendId) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다.');
      return;
    }

    _socket!.emit('stop_following', {'friend_id': friendId});
    print('따라가기 중단: $friendId');
  }

  // 위치 업데이트 전송
  void sendLocationUpdate(
    double latitude,
    double longitude,
    double? heading,
    double? accuracy,
  ) {
    if (_socket == null || !_socket!.connected) {
      print('소켓이 연결되어 있지 않습니다. 위치 업데이트를 보낼 수 없습니다.');
      initSocket();
      return;
    }

    Map<String, dynamic> data = {'latitude': latitude, 'longitude': longitude};

    if (heading != null) data['heading'] = heading;
    if (accuracy != null) data['accuracy'] = accuracy;

    print('위치 업데이트 전송: $data');
    _socket!.emit('update_location', data);
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
    // 기존 스트림 컨트롤러 해제
    _friendRequestController.close();
    _friendAcceptController.close();
    _locationUpdateController.close();
    _locationSharingStartedController.close();
    _locationSharingStoppedController.close();
    _friendStatusChangeController.close();

    // 새로운 따라가기 관련 스트림 컨트롤러 해제
    _followRequestReceivedController.close();
    _followRequestRespondedController.close();
    _followRequestCancelledController.close();
    _followStoppedController.close();
  }

  // 연결 상태 확인
  bool get isConnected => _socket?.connected ?? false;

  // 재연결 시도
  Future<void> reconnect() async {
    disconnect();
    await initSocket();
  }
}
