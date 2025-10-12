enum UserRole { admin, user }

class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? clinicId;
  final UserRole role;
  final bool approved;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.clinicId,
    this.role = UserRole.user,
    this.approved = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AppUser copyWith({String? displayName, String? clinicId, UserRole? role, bool? approved}) => AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        clinicId: clinicId ?? this.clinicId,
        role: role ?? this.role,
        approved: approved ?? this.approved,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'clinicId': clinicId,
        'role': role.name,
        'approved': approved,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        uid: j['uid'] as String,
        email: j['email'] as String,
        displayName: j['displayName'] as String?,
        clinicId: j['clinicId'] as String?,
        role: (j['role'] as String?) == 'admin' ? UserRole.admin : UserRole.user,
        approved: (j['approved'] as bool?) ?? false,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
