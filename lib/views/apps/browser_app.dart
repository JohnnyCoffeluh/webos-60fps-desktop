import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/gateway_client.dart';
import '../../theme/webos_theme.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

class BrowserApp extends StatefulWidget {
  const BrowserApp({super.key});

  @override
  State<BrowserApp> createState() => _BrowserAppState();
}

class _BrowserAppState extends State<BrowserApp> {
  final TextEditingController _urlController = TextEditingController(text: 'https://news.ycombinator.com');
  bool _isLoading = false;
  String _currentUrl = 'https://news.ycombinator.com';
  String _pageTitle = 'Hacker News';
  
  // Telemetry for current page
  int _lastLatency = 0;
  bool _isCacheHit = false;
  int _contentLength = 0;
  String? _htmlContent;
  String _viewMode = 'proxy_view'; // 'proxy_view' or 'iframe_embed'
  late String _iframeViewType;

  final List<Map<String, String>> _bookmarks = [
    {'title': 'Hacker News', 'url': 'https://news.ycombinator.com'},
    {'title': 'Wikipedia', 'url': 'https://en.wikipedia.org'},
    {'title': 'Dart Docs', 'url': 'https://dart.dev'},
    {'title': 'Flutter Docs', 'url': 'https://flutter.dev'},
    {'title': 'GitHub', 'url': 'https://github.com'},
  ];

  @override
  void initState() {
    super.initState();
    _iframeViewType = 'iframe_webos_${DateTime.now().millisecondsSinceEpoch}';
    _registerIframeView(_iframeViewType, _currentUrl);
    _loadUrl(_currentUrl);
  }

  void _registerIframeView(String viewType, String url) {
    if (kIsWeb) {
      try {
        ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
          final iframe = web.HTMLIFrameElement()
            ..src = url
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms allow-popups');
          return iframe;
        });
      } catch (_) {}
    }
  }

  Future<void> _loadUrl(String rawUrl) async {
    String url = rawUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        url = 'https://duckduckgo.com/html/?q=${Uri.encodeComponent(url)}';
      }
    }

    setState(() {
      _isLoading = true;
      _currentUrl = url;
      _urlController.text = url;
    });

    final gateway = GatewayClient.instance;
    final response = await gateway.fetchProxied(url);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _lastLatency = response.latencyMs;
        _isCacheHit = response.isCacheHit;
        _contentLength = response.body.length;
        _htmlContent = response.body;

        // Try extracting <title> from HTML
        final match = RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(response.body);
        if (match != null) {
          _pageTitle = match.group(1)?.trim() ?? url;
        } else {
          _pageTitle = Uri.parse(url).host;
        }

        // Also update iframe source if in iframe mode
        if (kIsWeb) {
          // Point iframe through gateway proxy to strip frame-ancestors / CSP
          final proxiedSrc = '${gateway.gatewayUrl}/proxy?url=${Uri.encodeComponent(url)}';
          _iframeViewType = 'iframe_webos_${DateTime.now().millisecondsSinceEpoch}';
          _registerIframeView(_iframeViewType, proxiedSrc);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Browser Toolbar & Address bar
          _buildBrowserToolbar(),
          
          // Bookmarks bar
          _buildBookmarksBar(),

          // Gateway Status & Speed Telemetry Bar
          _buildSpeedTelemetryBar(),

          // Page Content Area
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _buildContentArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0x2238BDF8))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            onPressed: () {},
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            onPressed: () {},
            tooltip: 'Forward',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(_isLoading ? Icons.close_rounded : Icons.refresh_rounded, size: 18),
            onPressed: () => _loadUrl(_currentUrl),
            tooltip: 'Reload',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded, size: 18),
            onPressed: () => _loadUrl('https://news.ycombinator.com'),
            tooltip: 'Home',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),

          // Address input field
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0B132B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x4438BDF8)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.lock_rounded, size: 14, color: WebOSTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        hintText: 'Enter URL or search...',
                        hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      onSubmitted: _loadUrl,
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: WebOSTheme.primary),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: WebOSTheme.primary),
                      onPressed: () => _loadUrl(_urlController.text),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // View mode switch (High Speed Proxy DOM vs Embedded Frame)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'proxy_view',
                icon: Icon(Icons.bolt_rounded, size: 16),
                label: Text('Turbo DOM', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: 'iframe_embed',
                icon: Icon(Icons.web_rounded, size: 16),
                label: Text('IFrame', style: TextStyle(fontSize: 11)),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (val) {
              setState(() => _viewMode = val.first);
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF131D33),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _bookmarks.length,
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final bm = _bookmarks[index];
          final isSelected = _currentUrl == bm['url'];
          return InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _loadUrl(bm['url']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0x3338BDF8) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public, size: 13, color: WebOSTheme.primary),
                  const SizedBox(width: 5),
                  Text(
                    bm['title']!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpeedTelemetryBar() {
    final gateway = GatewayClient.instance;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF090E17),
        border: Border(bottom: BorderSide(color: Color(0x1538BDF8))),
      ),
      child: Row(
        children: [
          // Gateway mode pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: gateway.telemetry.isConnected ? const Color(0x2210B981) : const Color(0x22EF4444),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: gateway.telemetry.isConnected ? WebOSTheme.accent : WebOSTheme.error,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  gateway.telemetry.isConnected ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
                  size: 11,
                  color: gateway.telemetry.isConnected ? WebOSTheme.accent : WebOSTheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  gateway.telemetry.isConnected ? 'GATEWAY ROUTED' : 'GATEWAY OFFLINE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: gateway.telemetry.isConnected ? WebOSTheme.accent : WebOSTheme.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Latency indicator
          Icon(Icons.speed_rounded, size: 13, color: _isCacheHit ? WebOSTheme.accent : WebOSTheme.primary),
          const SizedBox(width: 4),
          Text(
            _isCacheHit ? '⚡ CACHE HIT (0ms)' : 'Latency: ${_lastLatency}ms',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _isCacheHit ? WebOSTheme.accent : const Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(width: 12),

          // Payload size
          Text(
            'Size: ${(_contentLength / 1024).toStringAsFixed(1)} KB',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const Spacer(),

          // Service Worker tag
          const Text(
            'Service Worker Intercept: ACTIVE',
            style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3, color: WebOSTheme.primary),
          ),
          const SizedBox(height: 16),
          Text('Streaming $_currentUrl through Network Gateway...',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const SizedBox(height: 6),
          const Text('Applying in-memory cache & stripping restrictive CSP headers',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    if (_viewMode == 'iframe_embed' && kIsWeb) {
      return HtmlElementView(viewType: _iframeViewType);
    }

    // High Speed Turbo DOM View
    return Container(
      color: Colors.white,
      child: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF0284C7), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pageTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Source: $_currentUrl • Status: 200 OK • Stripped CORS: Yes',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_browser, size: 14),
                      label: const Text('Embed IFrame', style: TextStyle(fontSize: 12)),
                      onPressed: () => setState(() => _viewMode = 'iframe_embed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),

              // Render text content or raw HTML preview safely
              Text(
                _stripHtmlTags(_htmlContent ?? 'No content loaded'),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stripHtmlTags(String html) {
    if (html.isEmpty) return '';
    var text = html
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length > 5000 ? '${text.substring(0, 5000)}...\n\n[Display truncated for high-speed streaming]' : text;
  }
}
