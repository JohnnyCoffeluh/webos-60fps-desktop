import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env_config.dart';
import 'auth_service.dart';

import 'package:web/web.dart' as web;

enum RbiConnectionState {
  disconnected,
  authenticating,
  connectingSignaling,
  negotiatingWebRTC,
  streaming,
  error
}

class RbiClient extends ChangeNotifier {
  static final RbiClient instance = RbiClient._internal();
  RbiClient._internal();

  String _determineWsUrl() {
    if (kIsWeb) {
      try {
        final host = web.window.location.host;
        final isLocal = host.contains('localhost') || host.contains('127.0.0.1');
        if (!isLocal) {
          final proto = web.window.location.protocol == 'https:' ? 'wss:' : 'ws:';
          return '$proto//$host/rbi/';
        }
      } catch (_) {}
    }
    final wisp = EnvConfig.wispWsUrl;
    return wisp.replaceAll('/wisp/', '/rbi/').replaceAll('/wisp', '/rbi/');
  }

  String _gatewayWsUrl = '';
  String get gatewayWsUrl => _gatewayWsUrl.isNotEmpty ? _gatewayWsUrl : _determineWsUrl();

  RbiConnectionState _state = RbiConnectionState.disconnected;
  RbiConnectionState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _currentUrl = 'https://news.ycombinator.com';
  String get currentUrl => _currentUrl;

  // Remote viewport dimensions
  double _remoteWidth = 1280;
  double _remoteHeight = 720;
  double get remoteWidth => _remoteWidth;
  double get remoteHeight => _remoteHeight;

  // WebRTC & Streaming
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final RTCVideoRenderer videoRenderer = RTCVideoRenderer();

  // Low latency frame stream (JPEG bytes)
  Uint8List? _latestFrameBytes;
  Uint8List? get latestFrameBytes => _latestFrameBytes;

  int _fpsCount = 0;
  int _fps = 0;
  int get fps => _fps;
  Timer? _fpsTimer;

  final int _latencyMs = 0;
  int get latencyMs => _latencyMs;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  Future<void> initializeRenderer() async {
    await videoRenderer.initialize();
  }

  void connect({String? customWsUrl}) async {
    if (customWsUrl != null) _gatewayWsUrl = customWsUrl;

    _setState(RbiConnectionState.authenticating);
    _fpsTimer?.cancel();
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fps = _fpsCount;
      _fpsCount = 0;
      notifyListeners();
    });

    try {
      final token = AuthService.instance.idToken;
      if (token == null) {
        await AuthService.instance.initializeAuth();
      }

      final activeToken = AuthService.instance.idToken ?? 'guest-anon';
      _setState(RbiConnectionState.connectingSignaling);

      // Connect cross-platform WebSocket
      _channel?.sink.close();
      _channelSubscription?.cancel();
      _channel = WebSocketChannel.connect(Uri.parse(_gatewayWsUrl));

      _channelSubscription = _channel!.stream.listen(
        _onSignalingMessage,
        onError: (err) {
          _errorMessage = 'Signaling error: $err';
          _setState(RbiConnectionState.error);
        },
        onDone: () {
          _setState(RbiConnectionState.disconnected);
        },
      );

      // Authenticate RBI Session with Firebase token
      _sendSignaling({
        'type': 'auth_session',
        'token': activeToken,
      });

    } catch (e) {
      _errorMessage = 'Failed to connect to RBI gateway: $e';
      _setState(RbiConnectionState.error);
    }
  }

  void _sendSignaling(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  Future<void> _onSignalingMessage(dynamic message) async {
    try {
      final msg = jsonDecode(message as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'session_ready':
          _setState(RbiConnectionState.negotiatingWebRTC);
          if (msg['viewport'] != null) {
            final vp = msg['viewport'] as Map<String, dynamic>;
            _remoteWidth = (vp['width'] as num?)?.toDouble() ?? 1280;
            _remoteHeight = (vp['height'] as num?)?.toDouble() ?? 720;
          }
          await _setupWebRTC();
          break;

        case 'frame':
          // High-speed low-latency frame arrived
          final base64Data = msg['data'] as String?;
          if (base64Data != null) {
            _latestFrameBytes = base64Decode(base64Data);
            _fpsCount++;
            if (_state != RbiConnectionState.streaming) {
              _setState(RbiConnectionState.streaming);
            } else {
              notifyListeners();
            }
          }
          break;

        case 'answer':
          if (_peerConnection != null) {
            final sdp = msg['sdp'] as Map<String, dynamic>;
            await _peerConnection!.setRemoteDescription(
              RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
            );
          }
          break;

        case 'candidate':
          if (_peerConnection != null && msg['candidate'] != null) {
            final c = msg['candidate'] as Map<String, dynamic>;
            await _peerConnection!.addCandidate(
              RTCIceCandidate(c['candidate'] as String, c['sdpMid'] as String, c['sdpMLineIndex'] as int),
            );
          }
          break;

        case 'error':
          _errorMessage = msg['message'] as String? ?? 'RBI error';
          _setState(RbiConnectionState.error);
          break;
      }
    } catch (e) {
      debugPrint('[RbiClient] Signaling parse error: $e');
    }
  }

  Future<void> _setupWebRTC() async {
    try {
      final configuration = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ]
      };

      _peerConnection = await createPeerConnection(configuration);

      // Setup DataChannel for input events
      final dataChannelDict = RTCDataChannelInit()..ordered = true;
      _dataChannel = await _peerConnection!.createDataChannel('rbi-input', dataChannelDict);

      _dataChannel?.onDataChannelState = (state) {
        debugPrint('[RbiClient] DataChannel state: $state');
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          _setState(RbiConnectionState.streaming);
        }
      };

      _peerConnection!.onIceCandidate = (candidate) {
        _sendSignaling({
          'type': 'candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      };

      _peerConnection!.onTrack = (event) {
        if (event.track.kind == 'video') {
          videoRenderer.srcObject = event.streams[0];
          _setState(RbiConnectionState.streaming);
        }
      };

      // Create SDP offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _sendSignaling({
        'type': 'offer',
        'sdp': {
          'sdp': offer.sdp,
          'type': offer.type,
        }
      });
    } catch (e) {
      debugPrint('[RbiClient] WebRTC negotiation notice (falling back to low-latency stream): $e');
    }
  }

  /// Sends pointer and keyboard inputs to the remote Puppeteer browser
  void sendInput(Map<String, dynamic> event) {
    final payload = jsonEncode(event);

    // Prefer WebRTC DataChannel for minimum latency
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(payload));
    } else {
      // Fallback via WebSocket
      _sendSignaling({
        'type': 'input',
        'event': event,
      });
    }
  }

  void navigate(String url) {
    _currentUrl = url;
    sendInput({'type': 'goto', 'url': url});
    notifyListeners();
  }

  void sendMouseMove(double x, double y) {
    sendInput({'type': 'mousemove', 'x': x, 'y': y});
  }

  void sendMouseDown(double x, double y, {String button = 'left'}) {
    sendInput({'type': 'mousedown', 'x': x, 'y': y, 'button': button});
  }

  void sendMouseUp(double x, double y, {String button = 'left'}) {
    sendInput({'type': 'mouseup', 'x': x, 'y': y, 'button': button});
  }

  void sendClick(double x, double y, {String button = 'left'}) {
    sendInput({'type': 'click', 'x': x, 'y': y, 'button': button});
  }

  void sendWheel(double dx, double dy) {
    sendInput({'type': 'wheel', 'deltaX': dx, 'deltaY': dy});
  }

  void sendKeyDown(String key) {
    sendInput({'type': 'keydown', 'key': key});
  }

  void sendKeyUp(String key) {
    sendInput({'type': 'keyup', 'key': key});
  }

  void _setState(RbiConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  void disconnect() {
    _fpsTimer?.cancel();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _dataChannel?.close();
    _peerConnection?.close();
    _setState(RbiConnectionState.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    videoRenderer.dispose();
    super.dispose();
  }
}
