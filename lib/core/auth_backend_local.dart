import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import 'auth_backend.dart';

class LocalMockAuthBackend implements AuthBackend {
  static const _kUsers = 'auth_users_v1';
  static const _kCurrent = 'auth_current_uid_v1';
  final _ctrl = StreamController<AppUser?>.broadcast();

  Future<List<AppUser>> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kUsers);
    if (s == null || s.isEmpty) return [];
    final list = (jsonDecode(s) as List).cast<dynamic>();
    return list.map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> _saveUsers(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsers, jsonEncode(users.map((e) => e.toJson()).toList()));
  }

  Future<void> _setCurrentUid(String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (uid == null) {
      await prefs.remove(_kCurrent);
    } else {
      await prefs.setString(_kCurrent, uid);
    }
  }

  @override
  Future<AppUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_kCurrent);
    if (uid == null) return null;
    final users = await _loadUsers();
    return users.where((u) => u.uid == uid).cast<AppUser?>().firstWhere((u) => true, orElse: () => null);
  }

  @override
  Stream<AppUser?> authStateChanges() => _ctrl.stream;

  @override
  Future<AppUser> register({required String email, required String password, String? displayName}) async {
    final users = await _loadUsers();
    if (users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      throw Exception('User already exists');
    }
    // First user becomes admin; others are regular users and not approved until admin flips the switch
    final role = users.isEmpty ? UserRole.admin : UserRole.user;
    final approved = users.isEmpty; // auto-approve first admin
    final u = AppUser(uid: DateTime.now().microsecondsSinceEpoch.toString(), email: email, displayName: displayName, role: role, approved: approved);
    users.add(u);
    await _saveUsers(users);
    await _setCurrentUid(u.uid);
    _ctrl.add(u);
    return u;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    final users = await _loadUsers();
    final u = users.firstWhere((x) => x.email.toLowerCase() == email.toLowerCase(), orElse: () => throw Exception('User not found'));
    await _setCurrentUid(u.uid);
    _ctrl.add(u);
    return u;
  }

  @override
  Future<void> signOut() async {
    await _setCurrentUid(null);
    _ctrl.add(null);
  }

  @override
  Future<void> setApproved(String uid, bool approved) async {
    final users = await _loadUsers();
    final idx = users.indexWhere((u) => u.uid == uid);
    if (idx == -1) return;
    final u = users[idx];
    users[idx] = u.copyWith(approved: approved);
    await _saveUsers(users);
    // If approving current user, push event
    final cur = await currentUser();
    if (cur != null && cur.uid == uid) _ctrl.add(users[idx]);
  }

  @override
  Future<List<AppUser>> listUsers({bool? approved}) async {
    final users = await _loadUsers();
    if (approved == null) return users;
    return users.where((u) => u.approved == approved).toList();
  }
}
