class EnvConfig {
  /// Base proxy URL injected at compile time via --dart-define=PROXY_URL=...
  /// Default fallback: ws://localhost:3000/wisp
  static const String proxyUrl = String.fromEnvironment(
    'PROXY_URL',
    defaultValue: 'ws://localhost:3000/wisp',
  );

  /// Normalized WebSocket Wisp endpoint (wss:// or ws://)
  static String get wispWsUrl {
    var url = proxyUrl.trim();
    if (url.startsWith('https://')) {
      url = url.replaceFirst('https://', 'wss://');
    } else if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'ws://');
    } else if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'wss://$url';
    }
    if (!url.endsWith('/wisp') && !url.endsWith('/wisp/')) {
      url = '$url/wisp';
    }
    return url;
  }

  /// Normalized HTTP origin URL (https:// or http://)
  static String get httpBaseUrl {
    var url = proxyUrl.trim();
    if (url.startsWith('wss://')) {
      url = url.replaceFirst('wss://', 'https://');
    } else if (url.startsWith('ws://')) {
      url = url.replaceFirst('ws://', 'http://');
    } else if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    // Strip trailing /wisp and slashes
    url = url.replaceAll(RegExp(r'/wisp/?$'), '').replaceAll(RegExp(r'/+$'), '');
    return url;
  }

  /// Bare HTTP proxy endpoint
  static String get bareUrl => '$httpBaseUrl/bare/';
}
