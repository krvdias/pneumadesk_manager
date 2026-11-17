import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/app_user.dart';
import '../utils/password_utils.dart';

enum AppEnvironment { dev, live }

class SupabaseService with ChangeNotifier {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  AppEnvironment _currentEnv = AppEnvironment.dev;
  SupabaseClient? _client;
  AppUser? _currentUser;

  AppEnvironment get currentEnv => _currentEnv;
  SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase client is not initialized');
    }
    return _client!;
  }
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  String get currentUrl {
    final prefix = _currentEnv == AppEnvironment.dev ? 'DEV_' : 'LIVE_';
    return dotenv.env['${prefix}SUPABASE_URL'] ?? '';
  }

  String get currentHost {
    final prefix = _currentEnv == AppEnvironment.dev ? 'DEV_' : 'LIVE_';
    return dotenv.env['${prefix}DB_HOST'] ?? '';
  }

  String get currentPort {
    return '5432 / 6543';
  }

  Future<void> initEnvironment(AppEnvironment env) async {
    _currentEnv = env;
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    final prefix = env == AppEnvironment.dev ? 'DEV_' : 'LIVE_';
    
    final url = dotenv.env['${prefix}SUPABASE_URL'];
    final anonKey = dotenv.env['${prefix}SUPABASE_ANON_KEY'];

    if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
      throw Exception('Missing environment variables: ${prefix}SUPABASE_URL or ${prefix}SUPABASE_ANON_KEY in .env');
    }

    if (kDebugMode) {
      print('Connecting to $env environment: $url');
    }

    // Always create a dedicated client for the active environment URL and Key
    _client = SupabaseClient(url, anonKey);
    notifyListeners();
  }

  // Auth Operations
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? mobile,
  }) async {
    try {
      // 1. Check if username already exists
      final existing = await client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (existing != null) {
        return {'success': false, 'message': 'Username already taken'};
      }

      // 2. Count existing users
      final userCountResponse = await client
          .from('users')
          .select('id');
      final int userCount = (userCountResponse as List).length;

      // First registered user is super_admin, otherwise unknown
      final role = (userCount == 0) ? 'super_admin' : 'unknown';
      final hashedPassword = PasswordUtils.hashPassword(password);

      final insertResponse = await client.from('users').insert({
        'username': username,
        'password': hashedPassword,
        'role': role,
        'mobile': mobile,
      }).select().single();

      final newUser = AppUser.fromMap(insertResponse);

      // Log activity
      await logActivity(
        action: 'USER_REGISTERED',
        details: 'User ${newUser.username} registered with role $role',
        entityType: 'user',
        entityId: newUser.id,
        user: newUser,
      );

      // Notify Super Admins
      await sendNotification(
        title: 'New User Registered',
        message: 'New user "${newUser.username}" registered (Role: $role)',
        type: 'info',
        targetRole: 'super_admin',
      );

      return {
        'success': true, 
        'user': newUser,
        'isFirst': userCount == 0,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required AppEnvironment env,
  }) async {
    try {
      await initEnvironment(env);

      final userData = await client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (userData == null) {
        return {'success': false, 'message': 'User not found'};
      }

      final hashedPassword = PasswordUtils.hashPassword(password);
      if (userData['password'] != hashedPassword) {
        return {'success': false, 'message': 'Invalid password'};
      }

      final user = AppUser.fromMap(userData);

      if (user.isUnknown) {
        return {
          'success': false, 
          'message': 'Account pending approval. Please contact an Administrator.'
        };
      }

      _currentUser = user;
      notifyListeners();

      await logActivity(
        action: 'LOGIN',
        details: 'User logged in to ${env.name.toUpperCase()} environment',
        entityType: 'auth',
      );

      return {'success': true, 'user': user};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  void logout() {
    if (_currentUser != null) {
      logActivity(
        action: 'LOGOUT',
        details: 'User logged out',
        entityType: 'auth',
      );
    }
    _currentUser = null;
    notifyListeners();
  }

  // Activity Log
  Future<void> logActivity({
    required String action,
    String? details,
    String? entityType,
    String? entityId,
    AppUser? user,
  }) async {
    try {
      final actor = user ?? _currentUser;
      await client.from('activity_logs').insert({
        'user_id': actor?.id,
        'username': actor?.username ?? 'System',
        'action': action,
        'details': details,
        'entity_type': entityType,
        'entity_id': entityId,
      });
    } catch (e) {
      if (kDebugMode) print('Failed to log activity: $e');
    }
  }

  // Notifications
  Future<void> sendNotification({
    required String title,
    required String message,
    String type = 'info',
    String? targetRole,
    String? targetUserId,
  }) async {
    try {
      await client.from('notifications').insert({
        'title': title,
        'message': message,
        'type': type,
        'target_role': targetRole,
        'target_user_id': targetUserId,
        'created_by': _currentUser?.id,
      });
    } catch (e) {
      if (kDebugMode) print('Failed to send notification: $e');
    }
  }

  void updateCurrentUser(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }
}
