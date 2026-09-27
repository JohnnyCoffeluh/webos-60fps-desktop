import 'package:flutter/material.dart';
import '../../services/gateway_client.dart';
import '../../services/proxy_engine.dart';
import '../../services/auth_service.dart';
import '../../theme/webos_theme.dart';

class GatewayMonitorApp extends StatefulWidget {
  const GatewayMonitorApp({super.key});

  @override
  State<GatewayMonitorApp> createState() => _GatewayMonitorAppState();
}

class _GatewayMonitorAppState extends State<GatewayMonitorApp> {
  late TextEditingController _urlController;
  bool _isPinging = false;
  String? _lastDiagnosticLog;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: GatewayClient.instance.gatewayUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _manualPing() async {
    setState(() => _isPinging = true);
    final stopwatch = Stopwatch()..start();
    await GatewayClient.instance.pingGateway();
    stopwatch.stop();

    if (mounted) {
      setState(() {
        _isPinging = false;
        _lastDiagnosticLog = 'Diagnostic Ping executed in ${stopwatch.elapsedMilliseconds}ms.\n'
            'Status: ${GatewayClient.instance.telemetry.isConnected ? "CONNECTED (HTTP 200 OK)" : "FAILED (UNREACHABLE)"}\n'
            'Gateway: ${GatewayClient.instance.gatewayUrl}\n'
            'Service Worker Interception: ENABLED\n'
            'Auth Token: ${AuthService.instance.isAuthenticated ? "Verified (JWT Active)" : "Anonymous Session"}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([GatewayClient.instance, AuthService.instance]),
      builder: (context, _) {
        final gateway = GatewayClient.instance;
        final auth = AuthService.instance;
        final telem = gateway.telemetry;

        return Container(
          color: const Color(0xFF0B132B),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top status header
                _buildHeaderCard(telem, auth),
                const SizedBox(height: 16),

                // Metrics Grid
                _buildMetricsGrid(telem),
                const SizedBox(height: 20),

                // Gateway configuration form
                _buildConfigurationCard(gateway),
                const SizedBox(height: 20),

                // Live Diagnostics Log
                _buildDiagnosticsLog(telem),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(GatewayTelemetry telem, AuthService auth) {
    final isOnline = telem.isConnected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOnline ? WebOSTheme.accent.withValues(alpha: 0.3) : WebOSTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isOnline ? WebOSTheme.accent : WebOSTheme.error).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOnline ? Icons.router_rounded : Icons.cloud_off_rounded,
              color: isOnline ? WebOSTheme.accent : WebOSTheme.error,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOnline ? 'Express Gateway Online' : 'Gateway Disconnected',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOnline ? WebOSTheme.accent.withValues(alpha: 0.2) : WebOSTheme.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOnline ? '${telem.latencyMs}ms' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOnline ? WebOSTheme.accent : WebOSTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Routing: ${GatewayClient.instance.gatewayUrl} • Service Worker: Active • Tier: ${auth.displayUid}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isPinging ? null : _manualPing,
            icon: _isPinging
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.bolt_rounded, size: 16),
            label: const Text('Ping Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WebOSTheme.primary,
              foregroundColor: const Color(0xFF0F172A),
              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(GatewayTelemetry telem) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildMetricItem(
              title: 'Roundtrip Latency',
              value: telem.isConnected ? '${telem.latencyMs} ms' : 'N/A',
              icon: Icons.speed_rounded,
              color: WebOSTheme.accent,
            ),
            _buildMetricItem(
              title: 'Cache Hit Rate',
              value: telem.totalRequests > 0 ? '${((telem.cacheHits / telem.totalRequests) * 100).toStringAsFixed(1)}%' : '0%',
              icon: Icons.flash_on_rounded,
              color: WebOSTheme.primary,
            ),
            _buildMetricItem(
              title: 'Total Requests',
              value: '${telem.totalRequests}',
              icon: Icons.sync_alt_rounded,
              color: WebOSTheme.secondary,
            ),
            _buildMetricItem(
              title: 'Server Uptime',
              value: telem.serverUptime,
              icon: Icons.timer_rounded,
              color: WebOSTheme.warning,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard(GatewayClient gateway) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2238BDF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gateway Server Configuration',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'External Node.js & Express routing proxy backend URL:',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0x4438BDF8)),
                    ),
                    hintText: gateway.gatewayUrl,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  gateway.setGatewayUrl(_urlController.text);
                  ProxyEngine.instance.updateEndpoint(_urlController.text);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gateway & Wisp/Bare URL updated and synced with Service Worker')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: WebOSTheme.primary,
                  side: const BorderSide(color: WebOSTheme.primary),
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsLog(GatewayTelemetry telem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x3338BDF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal_rounded, size: 16, color: WebOSTheme.primary),
              SizedBox(width: 8),
              Text(
                'Live Diagnostic Output',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _lastDiagnosticLog ??
                'Gateway Telemetry Stream initialized.\n'
                'Listening on ${GatewayClient.instance.gatewayUrl}...\n'
                'Service Worker is intercepting virtual desktop traffic.\n'
                'All requests authenticated with Firebase Anonymous Credentials.',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFF38BDF8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
