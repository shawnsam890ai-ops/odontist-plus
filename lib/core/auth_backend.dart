import '../models/app_user.dart';

abstract class AuthBackend {
  Future<AppUser?> currentUser();
  Stream<AppUser?> authStateChanges();
  Future<AppUser> register({required String email, required String password, String? displayName});
  Future<AppUser> signIn({required String email, required String password});
  Future<void> signOut();

  // Admin approval
  Future<void> setApproved(String uid, bool approved);
  Future<List<AppUser>> listUsers({bool? approved});
}
