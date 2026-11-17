import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/password_utils.dart';
import '../../data/models/app_user.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _mobileController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  bool _isExporting = false;
  bool _isImporting = false;
  List<String> _projectNames = [];

  @override
  void initState() {
    super.initState();
    final user = Provider.of<SupabaseService>(context, listen: false).currentUser;
    _mobileController.text = user?.mobile ?? '';
    _loadProjectNames();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectNames() async {
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    try {
      final res = await supabase.client.from('projects').select('name');
      if (mounted) {
        setState(() {
          _projectNames = (res as List).map((p) => p['name'].toString()).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _updateMobile() async {
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    final user = supabase.currentUser;
    if (user == null) return;

    setState(() => _isSavingProfile = true);
    final newMobile = _mobileController.text.trim();

    try {
      await supabase.client
          .from('users')
          .update({'mobile': newMobile, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', user.id);

      final updatedUser = AppUser(
        id: user.id,
        username: user.username,
        role: user.role,
        mobile: newMobile,
        createdAt: user.createdAt,
      );
      supabase.updateCurrentUser(updatedUser);

      await supabase.logActivity(
        action: 'UPDATE_PROFILE',
        details: 'User updated their mobile number to $newMobile',
        entityType: 'user',
        entityId: user.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mobile number updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating mobile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    final user = supabase.currentUser;
    if (user == null) return;

    final currPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confPass = _confirmPasswordController.text.trim();

    if (currPass.isEmpty || newPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields'), backgroundColor: Colors.amber),
      );
      return;
    }

    if (newPass != confPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final dbUser = await supabase.client
          .from('users')
          .select('password')
          .eq('id', user.id)
          .single();

      final currHashed = PasswordUtils.hashPassword(currPass);
      if (dbUser['password'] != currHashed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Current password is incorrect'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final newHashed = PasswordUtils.hashPassword(newPass);
      await supabase.client
          .from('users')
          .update({'password': newHashed, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', user.id);

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      await supabase.logActivity(
        action: 'CHANGE_PASSWORD',
        details: 'User updated their personal password',
        entityType: 'user',
        entityId: user.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update password: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  // Full System Backup data to JSON file
  Future<void> _backupData() async {
    setState(() => _isExporting = true);
    final supabase = Provider.of<SupabaseService>(context, listen: false);

    try {
      final users = await supabase.client.from('users').select();
      final projects = await supabase.client.from('projects').select();
      final databases = await supabase.client.from('project_databases').select();
      final notifications = await supabase.client.from('notifications').select();
      final activityLogs = await supabase.client.from('activity_logs').select();

      final backup = {
        'export_date': DateTime.now().toIso8601String(),
        'environment': supabase.currentEnv.name,
        'system_version': '1.0.0',
        'users': users,
        'projects': projects,
        'project_databases': databases,
        'notifications': notifications,
        'activity_logs': activityLogs,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      final bytes = utf8.encode(jsonStr);

      final saveResult = await FilePicker.saveFile(
        dialogTitle: 'Select location to save complete system backup JSON',
        fileName: 'PnumaDesk_FullBackup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
        bytes: bytes,
      );

      if (saveResult != null) {
        await supabase.logActivity(
          action: 'FULL_SYSTEM_BACKUP',
          details: 'Complete system backup exported successfully: $saveResult',
          entityType: 'backup',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Complete system backup saved successfully! ($saveResult)'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // Restore full system data from JSON file
  Future<void> _restoreData() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select PnumaDesk backup JSON file',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result.isEmpty || result.first.path == null) return;

    if (!mounted) return;
    setState(() => _isImporting = true);
    final supabase = Provider.of<SupabaseService>(context, listen: false);

    try {
      final file = File(result.first.path!);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      int usersRestored = 0;
      int projectsRestored = 0;
      int databasesRestored = 0;
      int notificationsRestored = 0;
      int logsRestored = 0;

      // 1. Users
      if (data['users'] != null) {
        for (var u in (data['users'] as List)) {
          final uMap = Map<String, dynamic>.from(u);
          await supabase.client.from('users').upsert(uMap);
          usersRestored++;
        }
      }

      // 2. Projects
      if (data['projects'] != null) {
        for (var p in (data['projects'] as List)) {
          final pMap = Map<String, dynamic>.from(p);
          await supabase.client.from('projects').upsert(pMap);
          projectsRestored++;
        }
      }

      // 3. Project Databases
      if (data['project_databases'] != null) {
        for (var db in (data['project_databases'] as List)) {
          final dbMap = Map<String, dynamic>.from(db);
          await supabase.client.from('project_databases').upsert(dbMap);
          databasesRestored++;
        }
      }

      // 4. Notifications
      if (data['notifications'] != null) {
        for (var n in (data['notifications'] as List)) {
          final nMap = Map<String, dynamic>.from(n);
          await supabase.client.from('notifications').upsert(nMap);
          notificationsRestored++;
        }
      }

      // 5. Activity Logs
      if (data['activity_logs'] != null) {
        for (var l in (data['activity_logs'] as List)) {
          final lMap = Map<String, dynamic>.from(l);
          await supabase.client.from('activity_logs').upsert(lMap);
          logsRestored++;
        }
      }

      await supabase.logActivity(
        action: 'RESTORE_DATA',
        details: 'Full system restored: $usersRestored users, $projectsRestored projects, $databasesRestored databases, $notificationsRestored notifications, $logsRestored activity logs',
        entityType: 'backup',
      );

      await _loadProjectNames();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('System restored successfully! ($usersRestored users, $projectsRestored projects, $databasesRestored DBs, $notificationsRestored notes, $logsRestored logs)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Provider.of<SupabaseService>(context);
    final user = supabase.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text('User Profile & Configuration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Manage your credentials, mobile phone, associated projects, and system backup/restore',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile & Credentials Column
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Profile Info & Mobile Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Account Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const Divider(height: 24, color: Color(0xFF334155)),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                  child: const Icon(Icons.person, size: 32, color: Color(0xFF6366F1)),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.username ?? 'User',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Role: ${user?.role.toUpperCase()}',
                                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _mobileController,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                                prefixIcon: Icon(Icons.phone, size: 20),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: _isSavingProfile ? null : _updateMobile,
                                child: _isSavingProfile
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Update Mobile Number'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Change Password Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Security & Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const Divider(height: 24, color: Color(0xFF334155)),
                            TextField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Current Password',
                                prefixIcon: Icon(Icons.lock_outline, size: 20),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'New Password',
                                prefixIcon: Icon(Icons.lock_reset, size: 20),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm New Password',
                                prefixIcon: Icon(Icons.lock_reset, size: 20),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: _isChangingPassword ? null : _changePassword,
                                child: _isChangingPassword
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Change Password'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Projects & Backup / Restore Column
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // Active Projects List Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Active Projects', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('${_projectNames.length} Total', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ],
                            ),
                            const Divider(height: 24, color: Color(0xFF334155)),
                            if (_projectNames.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No projects registered yet.', style: TextStyle(color: Color(0xFF94A3B8))),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _projectNames.map((p) {
                                  return Chip(
                                    avatar: const Icon(Icons.folder, size: 16, color: Color(0xFF6366F1)),
                                    label: Text(p),
                                    backgroundColor: const Color(0xFF0F172A),
                                    side: const BorderSide(color: Color(0xFF334155)),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Backup & Restore Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Backup & Restore Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const Divider(height: 24, color: Color(0xFF334155)),
                            const Text(
                              'Safely export all projects and database configurations to a standalone JSON file, or restore from a previous backup file.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isExporting ? null : _backupData,
                                    icon: const Icon(Icons.download, size: 18),
                                    label: Text(_isExporting ? 'Exporting...' : 'Export Backup'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF06B6D4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _isImporting ? null : _restoreData,
                                    icon: const Icon(Icons.upload, size: 18),
                                    label: Text(_isImporting ? 'Restoring...' : 'Restore File'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
