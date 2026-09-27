import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../services/proxy_engine.dart';
import '../../services/auth_service.dart';
import '../../theme/webos_theme.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

class RbiBrowserApp extends StatefulWidget {
  const RbiBrowserApp({super.key});

  @override
  State<RbiBrowserApp> createState() => _RbiBrowserAppState();
}

class _RbiBrowserAppState extends State<RbiBrowserApp> {
  final TextEditingController _urlController = TextEditingController(text: 'https://news.ycombinator.com');
  String _currentDestination = 'https://news.ycombinator.com';
  late String _iframeViewType;

  final List<Map<String, dynamic>> _gamePresets = [
    {'title': 'Hacker News', 'url': 'https://news.ycombinator.com', 'icon': Icons.newspaper_rounded},
    {'title': 'Poki Games', 'url': 'https://poki.com', 'icon': Icons.sports_esports_rounded},
    {'title': 'CrazyGames', 'url': 'https://www.crazygames.com', 'icon': Icons.videogame_asset_rounded},
    {'title': 'Slope', 'url': 'https://slopegame.online', 'icon': Icons.sports_volleyball_rounded},
    {'title': 'Wikipedia', 'url': 'https://en.wikipedia.org', 'icon': Icons.public_rounded},
    {'title': 'DuckDuckGo', 'url': 'https://duckduckgo.com', 'icon': Icons.search_rounded},
  ];

  @override
  void initState() {
    super.initState();
    ProxyEngine.instance.initialize();
    _iframeViewType = 'uv_iframe_${DateTime.now().millisecondsSinceEpoch}';
    _registerIframe();
  }

  void _registerIframe() {
    if (kIsWeb) {
      try {
        final encodedSrc = ProxyEngine.instance.encodeTargetUrl(_currentDestination);

        ui_web.platformViewRegistry.registerViewFactory(_iframeViewType, (int viewId) {
          final iframe = web.HTMLIFrameElement()
            ..src = encodedSrc
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..setAttribute('allow', 'fullscreen; camera; microphone; payment; autoplay; clipboard-write; web-share; accelerometer; gyroscope')
            ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-forms allow-popups allow-pointer-lock allow-downloads');
          return iframe;
        });
      } catch (e) {
        debugPrint('[RbiBrowser] Notice on iframe registration: $e');
      }
    }
  }

  void _loadUrl(String rawUrl) {
    var target = rawUrl.trim();
    if (target.isEmpty) return;

    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      if (target.contains('.') && !target.contains(' ')) {
        target = 'https://$target';
      } else {
        target = 'https://duckduckgo.com/html/?q=${Uri.encodeComponent(target)}';
      }
    }

    setState(() {
      _currentDestination = target;
      _urlController.text = target;
      _iframeViewType = 'uv_iframe_${DateTime.now().millisecondsSinceEpoch}';
    });

    _registerIframe();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ProxyEngine.instance, AuthService.instance]),
      builder: (context, _) {
        final proxy = ProxyEngine.instance;
        final auth = AuthService.instance;

        return Container(
          color: const Color(0xFF0F172A),
          child: Column(
            children: [
              // Browser Toolbar
              _buildToolbar(proxy),

              // Game & Site Presets Bar
              _buildPresetsBar(),

              // Telemetry & Security Strip
              _buildTelemetryStrip(proxy, auth),

              // Native WebGL / Canvas / DOM Iframe Viewport
              Expanded(
                child: _buildIframeViewport(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(ProxyEngine proxy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0x2238BDF8))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            onPressed: () => _loadUrl(_currentDestination),
            tooltip: 'Reload',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded, size: 18),
            onPressed: () => _loadUrl('https://news.ycombinator.com'),
            tooltip: 'Home',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),

          // Address Bar
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
                  const Icon(Icons.shield_rounded, size: 15, color: WebOSTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        border: InputBorder.none,
                        hintText: 'Enter URL or game to launch via Wisp/UV...',
                        hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      onSubmitted: _loadUrl,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: WebOSTheme.primary),
                    onPressed: () => _loadUrl(_urlController.text),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Wisp Proxy Endpoint Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x3338BDF8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_rounded, size: 14, color: WebOSTheme.accent),
                const SizedBox(width: 6),
                Text(
                  proxy.wispUrl.contains('localhost') ? 'Local Wisp' : 'Cloud Wisp',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsBar() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF131D33),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _gamePresets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final preset = _gamePresets[index];
          final isSelected = _currentDestination == preset['url'];
          return InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _loadUrl(preset['url']!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0x3338BDF8) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(preset['icon'] as IconData, size: 13, color: WebOSTheme.primary),
                  const SizedBox(width: 5),
                  Text(
                    preset['title']!,
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

  Widget _buildTelemetryStrip(ProxyEngine proxy, AuthService auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      color: const Color(0xFF0A0F1D),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x2210B981),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WebOSTheme.accent, width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 11, color: WebOSTheme.accent),
                SizedBox(width: 4),
                Text(
                  'ULTRAVIOLET + WISP ACTIVE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: WebOSTheme.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          Text(
            'UID: ${auth.displayUid}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 12),

          const Text(
            '60+ FPS Native WebGL Context',
            style: TextStyle(fontSize: 11, color: WebOSTheme.primary, fontWeight: FontWeight.bold),
          ),
          const Spacer(),

          Text(
            'Endpoint: ${proxy.wispUrl}',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildIframeViewport() {
    if (kIsWeb) {
      return HtmlElementView(
        key: ValueKey(_iframeViewType),
        viewType: _iframeViewType,
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: const Text(
          'Ultraviolet in-browser proxy engine is active in Web browser contexts (WebGL/Canvas)',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
    );
  }
}
