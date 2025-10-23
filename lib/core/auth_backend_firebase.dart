import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../models/app_user.dart';
import 'auth_backend.dart';

class FirebaseAuthBackend implements AuthBackend {
  final fb_auth.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final _ctrl = StreamController<AppUser?>.broadcast();
  StreamSubscription<fb_auth.User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  FirebaseAuthBackend({fb_auth.FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? fb_auth.FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance {
    _authSub = _auth.authStateChanges().listen((user) async {
      await _attachProfileListener(user);
    });
    _attachProfileListener(_auth.currentUser);
  }

  Future<void> _attachProfileListener(fb_auth.User? user) async {
    await _profileSub?.cancel();
    if (user == null) {
      _ctrl.add(null);
      return;
    }
    final docRef = _db.collection('users').doc(user.uid);
    final snap = await docRef.get();
    if (!snap.exists) {
      await _ensureInitialRoleAndProfile(user);
    }
    _profileSub = docRef.snapshots().listen((doc) {
      _ctrl.add(_userFrom(user, doc.data()));
    });
  }

  Future<void> _ensureInitialRoleAndProfile(fb_auth.User user) async {
    final col = _db.collection('users');
  final firstDoc = await col.limit(1).get();
  final isFirst = firstDoc.docs.isEmpty;
  final role = isFirst ? 'admin' : 'user';
  // Auto-approve all users; licensing will gate access separately
  final approved = true;
    await col.doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'role': role,
      'approved': approved,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  AppUser _userFrom(fb_auth.User user, Map<String, dynamic>? data) {
    final roleStr = (data?['role'] as String?) ?? 'user';
  // Default to approved=true if field is missing to avoid blocking on manual approval
  final approved = (data?['approved'] as bool?) ?? true;
    final displayName = (data?['displayName'] as String?) ?? user.displayName;
    final clinicId = data?['clinicId'] as String?;
    DateTime createdAt = DateTime.now();
    final createdRaw = data?['createdAt'];
    if (createdRaw is Timestamp) {
      createdAt = createdRaw.toDate();
    } else if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();
    }
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: displayName,
      clinicId: clinicId,
      role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
      approved: approved,
      createdAt: createdAt,
    );
  }

  AppUser _userFromProfileDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final roleStr = (d['role'] as String?) ?? 'user';
  final approved = (d['approved'] as bool?) ?? true;
    final displayName = d['displayName'] as String?;
    final clinicId = d['clinicId'] as String?;
    DateTime createdAt = DateTime.now();
    final createdRaw = d['createdAt'];
    if (createdRaw is Timestamp) {
      createdAt = createdRaw.toDate();
    } else if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();
    }
    return AppUser(
      uid: (d['uid'] as String?) ?? doc.id,
      email: (d['email'] as String?) ?? '',
      displayName: displayName,
      clinicId: clinicId,
      role: roleStr == 'admin' ? UserRole.admin : UserRole.user,
      approved: approved,
      createdAt: createdAt,
    );
  }

  @override
  Future<AppUser?> currentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final prof = await _db.collection('users').doc(u.uid).get();
    if (!prof.exists) {
      await _ensureInitialRoleAndProfile(u);
      final refreshed = await _db.collection('users').doc(u.uid).get();
      return _userFrom(u, refreshed.data());
    }
    return _userFrom(u, prof.data());
  }

  @override
  Stream<AppUser?> authStateChanges() => _ctrl.stream;

  @override
  Future<AppUser> register({required String email, required String password, String? displayName}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    if (displayName != null && displayName.isNotEmpty) {
      await cred.user!.updateDisplayName(displayName);
    }
    await _ensureInitialRoleAndProfile(cred.user!);
    final doc = await _db.collection('users').doc(cred.user!.uid).get();
    final appUser = _userFrom(cred.user!, doc.data());
    _ctrl.add(appUser);
    return appUser;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final doc = await _db.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      await _ensureInitialRoleAndProfile(cred.user!);
    }
    final profile = await _db.collection('users').doc(cred.user!.uid).get();
    final appUser = _userFrom(cred.user!, profile.data());
    _ctrl.add(appUser);
    return appUser;
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _ctrl.add(null);
  }

  @override
  Future<void> setApproved(String uid, bool approved) async {
    await _db.collection('users').doc(uid).set({'approved': approved}, SetOptions(merge: true));
  }

  @override
  Future<List<AppUser>> listUsers({bool? approved}) async {
    Query<Map<String, dynamic>> q = _db.collection('users');
    if (approved != null) {
      q = q.where('approved', isEqualTo: approved);
    }
    final res = await q.get();
    return res.docs.map(_userFromProfileDoc).toList();
  }
}
