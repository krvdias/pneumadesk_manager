class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? targetRole;
  final String? targetUserId;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'info',
    this.targetRole,
    this.targetUserId,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? 'info',
      targetRole: map['target_role']?.toString(),
      targetUserId: map['target_user_id']?.toString(),
      isRead: map['is_read'] == true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }
}
