import 'package:flutter/material.dart';
import '../../models/window_model.dart';
import '../../services/window_manager.dart';
import '../../theme/webos_theme.dart';
import '../apps/browser_app.dart';
import '../apps/rbi_browser_app.dart';
import '../apps/gateway_monitor_app.dart';
import '../apps/terminal_app.dart';
import '../apps/notes_app.dart';
import '../apps/settings_app.dart';

class WindowFrame extends StatelessWidget {
  final WindowState window;
  final Function(String wallpaper)? onWallpaperChanged;

  const WindowFrame({
    super.key,
    required this.window,
    this.onWallpaperChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (window.isMinimized) return const SizedBox.shrink();

    final wm = WindowManager.instance;
    final isActive = wm.activeWindowId == window.id;
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 900;

    final left = (window.isMaximized || isCompact) ? 0.0 : window.position.dx.clamp(0.0, (screenSize.width - 100.0).clamp(0.0, screenSize.width));
    final top = (window.isMaximized || isCompact) ? 0.0 : window.position.dy.clamp(0.0, (screenSize.height - 100.0).clamp(0.0, screenSize.height));
    final width = (window.isMaximized || isCompact) ? screenSize.width : window.size.width.clamp(320.0, screenSize.width);
    final height = (window.isMaximized || isCompact)
        ? (screenSize.height - 48.0)
        : window.size.height.clamp(200.0, screenSize.height - 48.0);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTapDown: (_) => wm.focusWindow(window.id),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular((window.isMaximized || isCompact) ? 0 : 12),
            border: Border.all(
              color: isActive ? WebOSTheme.primary.withValues(alpha: 0.6) : const Color(0x33334155),
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive
                    ? WebOSTheme.primary.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.4),
                blurRadius: isActive ? 24 : 12,
                spreadRadius: isActive ? 2 : 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(window.isMaximized ? 0 : 11),
            child: Stack(
              children: [
                Column(
                  children: [
                    // Title Bar (Draggable)
                    _buildTitleBar(context, wm, isActive, screenSize),

                    // App Content
                    Expanded(
                      child: _buildAppContent(),
                    ),
                  ],
                ),

                // Resize Handles (only active when not maximized and not compact)
                if (!window.isMaximized && !isCompact) ..._buildResizeHandles(wm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context, WindowManager wm, bool isActive, Size screenSize) {
    final isCompact = screenSize.width < 900;
    return GestureDetector(
      onPanUpdate: isCompact ? null : (details) => wm.updatePosition(window.id, details.delta),
      onDoubleTap: () => wm.toggleMaximizeWindow(window.id, screenSize),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E293B) : const Color(0xFF141E33),
          border: const Border(bottom: BorderSide(color: Color(0x2238BDF8))),
        ),
        child: Row(
          children: [
            Icon(window.icon, size: 16, color: isActive ? WebOSTheme.primary : const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text(
              window.title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            const Spacer(),

            // Window Action Buttons
            _buildWindowButton(
              icon: Icons.remove_rounded,
              color: const Color(0xFFF59E0B),
              tooltip: 'Minimize',
              onTap: () => wm.minimizeWindow(window.id),
            ),
            const SizedBox(width: 6),
            _buildWindowButton(
              icon: window.isMaximized ? Icons.crop_square_rounded : Icons.crop_7_5_rounded,
              color: const Color(0xFF10B981),
              tooltip: window.isMaximized ? 'Restore' : 'Maximize',
              onTap: () => wm.toggleMaximizeWindow(window.id, screenSize),
            ),
            const SizedBox(width: 6),
            _buildWindowButton(
              icon: Icons.close_rounded,
              color: const Color(0xFFEF4444),
              tooltip: 'Close',
              onTap: () => wm.closeWindow(window.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
      ),
    );
  }

  Widget _buildAppContent() {
    switch (window.type) {
      case WindowAppType.rbiBrowser:
        return const RbiBrowserApp();
      case WindowAppType.browser:
        return const BrowserApp();
      case WindowAppType.gatewayMonitor:
        return const GatewayMonitorApp();
      case WindowAppType.terminal:
        return const TerminalApp();
      case WindowAppType.notes:
        return const NotesApp();
      case WindowAppType.settings:
        return SettingsApp(onWallpaperChanged: onWallpaperChanged);
    }
  }

  List<Widget> _buildResizeHandles(WindowManager wm) {
    const handleSize = 10.0;
    return [
      // Bottom Right corner
      Positioned(
        right: 0,
        bottom: 0,
        width: handleSize,
        height: handleSize,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeDownRight,
          child: GestureDetector(
            onPanUpdate: (d) => wm.updateSize(window.id, Size(d.delta.dx, d.delta.dy)),
          ),
        ),
      ),
      // Right edge
      Positioned(
        right: 0,
        top: 38,
        bottom: handleSize,
        width: handleSize,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeRight,
          child: GestureDetector(
            onPanUpdate: (d) => wm.updateSize(window.id, Size(d.delta.dx, 0)),
          ),
        ),
      ),
      // Bottom edge
      Positioned(
        left: handleSize,
        right: handleSize,
        bottom: 0,
        height: handleSize,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeDown,
          child: GestureDetector(
            onPanUpdate: (d) => wm.updateSize(window.id, Size(0, d.delta.dy)),
          ),
        ),
      ),
      // Left edge
      Positioned(
        left: 0,
        top: 38,
        bottom: handleSize,
        width: handleSize,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeft,
          child: GestureDetector(
            onPanUpdate: (d) => wm.updateSize(window.id, Size(-d.delta.dx, 0), fromLeft: true),
          ),
        ),
      ),
    ];
  }
}
