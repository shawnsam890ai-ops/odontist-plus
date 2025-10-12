import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../core/auth_backend.dart';
import '../core/auth_backend_local.dart';

// To switch to Firebase after running `flutterfire configure`, import
//   import '../core/auth_backend_firebase.dart';
// and pass: AuthProvider(backend: FirebaseAuthBackend()) at provider creation.
class AuthProvider extends ChangeNotifier {
  final AuthBackend _backend;
  AppUser? _user;
  bool _loaded = false;

  AuthProvider({AuthBackend? backend}) : _backend = backend ?? LocalMockAuthBackend() {
    _backend.authStateChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  AppUser? get user => _user;
  bool get isLoaded => _loaded;
  bool get isLoggedIn => _user != null;
  bool get isApproved => _user?.approved == true;
  bool get isAdmin => _user?.role == UserRole.admin;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _user = await _backend.currentUser();
    _loaded = true;
    notifyListeners();
  }

  Future<String?> register(String email, String password, {String? displayName}) async {
    try {
      _user = await _backend.register(email: email, password: password, displayName: displayName);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      _user = await _backend.signIn(email: email, password: password);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _backend.signOut();
    _user = null;
    notifyListeners();
  }

  Future<List<AppUser>> listPendingUsers() async => _backend.listUsers(approved: false);
  Future<void> approveUser(String uid) async => _backend.setApproved(uid, true);
  Future<void> revokeUser(String uid) async => _backend.setApproved(uid, false);
}
