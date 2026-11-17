class AppUser {
  final String id;
  final String username;
  final String role; // 'super_admin', 'admin', 'unknown'
  final String? mobile;
  final DateTime? createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.mobile,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      role: map['role']?.toString() ?? 'unknown',
      mobile: map['mobile']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'mobile': mobile,
    };
  }

  bool get isSuperAdmin => role == 'super_admin';
  bool get isAdmin => role == 'admin';
  bool get isUnknown => role == 'unknown';
}
