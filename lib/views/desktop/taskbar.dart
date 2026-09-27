import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/window_model.dart';
import '../../services/window_manager.dart';
import '../../services/gateway_client.dart';
import '../../services/auth_service.dart';
import '../../theme/webos_theme.dart';

class Taskbar extends StatefulWidget {
  final VoidCallback onToggleStartMenu;
  final bool isStartMenuOpen;

  const Taskbar({
    super.key,
    required this.onToggleStartMenu,
    required this.isStartMenuOpen,
  });

  @override
  State<Taskbar> createState() => _TaskbarState();
}

class _TaskbarState extends State<Taskbar> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        WindowManager.instance,
        GatewayClient.instance,
        AuthService.instance,
      ]),
      builder: (context, _) {
        final gateway = GatewayClient.instance;
        final auth = AuthService.instance;

        return Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.9),
            border: const Border(top: BorderSide(color: Color(0x3338BDF8), width: 1.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              // Start Button
              _buildStartButton(),
              const SizedBox(width: 8),

              // Running & Pinned Apps
              Expanded(
                child: Row(
                  children: [
                    _buildAppShortcut(WindowAppType.rbiBrowser, 'RBI Browser', Icons.security_rounded, WebOSTheme.accent),
                    _buildAppShortcut(WindowAppType.browser, 'Browser', Icons.public_rounded, WebOSTheme.primary),
                    _buildAppShortcut(WindowAppType.gatewayMonitor, 'Gateway', Icons.hub_rounded, WebOSTheme.accent),
                    _buildAppShortcut(WindowAppType.terminal, 'Terminal', Icons.terminal_rounded, const Color(0xFFA855F7)),
                    _buildAppShortcut(WindowAppType.notes, 'Notes', Icons.note_alt_rounded, WebOSTheme.warning),
                    _buildAppShortcut(WindowAppType.settings, 'Settings', Icons.settings_rounded, const Color(0xFF94A3B8)),
                  ],
                ),
              ),

              // System Tray
              _buildSystemTray(auth, gateway),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStartButton() {
    return InkWell(
      onTap: widget.onToggleStartMenu,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isStartMenuOpen ? WebOSTheme.primary.withValues(alpha: 0.25) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isStartMenuOpen ? WebOSTheme.primary : const Color(0x3338BDF8),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: WebOSTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.apps_rounded, size: 13, color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 6),
            const Text(
              'WebOS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppShortcut(WindowAppType type, String label, IconData icon, Color color) {
    final wm = WindowManager.instance;
    final windows = wm.windows.where((w) => w.type == type).toList();
    final isOpen = windows.isNotEmpty;
    final isFocused = isOpen && wm.activeWindowId == windows.first.id && !windows.first.isMinimized;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () {
            if (!isOpen) {
              wm.openApp(type);
            } else {
              final win = windows.first;
              if (win.isMinimized) {
                win.isMinimized = false;
                wm.focusWindow(win.id);
              } else if (isFocused) {
                wm.minimizeWindow(win.id);
              } else {
                wm.focusWindow(win.id);
              }
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isFocused
                  ? color.withValues(alpha: 0.2)
                  : (isOpen ? const Color(0xFF1E293B) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isFocused ? color : (isOpen ? const Color(0x2238BDF8) : Colors.transparent),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: isOpen ? color : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                    color: isFocused ? Colors.white : (isOpen ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                  ),
                ),
                if (isOpen) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isFocused ? color : const Color(0xFF64748B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemTray(AuthService auth, GatewayClient gateway) {
    final isOnline = gateway.telemetry.isConnected;
    final latency = gateway.telemetry.latencyMs;

    return Row(
      children: [
        // Firebase Auth badge
        Tooltip(
          message: 'Firebase Authenticated (Guest User)\nUID: ${auth.currentUser?.uid ?? "Anonymous"}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0x3310B981)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, size: 13, color: WebOSTheme.accent),
                const SizedBox(width: 4),
                Text(
                  auth.displayUid,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Network Gateway Ping Indicator
        Tooltip(
          message: isOnline
              ? 'Wisp/Bare Gateway: Connected\nEndpoint: ${gateway.gatewayUrl}\nPing: ${latency}ms\nService Worker: Intercepting'
              : 'Wisp/Bare Gateway: Offline\nCheck connection to ${gateway.gatewayUrl}',
          child: InkWell(
            onTap: () => WindowManager.instance.openApp(WindowAppType.gatewayMonitor),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isOnline ? WebOSTheme.accent.withValues(alpha: 0.4) : WebOSTheme.error.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 14,
                    color: isOnline ? WebOSTheme.accent : WebOSTheme.error,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isOnline ? '${latency}ms' : 'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? WebOSTheme.accent : WebOSTheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Digital Clock
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(_now),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              _formatDate(_now),
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ],
    );
  }
}
