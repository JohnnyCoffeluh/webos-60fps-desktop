import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/webos_theme.dart';
import 'views/desktop/desktop_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[WebOS] Firebase initialization notice: $e');
  }
  runApp(const WebOSApp());
}

class WebOSApp extends StatelessWidget {
  const WebOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebOS - Virtual Desktop Workspace',
      debugShowCheckedModeBanner: false,
      theme: WebOSTheme.darkTheme,
      home: const DesktopView(),
    );
  }
}
