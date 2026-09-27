import 'package:flutter/material.dart';
import '../../models/window_model.dart';
import '../../services/window_manager.dart';
import '../../services/auth_service.dart';
import '../../services/gateway_client.dart';
import '../../theme/webos_theme.dart';

class StartMenu extends StatelessWidget {
  final VoidCallback onClose;

  const StartMenu({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final wm = WindowManager.instance;
    final auth = AuthService.instance;
    final gateway = GatewayClient.instance;

    return Container(
      width: 360,
      height: 480,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4438BDF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header / User Profile Chip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: WebOSTheme.primary.withValues(alpha: 0.2),
                  child: const Icon(Icons.person_rounded, color: WebOSTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.displayUid,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      const Row(
                        children: [
                          Icon(Icons.shield_rounded, size: 12, color: WebOSTheme.accent),
                          SizedBox(width: 4),
                          Text('Firebase Authenticated (Guest)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Pinned App Grid
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                const Text(
                  'Workspace Applications',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                _buildAppTile(
                  title: 'Remote Browser Isolation (RBI)',
                  subtitle: 'Air-gapped WebRTC Puppeteer Chromium',
                  icon: Icons.security_rounded,
                  color: WebOSTheme.accent,
                  onTap: () {
                    wm.openApp(WindowAppType.rbiBrowser);
                    onClose();
                  },
                ),
                _buildAppTile(
                  title: 'Apex Virtual Browser',
                  subtitle: 'High-speed proxy web browsing',
                  icon: Icons.public_rounded,
                  color: WebOSTheme.primary,
                  onTap: () {
                    wm.openApp(WindowAppType.browser);
                    onClose();
                  },
                ),
                _buildAppTile(
                  title: 'Network Gateway Telemetry',
                  subtitle: 'Express backend & latency monitor',
                  icon: Icons.hub_rounded,
                  color: WebOSTheme.accent,
                  onTap: () {
                    wm.openApp(WindowAppType.gatewayMonitor);
                    onClose();
                  },
                ),
                _buildAppTile(
                  title: 'Nexus CLI Terminal',
                  subtitle: 'Virtual shell & network diagnostics',
                  icon: Icons.terminal_rounded,
                  color: const Color(0xFFA855F7),
                  onTap: () {
                    wm.openApp(WindowAppType.terminal);
                    onClose();
                  },
                ),
                _buildAppTile(
                  title: 'Cloud Workspace Notes',
                  subtitle: 'Session scratchpad & documentation',
                  icon: Icons.note_alt_rounded,
                  color: WebOSTheme.warning,
                  onTap: () {
                    wm.openApp(WindowAppType.notes);
                    onClose();
                  },
                ),
                _buildAppTile(
                  title: 'System Settings',
                  subtitle: 'Wallpapers & network accelerators',
                  icon: Icons.settings_rounded,
                  color: const Color(0xFF64748B),
                  onTap: () {
                    wm.openApp(WindowAppType.settings);
                    onClose();
                  },
                ),
              ],
            ),
          ),

          // Footer Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0B132B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(
                  gateway.telemetry.isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  size: 14,
                  color: gateway.telemetry.isConnected ? WebOSTheme.accent : WebOSTheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gateway.telemetry.isConnected
                        ? 'Gateway Online: ${gateway.telemetry.latencyMs}ms'
                        : 'Gateway Unreachable',
                    style: TextStyle(
                      fontSize: 11,
                      color: gateway.telemetry.isConnected ? WebOSTheme.accent : WebOSTheme.error,
                    ),
                  ),
                ),
                Text(
                  'WebOS v2.4',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
      onTap: onTap,
    );
  }
}
