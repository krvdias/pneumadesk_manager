import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/password_utils.dart';
import '../../data/models/app_user.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<AppUser> _users = [];
  List<AppUser> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _roleFilter = 'all'; // 'all', 'super_admin', 'admin', 'unknown'

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final supabase = Provider.of<SupabaseService>(context, listen: false);

    try {
      final res = await supabase.client
          .from('users')
          .select()
          .order('created_at', ascending: false);

      final list = (res as List).map((e) => AppUser.fromMap(e)).toList();
      if (mounted) {
        setState(() {
          _users = list;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (user.mobile != null && user.mobile!.contains(_searchQuery));
        final matchesRole = _roleFilter == 'all' || user.role == _roleFilter;
        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  // Dialog: Create or Edit User
  void _showUserFormDialog({AppUser? user}) {
    final isEditing = user != null;
    final usernameController = TextEditingController(text: user?.username ?? '');
    final mobileController = TextEditingController(text: user?.mobile ?? '');
    final passwordController = TextEditingController();
    String selectedRole = user?.role ?? 'unknown';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(isEditing ? 'Edit User: ${user.username}' : 'Create New User'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      enabled: !isEditing, // Username immutable when editing
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mobileController,
                      decoration: const InputDecoration(labelText: 'Mobile Number'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      dropdownColor: const Color(0xFF1E293B),
                      items: const [
                        DropdownMenuItem(value: 'unknown', child: Text('Unknown (Pending)')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedRole = val);
                      },
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Initial Password'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final supabase = Provider.of<SupabaseService>(context, listen: false);
                    Navigator.pop(context);

                    if (isEditing) {
                      // Update user
                      await supabase.client.from('users').update({
                        'mobile': mobileController.text.trim(),
                        'role': selectedRole,
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', user.id);

                      await supabase.logActivity(
                        action: 'UPDATE_USER',
                        details: 'Updated user ${user.username} (Role: $selectedRole)',
                        entityType: 'user',
                        entityId: user.id,
                      );

                      await supabase.sendNotification(
                        title: 'User Updated',
                        message: 'User "${user.username}" profile was updated.',
                        type: 'info',
                        targetRole: 'admin',
                      );
                    } else {
                      // Create user
                      final pass = passwordController.text.trim();
                      if (pass.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password is required')),
                        );
                        return;
                      }

                      final hashed = PasswordUtils.hashPassword(pass);
                      final inserted = await supabase.client.from('users').insert({
                        'username': usernameController.text.trim(),
                        'password': hashed,
                        'role': selectedRole,
                        'mobile': mobileController.text.trim(),
                      }).select().single();

                      await supabase.logActivity(
                        action: 'CREATE_USER',
                        details: 'Created user ${usernameController.text.trim()} ($selectedRole)',
                        entityType: 'user',
                        entityId: inserted['id'],
                      );

                      await supabase.sendNotification(
                        title: 'New User Created',
                        message: 'Admin created user "${usernameController.text.trim()}"',
                        type: 'success',
                      );
                    }

                    _fetchUsers();
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog: Reset Password
  void _showChangePasswordDialog(AppUser user) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Reset Password: ${user.username}'),
          content: SizedBox(
            width: 360,
            child: TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPass = passwordController.text.trim();
                if (newPass.isEmpty) return;

                final supabase = Provider.of<SupabaseService>(context, listen: false);
                Navigator.pop(dialogContext);

                final hashed = PasswordUtils.hashPassword(newPass);
                await supabase.client
                    .from('users')
                    .update({'password': hashed})
                    .eq('id', user.id);

                await supabase.logActivity(
                  action: 'RESET_PASSWORD',
                  details: 'Reset password for user ${user.username}',
                  entityType: 'user',
                  entityId: user.id,
                );

                await supabase.sendNotification(
                  title: 'Password Reset',
                  message: 'Password for your account was reset by administrator.',
                  type: 'warning',
                  targetUserId: user.id,
                );

                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Password updated for ${user.username}')),
                );
              },
              child: const Text('Update Password'),
            ),
          ],
        );
      },
    );
  }

  // Delete User with 2-step confirmation
  void _confirmDeleteUser(AppUser user) {
    showDialog(
      context: context,
      builder: (firstContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Delete User - Step 1 of 2'),
          content: Text('Are you sure you want to delete user "${user.username}" (${user.role.toUpperCase()})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(firstContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
              onPressed: () {
                Navigator.pop(firstContext);
                _confirmDeleteUserSecondStep(user);
              },
              child: const Text('Proceed to Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteUserSecondStep(AppUser user) {
    showDialog(
      context: context,
      builder: (secondContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Text('Final Confirmation - Step 2 of 2'),
            ],
          ),
          content: Text(
            'WARNING: This action is permanent and cannot be undone.\n\nDo you really want to permanently delete user "${user.username}" from the database?',
            style: const TextStyle(color: Color(0xFFF8FAFC)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(secondContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final supabase = Provider.of<SupabaseService>(context, listen: false);
                Navigator.pop(secondContext);

                await supabase.client.from('users').delete().eq('id', user.id);

                await supabase.logActivity(
                  action: 'DELETE_USER',
                  details: 'Permanently deleted user ${user.username} (${user.role})',
                  entityType: 'user',
                  entityId: user.id,
                );

                await supabase.sendNotification(
                  title: 'User Deleted',
                  message: 'User "${user.username}" was deleted by Super Administrator.',
                  type: 'error',
                );

                _fetchUsers();
              },
              child: const Text('Yes, Permanently Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Provider.of<SupabaseService>(context);
    final currentUser = supabase.currentUser;

    // User deletion permissions: Super Admins can delete users, Admins cannot delete.
    final canDelete = currentUser?.isSuperAdmin == true;
    final canEditOrAssign = currentUser?.isSuperAdmin == true || currentUser?.isAdmin == true;
    final canCreate = currentUser?.isSuperAdmin == true || currentUser?.isAdmin == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Actions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('User Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Manage roles, approvals, credentials and accounts (${_filteredUsers.length} total)',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _fetchUsers,
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: 8),
                    if (canCreate)
                      ElevatedButton.icon(
                        onPressed: () => _showUserFormDialog(),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add User'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search and Filters
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by username or mobile number...',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _roleFilter,
                        dropdownColor: const Color(0xFF1E293B),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Roles')),
                          DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'unknown', child: Text('Unknown (Pending)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _roleFilter = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // User Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.person_off_outlined, size: 48, color: Color(0xFF64748B)),
                              SizedBox(height: 12),
                              Text('No users found', style: TextStyle(color: Color(0xFF94A3B8))),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.separated(
                              itemCount: _filteredUsers.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF334155)),
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                final isCurrent = user.id == currentUser?.id;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
                                    child: Icon(
                                      user.isSuperAdmin
                                          ? Icons.military_tech
                                          : user.isAdmin
                                              ? Icons.security
                                              : Icons.help_outline,
                                      color: _getRoleColor(user.role),
                                      size: 20,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        user.username,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('You', style: TextStyle(fontSize: 10, color: Colors.green)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Text(
                                        user.mobile != null && user.mobile!.isNotEmpty
                                            ? 'Mobile: ${user.mobile}'
                                            : 'No mobile attached',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                      ),
                                      const SizedBox(width: 14),
                                      if (user.createdAt != null)
                                        Text(
                                          'Joined: ${DateFormat.yMMMd().format(user.createdAt!)}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Role badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(user.role).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: _getRoleColor(user.role)),
                                        ),
                                        child: Text(
                                          user.role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getRoleColor(user.role),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Actions
                                      if (canEditOrAssign) ...[
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          tooltip: 'Edit / Assign Role',
                                          onPressed: () => _showUserFormDialog(user: user),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.password_outlined, size: 18),
                                          tooltip: 'Reset Password',
                                          onPressed: () => _showChangePasswordDialog(user),
                                        ),
                                      ],

                                      if (canDelete) ...[
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                          tooltip: 'Delete User (Super Admin Only)',
                                          onPressed: isCurrent ? null : () => _confirmDeleteUser(user),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
        return const Color(0xFFA855F7); // Purple
      case 'admin':
        return const Color(0xFF3B82F6); // Blue
      default:
        return const Color(0xFFEAB308); // Yellow/Amber for unknown
    }
  }
}
