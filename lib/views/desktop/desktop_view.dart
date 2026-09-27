import 'package:flutter/material.dart';
import '../../models/window_model.dart';
import '../../services/window_manager.dart';
import '../../services/auth_service.dart';
import '../../services/gateway_client.dart';
import '../../services/proxy_engine.dart';
import '../../theme/webos_theme.dart';
import 'window_frame.dart';
import 'taskbar.dart';
import 'start_menu.dart';

class DesktopView extends StatefulWidget {
  const DesktopView({super.key});

  @override
  State<DesktopView> createState() => _DesktopViewState();
}

class _DesktopViewState extends State<DesktopView> {
  bool _isStartMenuOpen = false;
  String _currentWallpaper = 'Cyber Obsidian';
  bool _isBooting = true;

  @override
  void initState() {
    super.initState();
    // Initialize services
    AuthService.instance.initializeAuth().then((_) {
      GatewayClient.instance.initialize();
      ProxyEngine.instance.initialize();
      // Open Remote Browser Isolation app on boot
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() => _isBooting = false);
          WindowManager.instance.openApp(WindowAppType.rbiBrowser);
        }
      });
    });
  }

  void _toggleStartMenu() {
    setState(() => _isStartMenuOpen = !_isStartMenuOpen);
  }

  void _closeStartMenu() {
    if (_isStartMenuOpen) {
      setState(() => _isStartMenuOpen = false);
    }
  }

  BoxDecoration _getWallpaperDecoration() {
    switch (_currentWallpaper) {
      case 'Neon Nebula':
        return const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.4, -0.5),
            radius: 1.2,
            colors: [Color(0xFF3B0764), Color(0xFF1E1B4B), Color(0xFF030712)],
          ),
        );
      case 'Deep Aurora':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF064E3B), Color(0xFF042F2E), Color(0xFF020617)],
          ),
        );
      case 'Midnight Slate':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
          ),
        );
      case 'Cyber Obsidian':
      default:
        return const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.3, -0.6),
            radius: 1.3,
            colors: [Color(0xFF0C1F38), Color(0xFF070E1A), Color(0xFF030712)],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBooting) {
      return _buildBootScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _closeStartMenu,
        child: Container(
          decoration: _getWallpaperDecoration(),
          child: Stack(
            children: [
              // Subtle grid pattern overlay
              CustomPaint(
                size: Size.infinite,
                painter: DesktopGridPainter(),
              ),

              // Desktop Icons Grid
              _buildDesktopIconsGrid(),

              // Floating Windows Stack
              _buildWindowsStack(),

              // Start Menu Popup
              if (_isStartMenuOpen)
                Positioned(
                  left: 10,
                  bottom: 56,
                  child: StartMenu(onClose: _closeStartMenu),
                ),

              // Bottom Taskbar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Taskbar(
                  onToggleStartMenu: _toggleStartMenu,
                  isStartMenuOpen: _isStartMenuOpen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBootScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0x3338BDF8), Colors.transparent],
                ),
                border: Border.all(color: WebOSTheme.primary.withValues(alpha: 0.5), width: 2),
              ),
              child: const Icon(Icons.cloud_sync_rounded, size: 48, color: WebOSTheme.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'WebOS Workspace',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Authenticating with Firebase & Linking Network Gateway...',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFF1E293B),
                color: WebOSTheme.primary,
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopIconsGrid() {
    final wm = WindowManager.instance;
    return Positioned(
      left: 16,
      top: 16,
      bottom: 60,
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDesktopIcon(
            title: 'RBI Browser',
            icon: Icons.security_rounded,
            color: WebOSTheme.accent,
            onTap: () => wm.openApp(WindowAppType.rbiBrowser),
          ),
          const SizedBox(height: 16),
          _buildDesktopIcon(
            title: 'Apex Browser',
            icon: Icons.public_rounded,
            color: WebOSTheme.primary,
            onTap: () => wm.openApp(WindowAppType.browser),
          ),
          const SizedBox(height: 16),
          _buildDesktopIcon(
            title: 'Gateway',
            icon: Icons.hub_rounded,
            color: WebOSTheme.accent,
            onTap: () => wm.openApp(WindowAppType.gatewayMonitor),
          ),
          const SizedBox(height: 16),
          _buildDesktopIcon(
            title: 'Terminal',
            icon: Icons.terminal_rounded,
            color: const Color(0xFFA855F7),
            onTap: () => wm.openApp(WindowAppType.terminal),
          ),
          const SizedBox(height: 16),
          _buildDesktopIcon(
            title: 'Cloud Notes',
            icon: Icons.note_alt_rounded,
            color: WebOSTheme.warning,
            onTap: () => wm.openApp(WindowAppType.notes),
          ),
          const SizedBox(height: 16),
          _buildDesktopIcon(
            title: 'Settings',
            icon: Icons.settings_rounded,
            color: const Color(0xFF94A3B8),
            onTap: () => wm.openApp(WindowAppType.settings),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopIcon({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowsStack() {
    return ListenableBuilder(
      listenable: WindowManager.instance,
      builder: (context, _) {
        final windows = List<WindowState>.from(WindowManager.instance.windows)
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

        return Stack(
          children: windows.map((w) {
            return WindowFrame(
              key: ValueKey(w.id),
              window: w,
              onWallpaperChanged: (wp) => setState(() => _currentWallpaper = wp),
            );
          }).toList(),
        );
      },
    );
  }
}

class DesktopGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0638BDF8)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
