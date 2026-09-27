import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import 'auth_service.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';

@JS('configureWebOSGateway')
external void _configureWebOSGateway(JSString gatewayUrl, JSString authToken);

class GatewayTelemetry {
  final int latencyMs;
  final bool isConnected;
  final int totalRequests;
  final int cacheHits;
  final String serverUptime;
  final String clientTier;
  final DateTime lastPingTime;

  GatewayTelemetry({
    required this.latencyMs,
    required this.isConnected,
    required this.totalRequests,
    required this.cacheHits,
    required this.serverUptime,
    required this.clientTier,
    required this.lastPingTime,
  });

  factory GatewayTelemetry.initial() => GatewayTelemetry(
    latencyMs: 0,
    isConnected: false,
    totalRequests: 0,
    cacheHits: 0,
    serverUptime: '0s',
    clientTier: 'connecting...',
    lastPingTime: DateTime.now(),
  );
}

class ProxiedResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final int latencyMs;
  final bool isCacheHit;
  final String targetUrl;

  ProxiedResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.latencyMs,
    required this.isCacheHit,
    required this.targetUrl,
  });
}

class GatewayClient extends ChangeNotifier {
  static final GatewayClient instance = GatewayClient._internal();
  GatewayClient._internal();

  String _gatewayUrl = EnvConfig.httpBaseUrl;
  String get gatewayUrl => _gatewayUrl;

  GatewayTelemetry _telemetry = GatewayTelemetry.initial();
  GatewayTelemetry get telemetry => _telemetry;

  Timer? _pingTimer;
  int _clientRequestCount = 0;
  int get clientRequestCount => _clientRequestCount;

  void initialize() {
    pingGateway();
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 4), (_) => pingGateway());
    _syncServiceWorker();
  }

  void setGatewayUrl(String newUrl) {
    _gatewayUrl = newUrl.trim().replaceAll(RegExp(r'/+$'), '');
    pingGateway();
    _syncServiceWorker();
    notifyListeners();
  }

  void _syncServiceWorker() {
    if (kIsWeb) {
      try {
        final token = AuthService.instance.idToken ?? '';
        _configureWebOSGateway(_gatewayUrl.toJS, token.toJS);
      } catch (e) {
        debugPrint('[GatewayClient] Service Worker sync notice: $e');
      }
    }
  }

  /// Pings the gateway to measure network roundtrip latency
  Future<void> pingGateway() async {
    final stopwatch = Stopwatch()..start();
    try {
      final token = AuthService.instance.idToken;
      final uri = Uri.parse('$_gatewayUrl/api/ping');
      final headers = <String, String>{
        'Cache-Control': 'no-cache',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
        headers['x-firebase-auth-token'] = token;
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 3));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _telemetry = GatewayTelemetry(
          latencyMs: stopwatch.elapsedMilliseconds,
          isConnected: true,
          totalRequests: _telemetry.totalRequests,
          cacheHits: _telemetry.cacheHits,
          serverUptime: _telemetry.serverUptime,
          clientTier: (data['tier'] as String?) ?? 'authenticated-workspace',
          lastPingTime: DateTime.now(),
        );
        fetchBackendStats();
      } else {
        _telemetry = GatewayTelemetry(
          latencyMs: stopwatch.elapsedMilliseconds,
          isConnected: false,
          totalRequests: _telemetry.totalRequests,
          cacheHits: _telemetry.cacheHits,
          serverUptime: _telemetry.serverUptime,
          clientTier: 'gateway-error',
          lastPingTime: DateTime.now(),
        );
      }
    } catch (e) {
      stopwatch.stop();
      _telemetry = GatewayTelemetry(
        latencyMs: 999,
        isConnected: false,
        totalRequests: _telemetry.totalRequests,
        cacheHits: _telemetry.cacheHits,
        serverUptime: 'offline',
        clientTier: 'offline',
        lastPingTime: DateTime.now(),
      );
    }
    notifyListeners();
  }

  /// Fetch telemetry statistics from backend
  Future<void> fetchBackendStats() async {
    try {
      final uri = Uri.parse('$_gatewayUrl/api/status');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final telem = data['telemetry'] as Map<String, dynamic>? ?? {};
        _telemetry = GatewayTelemetry(
          latencyMs: _telemetry.latencyMs,
          isConnected: true,
          totalRequests: (telem['totalRequests'] as num?)?.toInt() ?? _telemetry.totalRequests,
          cacheHits: (telem['cacheHits'] as num?)?.toInt() ?? _telemetry.cacheHits,
          serverUptime: '${data['uptimeSeconds'] ?? 0}s',
          clientTier: (data['clientTier'] as String?) ?? 'authenticated-workspace',
          lastPingTime: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Fetch a web page or resource through the authenticated gateway proxy
  Future<ProxiedResponse> fetchProxied(String targetUrl) async {
    _clientRequestCount++;
    final stopwatch = Stopwatch()..start();
    final token = AuthService.instance.idToken;

    final queryParams = <String, String>{
      'url': targetUrl,
    };
    if (token != null) {
      queryParams['auth_token'] = token;
    }

    final proxyUri = Uri.parse('$_gatewayUrl/proxy').replace(queryParameters: queryParams);

    final reqHeaders = <String, String>{
      'X-WebOS-Virtual-Net': 'true',
    };
    if (token != null) {
      reqHeaders['Authorization'] = 'Bearer $token';
      reqHeaders['x-firebase-auth-token'] = token;
    }

    try {
      final response = await http.get(
        proxyUri,
        headers: reqHeaders,
      ).timeout(const Duration(seconds: 12));

      stopwatch.stop();
      final isCacheHit = response.headers['x-gateway-cache'] == 'HIT';

      return ProxiedResponse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
        latencyMs: stopwatch.elapsedMilliseconds,
        isCacheHit: isCacheHit,
        targetUrl: targetUrl,
      );
    } catch (e) {
      stopwatch.stop();
      return ProxiedResponse(
        statusCode: 504,
        body: '<html><body><h3>Virtual Gateway Error</h3><p>$e</p></body></html>',
        headers: {},
        latencyMs: stopwatch.elapsedMilliseconds,
        isCacheHit: false,
        targetUrl: targetUrl,
      );
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    super.dispose();
  }
}
