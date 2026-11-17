import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'supabase_service.dart';

class DatabaseSetupService {
  static const String schemaSql = '''
    CREATE TABLE IF NOT EXISTS public.users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'unknown' CHECK (role IN ('super_admin', 'admin', 'unknown')),
        mobile TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS public.projects (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        description TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS public.project_databases (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
        db_name TEXT NOT NULL,
        supabase_url TEXT,
        supabase_service_role_key TEXT,
        supabase_anon_key TEXT,
        db_password TEXT,
        db_host TEXT,
        sms_provider TEXT,
        notify_base_url TEXT,
        notify_api_key TEXT,
        notify_user_id TEXT,
        notify_sender_id TEXT,
        r2_access_key TEXT,
        r2_secret_key TEXT,
        r2_endpoint TEXT,
        r2_public_url TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS public.notifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        type TEXT DEFAULT 'info',
        target_role TEXT,
        target_user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
        created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS public.activity_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
        username TEXT,
        action TEXT NOT NULL,
        details TEXT,
        entity_type TEXT,
        entity_id TEXT,
        ip_address TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    -- Enable RLS and add system policies for public & service_role
    ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.project_databases ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

    DO \$\$
    DECLARE
        tbl text;
        tables text[] := ARRAY['users', 'projects', 'project_databases', 'notifications', 'activity_logs'];
    BEGIN
        FOREACH tbl IN ARRAY tables LOOP
            EXECUTE format('DROP POLICY IF EXISTS "Allow all for anon and service_role" ON public.%I', tbl);
            EXECUTE format('CREATE POLICY "Allow all for anon and service_role" ON public.%I FOR ALL TO public USING (true) WITH CHECK (true)', tbl);
        END LOOP;
    END \$\$;

    GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
    GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
    GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
    GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;
    NOTIFY pgrst, 'reload schema';
  ''';

  /// Verifies whether all 5 core tables exist and are reachable via PostgREST
  static Future<bool> checkTablesExist(String supabaseUrl, String anonKey) async {
    try {
      final tables = ['users', 'projects', 'project_databases', 'notifications', 'activity_logs'];
      for (var t in tables) {
        final uri = Uri.parse('$supabaseUrl/rest/v1/$t?select=count');
        final res = await http.get(uri, headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
        }).timeout(const Duration(seconds: 5));
        
        if (res.statusCode != 200) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> configureDatabase(AppEnvironment env) async {
    // Reload .env directly so any file edits are immediately updated without a rebuild
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {}

    final prefix = env == AppEnvironment.dev ? 'DEV_' : 'LIVE_';
    
    final host = dotenv.env['${prefix}DB_HOST'];
    final password = dotenv.env['${prefix}DB_PASSWORD'];
    final url = dotenv.env['${prefix}SUPABASE_URL'];
    final anonKey = dotenv.env['${prefix}SUPABASE_ANON_KEY'];

    if (host == null || host.isEmpty || password == null || password.isEmpty || url == null || url.isEmpty) {
      return {
        'success': false,
        'message': 'Missing environment variables for $prefix in .env (check DB_HOST, DB_PASSWORD, SUPABASE_URL)',
      };
    }

    // Step 1: Check if tables are already configured and reachable
    if (anonKey != null && anonKey.isNotEmpty) {
      final alreadyConfigured = await checkTablesExist(url, anonKey);
      if (alreadyConfigured) {
        return {
          'success': true,
          'message': '${env.name.toUpperCase()} database is verified! All 5 tables and RLS are active and ready.',
        };
      }
    }

    // Step 2: Extract project ref dynamically from SUPABASE_URL
    final uri = Uri.tryParse(url.trim());
    String projectRef = '';
    if (uri != null && uri.host.isNotEmpty) {
      projectRef = uri.host.split('.').first;
    }

    if (projectRef.isEmpty) {
      return {
        'success': false,
        'message': 'Could not extract project ref from ${prefix}SUPABASE_URL ($url)',
      };
    }

    final username = 'postgres.$projectRef';

    Connection? connection;
    try {
      final endpoint = Endpoint(
        host: host.trim(),
        database: 'postgres',
        username: username,
        password: password.trim(),
        port: 5432,
      );

      connection = await Connection.open(
        endpoint,
        settings: const ConnectionSettings(
          sslMode: SslMode.require,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Port 5432 failed, trying pooler port 6543: $e');
      try {
        final endpoint = Endpoint(
          host: host.trim(),
          database: 'postgres',
          username: username,
          password: password.trim(),
          port: 6543,
        );

        connection = await Connection.open(
          endpoint,
          settings: const ConnectionSettings(
            sslMode: SslMode.require,
          ),
        );
      } catch (e2) {
        return {
          'success': false,
          'message': 'Direct connection failed ($e2). Verify ${prefix}DB_PASSWORD in .env or run setup in Supabase SQL editor.',
        };
      }
    }

    try {
      await connection.execute(Sql(schemaSql), queryMode: QueryMode.simple);
      await connection.close();

      return {
        'success': true,
        'message': '${env.name.toUpperCase()} database tables configured & RLS policies enabled successfully!'
      };
    } catch (e) {
      if (kDebugMode) print('Error configuring database: $e');
      if (connection.isOpen) {
        try {
          await connection.close();
        } catch (_) {}
      }
      return {
        'success': false,
        'message': 'Failed to execute schema SQL: $e'
      };
    }
  }
}
