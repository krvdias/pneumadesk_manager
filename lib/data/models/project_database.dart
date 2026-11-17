class ProjectDatabase {
  final String id;
  final String projectId;
  final String dbName;
  final String? supabaseUrl;
  final String? supabaseServiceRoleKey;
  final String? supabaseAnonKey;
  final String? dbPassword;
  final String? dbHost;
  final String? smsProvider;
  final String? notifyBaseUrl;
  final String? notifyApiKey;
  final String? notifyUserId;
  final String? notifySenderId;
  final String? r2AccessKey;
  final String? r2SecretKey;
  final String? r2Endpoint;
  final String? r2PublicUrl;
  final DateTime? createdAt;

  ProjectDatabase({
    required this.id,
    required this.projectId,
    required this.dbName,
    this.supabaseUrl,
    this.supabaseServiceRoleKey,
    this.supabaseAnonKey,
    this.dbPassword,
    this.dbHost,
    this.smsProvider,
    this.notifyBaseUrl,
    this.notifyApiKey,
    this.notifyUserId,
    this.notifySenderId,
    this.r2AccessKey,
    this.r2SecretKey,
    this.r2Endpoint,
    this.r2PublicUrl,
    this.createdAt,
  });

  factory ProjectDatabase.fromMap(Map<String, dynamic> map) {
    return ProjectDatabase(
      id: map['id']?.toString() ?? '',
      projectId: map['project_id']?.toString() ?? '',
      dbName: map['db_name']?.toString() ?? '',
      supabaseUrl: map['supabase_url']?.toString(),
      supabaseServiceRoleKey: map['supabase_service_role_key']?.toString(),
      supabaseAnonKey: map['supabase_anon_key']?.toString(),
      dbPassword: map['db_password']?.toString(),
      dbHost: map['db_host']?.toString(),
      smsProvider: map['sms_provider']?.toString(),
      notifyBaseUrl: map['notify_base_url']?.toString(),
      notifyApiKey: map['notify_api_key']?.toString(),
      notifyUserId: map['notify_user_id']?.toString(),
      notifySenderId: map['notify_sender_id']?.toString(),
      r2AccessKey: map['r2_access_key']?.toString(),
      r2SecretKey: map['r2_secret_key']?.toString(),
      r2Endpoint: map['r2_endpoint']?.toString(),
      r2PublicUrl: map['r2_public_url']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'project_id': projectId,
      'db_name': dbName,
      'supabase_url': supabaseUrl,
      'supabase_service_role_key': supabaseServiceRoleKey,
      'supabase_anon_key': supabaseAnonKey,
      'db_password': dbPassword,
      'db_host': dbHost,
      'sms_provider': smsProvider,
      'notify_base_url': notifyBaseUrl,
      'notify_api_key': notifyApiKey,
      'notify_user_id': notifyUserId,
      'notify_sender_id': notifySenderId,
      'r2_access_key': r2AccessKey,
      'r2_secret_key': r2SecretKey,
      'r2_endpoint': r2Endpoint,
      'r2_public_url': r2PublicUrl,
    };
  }
}
