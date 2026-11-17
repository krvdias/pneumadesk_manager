import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/database_setup_service.dart';

class DatabaseConfigurationDialog extends StatefulWidget {
  final AppEnvironment initialEnv;
  final ValueChanged<AppEnvironment>? onEnvironmentChanged;

  const DatabaseConfigurationDialog({
    super.key,
    required this.initialEnv,
    this.onEnvironmentChanged,
  });

  @override
  State<DatabaseConfigurationDialog> createState() => _DatabaseConfigurationDialogState();
}

class _DatabaseConfigurationDialogState extends State<DatabaseConfigurationDialog> {
  late AppEnvironment _selectedEnv;
  bool _isConfiguring = false;
  bool _isRestoring = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _selectedEnv = widget.initialEnv;
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    try {
      await dotenv.load(fileName: '.env');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _handleRestoreDatabase() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select PnumaDesk backup JSON file to restore',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result.isEmpty || result.first.path == null) return;

    setState(() {
      _isRestoring = true;
      _statusMessage = null;
    });

    try {
      final file = File(result.first.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      final prefix = _selectedEnv == AppEnvironment.dev ? 'DEV_' : 'LIVE_';
      final url = dotenv.env['${prefix}SUPABASE_URL'];
      final anonKey = dotenv.env['${prefix}SUPABASE_ANON_KEY'];

      if (url == null || anonKey == null) {
        throw Exception('Supabase credentials not found for ${_selectedEnv.name.toUpperCase()} in .env');
      }

      final client = SupabaseClient(url, anonKey);

      int usersRestored = 0;
      int projectsRestored = 0;
      int databasesRestored = 0;
      int notificationsRestored = 0;
      int logsRestored = 0;

      // 1. Users
      if (data['users'] != null) {
        for (var u in (data['users'] as List)) {
          final uMap = Map<String, dynamic>.from(u);
          await client.from('users').upsert(uMap);
          usersRestored++;
        }
      }

      // 2. Projects
      if (data['projects'] != null) {
        for (var p in (data['projects'] as List)) {
          final pMap = Map<String, dynamic>.from(p);
          await client.from('projects').upsert(pMap);
          projectsRestored++;
        }
      }

      // 3. Project Databases
      if (data['project_databases'] != null) {
        for (var db in (data['project_databases'] as List)) {
          final dbMap = Map<String, dynamic>.from(db);
          await client.from('project_databases').upsert(dbMap);
          databasesRestored++;
        }
      }

      // 4. Notifications
      if (data['notifications'] != null) {
        for (var n in (data['notifications'] as List)) {
          final nMap = Map<String, dynamic>.from(n);
          await client.from('notifications').upsert(nMap);
          notificationsRestored++;
        }
      }

      // 5. Activity Logs
      if (data['activity_logs'] != null) {
        for (var l in (data['activity_logs'] as List)) {
          final lMap = Map<String, dynamic>.from(l);
          await client.from('activity_logs').upsert(lMap);
          logsRestored++;
        }
      }

      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _isSuccess = true;
        _statusMessage = 'Full system backup restored into ${_selectedEnv.name.toUpperCase()}!\n'
            '($usersRestored users, $projectsRestored projects, $databasesRestored DBs, $notificationsRestored notifications, $logsRestored activity logs)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
        _isSuccess = false;
        _statusMessage = 'Restore failed: $e';
      });
    }
  }

  Future<void> _handleConfigure() async {
    setState(() {
      _isConfiguring = true;
      _statusMessage = null;
    });

    final res = await DatabaseSetupService.configureDatabase(_selectedEnv);

    if (!mounted) return;
    setState(() {
      _isConfiguring = false;
      _isSuccess = res['success'] == true;
      _statusMessage = res['message'];
    });

    if (res['success'] == true) {
      widget.onEnvironmentChanged?.call(_selectedEnv);
      final supabase = Provider.of<SupabaseService>(context, listen: false);
      supabase.initEnvironment(_selectedEnv);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155), width: 1),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_suggest, color: Color(0xFF6366F1), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Database Configuration',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Initialize or repair core system tables & RLS',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFF334155)),

            // Environment Switcher
            const Text(
              'Target Environment',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedEnv = AppEnvironment.dev;
                        _statusMessage = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedEnv == AppEnvironment.dev
                              ? const Color(0xFF6366F1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Development',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _selectedEnv == AppEnvironment.dev
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedEnv = AppEnvironment.live;
                        _statusMessage = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedEnv == AppEnvironment.live
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Live Production',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _selectedEnv == AppEnvironment.live
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Status message
            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccess ? Colors.green : Colors.redAccent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _isSuccess ? Colors.green : Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isSuccess ? Colors.green : Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'Clicking "Run Setup" will ensure tables (users, projects, project_databases, notifications, activity_logs) are created and verified with RLS system policies.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                if (_isSuccess) ...[
                  OutlinedButton.icon(
                    onPressed: (_isConfiguring || _isRestoring) ? null : _handleRestoreDatabase,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF06B6D4),
                      side: const BorderSide(color: Color(0xFF06B6D4), width: 1),
                    ),
                    icon: _isRestoring
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
                          )
                        : const Icon(Icons.restore_page_outlined, size: 16),
                    label: Text(_isRestoring ? 'Restoring...' : 'Restore Database'),
                  ),
                ],
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: (_isConfiguring || _isRestoring) ? null : _handleConfigure,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedEnv == AppEnvironment.live
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6366F1),
                  ),
                  icon: _isConfiguring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(_isConfiguring ? 'Configuring...' : 'Run Setup'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
