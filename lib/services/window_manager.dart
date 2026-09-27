import 'dart:math';
import 'package:flutter/material.dart';
import '../models/window_model.dart';

class WindowManager extends ChangeNotifier {
  static final WindowManager instance = WindowManager._internal();
  WindowManager._internal();

  final List<WindowState> _windows = [];
  List<WindowState> get windows => List.unmodifiable(_windows);

  String? _activeWindowId;
  String? get activeWindowId => _activeWindowId;

  int _nextZIndex = 1;

  WindowState? getWindow(String id) {
    try {
      return _windows.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  void openApp(WindowAppType type, {Size? initialSize, Offset? initialPosition}) {
    // If single-instance app already open, focus it
    final existing = _windows.where((w) => w.type == type).toList();
    if (existing.isNotEmpty) {
      final win = existing.first;
      if (win.isMinimized) win.isMinimized = false;
      focusWindow(win.id);
      notifyListeners();
      return;
    }

    final id = 'win_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    String title;
    IconData icon;
    Size size = initialSize ?? const Size(820, 560);
    Offset position = initialPosition ?? Offset(
      80.0 + (_windows.length * 35),
      60.0 + (_windows.length * 30),
    );

    switch (type) {
      case WindowAppType.rbiBrowser:
        title = 'Remote Browser Isolation (Air-Gapped)';
        icon = Icons.security_rounded;
        size = const Size(980, 640);
        break;
      case WindowAppType.browser:
        title = 'Apex Virtual Browser';
        icon = Icons.public_rounded;
        size = const Size(920, 620);
        break;
      case WindowAppType.gatewayMonitor:
        title = 'Network Gateway & Telemetry';
        icon = Icons.hub_rounded;
        size = const Size(780, 520);
        break;
      case WindowAppType.terminal:
        title = 'Nexus Terminal';
        icon = Icons.terminal_rounded;
        size = const Size(720, 480);
        break;
      case WindowAppType.notes:
        title = 'Workspace Cloud Notes';
        icon = Icons.note_alt_rounded;
        size = const Size(640, 500);
        break;
      case WindowAppType.settings:
        title = 'System & Network Settings';
        icon = Icons.settings_rounded;
        size = const Size(680, 520);
        break;
    }

    final newWindow = WindowState(
      id: id,
      title: title,
      icon: icon,
      type: type,
      position: position,
      size: size,
      zIndex: _nextZIndex++,
    );

    _windows.add(newWindow);
    _activeWindowId = id;
    notifyListeners();
  }

  void focusWindow(String id) {
    final win = getWindow(id);
    if (win != null) {
      win.zIndex = _nextZIndex++;
      _activeWindowId = id;
      notifyListeners();
    }
  }

  void minimizeWindow(String id) {
    final win = getWindow(id);
    if (win != null) {
      win.isMinimized = true;
      if (_activeWindowId == id) {
        // Focus top non-minimized window
        final visible = _windows.where((w) => !w.isMinimized).toList();
        if (visible.isNotEmpty) {
          visible.sort((a, b) => b.zIndex.compareTo(a.zIndex));
          _activeWindowId = visible.first.id;
        } else {
          _activeWindowId = null;
        }
      }
      notifyListeners();
    }
  }

  void toggleMaximizeWindow(String id, Size screenSize) {
    final win = getWindow(id);
    if (win != null) {
      if (win.isMaximized) {
        win.isMaximized = false;
        win.position = win.preMaximizePosition;
        win.size = win.preMaximizeSize;
      } else {
        win.preMaximizePosition = win.position;
        win.preMaximizeSize = win.size;
        win.isMaximized = true;
        win.position = Offset.zero;
        // Leave room for taskbar (approx 56px)
        win.size = Size(screenSize.width, max(200.0, screenSize.height - 56.0));
      }
      focusWindow(id);
    }
  }

  void closeWindow(String id) {
    _windows.removeWhere((w) => w.id == id);
    if (_activeWindowId == id) {
      final visible = _windows.where((w) => !w.isMinimized).toList();
      if (visible.isNotEmpty) {
        visible.sort((a, b) => b.zIndex.compareTo(a.zIndex));
        _activeWindowId = visible.first.id;
      } else {
        _activeWindowId = null;
      }
    }
    notifyListeners();
  }

  void updatePosition(String id, Offset delta) {
    final win = getWindow(id);
    if (win != null && !win.isMaximized) {
      win.position = Offset(
        max(-win.size.width + 100, win.position.dx + delta.dx),
        max(0.0, win.position.dy + delta.dy),
      );
      notifyListeners();
    }
  }

  void updateSize(String id, Size delta, {bool fromLeft = false, bool fromTop = false}) {
    final win = getWindow(id);
    if (win != null && !win.isMaximized) {
      double newWidth = max(380.0, win.size.width + delta.width);
      double newHeight = max(260.0, win.size.height + delta.height);

      double newX = win.position.dx;
      double newY = win.position.dy;

      if (fromLeft) {
        final actualDiffX = newWidth - win.size.width;
        newX -= actualDiffX;
      }
      if (fromTop) {
        final actualDiffY = newHeight - win.size.height;
        newY -= actualDiffY;
      }

      win.size = Size(newWidth, newHeight);
      win.position = Offset(newX, newY);
      notifyListeners();
    }
  }
}
