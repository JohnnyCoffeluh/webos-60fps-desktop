import 'package:flutter/material.dart';

enum WindowAppType {
  rbiBrowser,
  browser,
  gatewayMonitor,
  terminal,
  notes,
  settings,
}

class WindowState {
  final String id;
  String title;
  IconData icon;
  final WindowAppType type;
  Offset position;
  Size size;
  bool isMinimized;
  bool isMaximized;
  int zIndex;
  Offset preMaximizePosition;
  Size preMaximizeSize;

  WindowState({
    required this.id,
    required this.title,
    required this.icon,
    required this.type,
    required this.position,
    required this.size,
    this.isMinimized = false,
    this.isMaximized = false,
    this.zIndex = 0,
    Offset? preMaximizePosition,
    Size? preMaximizeSize,
  })  : preMaximizePosition = preMaximizePosition ?? position,
        preMaximizeSize = preMaximizeSize ?? size;
}
