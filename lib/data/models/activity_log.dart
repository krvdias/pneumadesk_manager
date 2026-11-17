class ActivityLog {
  final String id;
  final String? userId;
  final String? username;
  final String action;
  final String? details;
  final String? entityType;
  final String? entityId;
  final DateTime? createdAt;

  ActivityLog({
    required this.id,
    this.userId,
    this.username,
    required this.action,
    this.details,
    this.entityType,
    this.entityId,
    this.createdAt,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString(),
      username: map['username']?.toString(),
      action: map['action']?.toString() ?? '',
      details: map['details']?.toString(),
      entityType: map['entity_type']?.toString(),
      entityId: map['entity_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }
}
