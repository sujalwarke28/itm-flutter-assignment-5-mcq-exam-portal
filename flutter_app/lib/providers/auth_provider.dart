import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService}) : _authService = authService ?? AuthService() {
    _sub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  StreamSubscription<User?>? _sub;

  AuthStatus status = AuthStatus.unknown;
  UserModel? profile;
  bool isLoading = false;
  String? errorMessage;

  bool get isAdmin => profile?.isAdmin ?? false;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      profile = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      profile = await _authService.fetchUserProfile(user.uid);
      status = profile != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> signUp({required String name, required String email, required String password}) {
    return _runGuarded(() async {
      profile = await _authService.signUpWithEmail(name: name, email: email, password: password);
      status = AuthStatus.authenticated;
    });
  }

  Future<bool> signIn({required String email, required String password}) {
    return _runGuarded(() async {
      profile = await _authService.signInWithEmail(email: email, password: password);
      status = AuthStatus.authenticated;
    });
  }

  Future<bool> signInWithGoogle() {
    return _runGuarded(() async {
      profile = await _authService.signInWithGoogle();
      status = AuthStatus.authenticated;
    });
  }

  Future<bool> sendPasswordReset(String email) {
    return _runGuarded(() => _authService.sendPasswordResetEmail(email));
  }

  Future<void> refreshProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    profile = await _authService.fetchUserProfile(uid);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  Future<bool> _runGuarded(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      return false;
    } catch (e) {
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
