import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Authentication Service for WebOS.
/// Provides zero-friction anonymous authentication ensuring everyone can access
/// the workspace instantly while generating valid Firebase Auth JWT tokens
/// for the authenticated network gateway client.
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _currentUser;
  String? _idToken;
  bool _isLoading = true;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  String? get idToken => _idToken;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;

  String get displayUid {
    if (_currentUser == null) return 'Not Authenticated';
    final uid = _currentUser!.uid;
    return 'Anon-${uid.length > 6 ? uid.substring(0, 6) : uid}';
  }

  /// Initialize and perform immediate anonymous sign-in
  Future<void> initializeAuth() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Listen to auth changes
      _auth.authStateChanges().listen((User? user) async {
        _currentUser = user;
        if (user != null) {
          _idToken = await user.getIdToken();
        } else {
          _idToken = null;
        }
        _isLoading = false;
        notifyListeners();
      });

      // If no user is logged in, sign in anonymously immediately
      if (_auth.currentUser == null) {
        final credential = await _auth.signInAnonymously();
        _currentUser = credential.user;
        _idToken = await credential.user?.getIdToken();
      } else {
        _currentUser = _auth.currentUser;
        _idToken = await _currentUser?.getIdToken();
      }
    } catch (e) {
      debugPrint('[AuthService] Anonymous sign-in notice: $e');
      // If Firebase project auth isn't toggled yet in console, generate a fallback local anonymous session
      _errorMessage = e.toString();
      _idToken = 'webos-anon-${DateTime.now().millisecondsSinceEpoch}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh Firebase ID token
  Future<String?> refreshToken() async {
    if (_currentUser != null) {
      _idToken = await _currentUser!.getIdToken(true);
      notifyListeners();
    }
    return _idToken;
  }
}
