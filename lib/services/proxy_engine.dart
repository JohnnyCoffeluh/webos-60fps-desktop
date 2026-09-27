import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';

@JS('initWebOSProxy')
external void _initWebOSProxy(JSString wispUrl, JSString bareUrl);

@JS('encodeUVUrl')
external JSString _encodeUVUrl(JSString url);

class ProxyEngine extends ChangeNotifier {
  static final ProxyEngine instance = ProxyEngine._internal();
  ProxyEngine._internal();

  String _wispUrl = EnvConfig.wispWsUrl;
  String _bareUrl = EnvConfig.bareUrl;
  String _httpBaseUrl = EnvConfig.httpBaseUrl;

  String get wispUrl => _wispUrl;
  String get bareUrl => _bareUrl;
  String get httpBaseUrl => _httpBaseUrl;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  int _latencyMs = 0;
  int get latencyMs => _latencyMs;

  void initialize() {
    _syncWithClient();
    checkHealth();
  }

  void updateEndpoint(String newProxyUrl) {
    if (newProxyUrl.trim().isEmpty) return;
    
    // Update dynamically
    var url = newProxyUrl.trim();
    if (url.startsWith('https://')) {
      _wispUrl = url.replaceFirst('https://', 'wss://');
    } else if (url.startsWith('http://')) {
      _wispUrl = url.replaceFirst('http://', 'ws://');
    } else if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      _wispUrl = 'wss://$url';
    }
    if (!_wispUrl.endsWith('/wisp') && !_wispUrl.endsWith('/wisp/')) {
      _wispUrl = '$_wispUrl/wisp';
    }

    _httpBaseUrl = _wispUrl.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://').replaceAll(RegExp(r'/wisp/?$'), '');
    _bareUrl = '$_httpBaseUrl/bare/';

    _syncWithClient();
    checkHealth();
    notifyListeners();
  }

  void _syncWithClient() {
    if (kIsWeb) {
      try {
        _initWebOSProxy(_wispUrl.toJS, _bareUrl.toJS);
      } catch (e) {
        debugPrint('[ProxyEngine] Notice syncing proxy config: $e');
      }
    }
  }

  /// Encodes destination target URL for Ultraviolet Service Worker routing
  String encodeTargetUrl(String url) {
    var target = url.trim();
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      if (target.contains('.') && !target.contains(' ')) {
        target = 'https://$target';
      } else {
        target = 'https://duckduckgo.com/html/?q=${Uri.encodeComponent(target)}';
      }
    }

    if (kIsWeb) {
      try {
        final jsEncoded = _encodeUVUrl(target.toJS);
        return jsEncoded.toDart;
      } catch (e) {
        debugPrint('[ProxyEngine] Notice on JS URL encode: $e');
      }
    }
    return '/uv/service/${Uri.encodeComponent(target)}';
  }

  /// Pings backend health endpoint
  Future<void> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('$_httpBaseUrl/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      sw.stop();
      _latencyMs = sw.elapsedMilliseconds;
      _isOnline = res.statusCode == 200;
    } catch (_) {
      sw.stop();
      _latencyMs = sw.elapsedMilliseconds;
      _isOnline = false;
    }
    notifyListeners();
  }
}
