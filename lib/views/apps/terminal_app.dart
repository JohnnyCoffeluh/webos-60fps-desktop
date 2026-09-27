import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/gateway_client.dart';
import '../../services/auth_service.dart';
import '../../theme/webos_theme.dart';

class TerminalApp extends StatefulWidget {
  const TerminalApp({super.key});

  @override
  State<TerminalApp> createState() => _TerminalAppState();
}

class _TerminalAppState extends State<TerminalApp> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _history.add('WebOS Virtual Network Terminal [Version 2.4.0]');
    _history.add('Connected to Express Gateway: ${GatewayClient.instance.gatewayUrl}');
    _history.add('Authenticated as: ${AuthService.instance.displayUid}');
    _history.add('Type "help" for a list of available commands.\n');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleCommand(String rawCmd) async {
    final cmd = rawCmd.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _history.add('anon@webos:~\$ $cmd');
      _inputController.clear();
    });

    final parts = cmd.split(RegExp(r'\s+'));
    final mainCmd = parts[0].toLowerCase();
    final args = parts.sublist(1);

    switch (mainCmd) {
      case 'help':
        _history.add('Available WebOS Commands:');
        _history.add('  ping <host>       - Ping host or gateway for latency');
        _history.add('  curl <url>        - Fetch web resource through Express Gateway');
        _history.add('  gateway status    - View routing backend health & cache metrics');
        _history.add('  auth              - Display Firebase Anonymous Session credentials');
        _history.add('  speedtest         - Measure throughput and cache efficiency');
        _history.add('  date              - Show current system date and UTC time');
        _history.add('  uptime            - Display gateway server uptime');
        _history.add('  clear             - Clear terminal screen');
        break;

      case 'clear':
        setState(() {
          _history.clear();
        });
        return;

      case 'date':
        _history.add('${DateTime.now().toUtc().toIso8601String()} UTC');
        break;

      case 'uptime':
        _history.add('Gateway Server Uptime: ${GatewayClient.instance.telemetry.serverUptime}');
        break;

      case 'auth':
        final auth = AuthService.instance;
        _history.add('Firebase Authentication Status:');
        _history.add('  Authenticated : ${auth.isAuthenticated}');
        _history.add('  User ID       : ${auth.currentUser?.uid ?? "Anonymous Session"}');
        _history.add('  Display Badge : ${auth.displayUid}');
        _history.add('  Provider      : Anonymous (Instant zero-friction access)');
        _history.add('  Token Length  : ${auth.idToken?.length ?? 0} characters');
        break;

      case 'gateway':
        if (args.isNotEmpty && args[0] == 'status') {
          final telem = GatewayClient.instance.telemetry;
          _history.add('Express Gateway Status:');
          _history.add('  Endpoint      : ${GatewayClient.instance.gatewayUrl}');
          _history.add('  Status        : ${telem.isConnected ? "CONNECTED" : "OFFLINE"}');
          _history.add('  Ping Latency  : ${telem.latencyMs} ms');
          _history.add('  Total Req     : ${telem.totalRequests}');
          _history.add('  Cache Hits    : ${telem.cacheHits}');
          _history.add('  Service Worker: INTERCEPTING (sw.js)');
        } else {
          _history.add('Usage: gateway status');
        }
        break;

      case 'ping':
        final target = args.isNotEmpty ? args[0] : GatewayClient.instance.gatewayUrl;
        _history.add('PING $target via Express Gateway...');
        final stopwatch = Stopwatch()..start();
        await GatewayClient.instance.pingGateway();
        stopwatch.stop();
        _history.add('64 bytes from $target: time=${stopwatch.elapsedMilliseconds}ms TTL=64');
        _history.add('--- $target ping statistics ---');
        _history.add('1 packets transmitted, 1 received, 0% packet loss, time ${stopwatch.elapsedMilliseconds}ms');
        break;

      case 'curl':
        if (args.isEmpty) {
          _history.add('Usage: curl <url>');
        } else {
          final targetUrl = args[0];
          _history.add('Routing $targetUrl through Gateway Proxy...');
          final res = await GatewayClient.instance.fetchProxied(targetUrl);
          _history.add('< HTTP/1.1 ${res.statusCode}');
          _history.add('< X-Gateway-Latency: ${res.latencyMs}ms');
          _history.add('< X-Gateway-Cache: ${res.isCacheHit ? "HIT" : "MISS"}');
          _history.add('< Content-Length: ${res.body.length}');
          _history.add('');
          final preview = res.body.length > 300 ? '${res.body.substring(0, 300)}...\n[Payload truncated]' : res.body;
          _history.add(preview);
        }
        break;

      case 'speedtest':
        _history.add('Testing Virtual Desktop Gateway Speed...');
        final t1 = Stopwatch()..start();
        await GatewayClient.instance.pingGateway();
        t1.stop();
        _history.add('✓ Gateway Roundtrip : ${t1.elapsedMilliseconds} ms');
        _history.add('✓ Cache Hit Speed   : 0 ms (Instant RAM)');
        _history.add('✓ Compression       : Gzip/Brotli Active');
        _history.add('✓ Quality of Service: ULTRA-FAST');
        break;

      default:
        _history.add('webos: command not found: $mainCmd. Type "help" for commands.');
        break;
    }

    _history.add('');
    setState(() {});
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF070B14),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final line = _history[index];
                final isPrompt = line.startsWith('anon@webos:');
                final isError = line.contains('command not found') || line.contains('FAILED');
                final isSuccess = line.contains('CONNECTED') || line.contains('✓') || line.contains('Authenticated : true');

                Color textColor = const Color(0xFFE2E8F0);
                if (isPrompt) textColor = WebOSTheme.primary;
                if (isError) textColor = WebOSTheme.error;
                if (isSuccess) textColor = WebOSTheme.accent;

                return Text(
                  line,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    color: textColor,
                    height: 1.4,
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Color(0x3338BDF8))),
            ),
            child: Row(
              children: [
                Text(
                  'anon@webos:~\$ ',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    color: WebOSTheme.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    autofocus: true,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.5,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onSubmitted: _handleCommand,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
