import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToProjects;
  final VoidCallback onNavigateToUsers;

  const DashboardScreen({
    super.key,
    required this.onNavigateToProjects,
    required this.onNavigateToUsers,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _projectCount = 0;
  int _databaseCount = 0;
  int _userCount = 0;
  int _adminCount = 0;
  int _unknownUserCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final supabase = Provider.of<SupabaseService>(context, listen: false);

    try {
      final projectsRes = await supabase.client.from('projects').select('id');
      final databasesRes = await supabase.client.from('project_databases').select('id');
      final usersRes = await supabase.client.from('users').select('id, role');

      final users = usersRes as List;
      int admins = 0;
      int unknowns = 0;

      for (var u in users) {
        final role = u['role']?.toString();
        if (role == 'admin' || role == 'super_admin') admins++;
        if (role == 'unknown') unknowns++;
      }

      if (mounted) {
        setState(() {
          _projectCount = (projectsRes as List).length;
          _databaseCount = (databasesRes as List).length;
          _userCount = users.length;
          _adminCount = admins;
          _unknownUserCount = unknowns;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Provider.of<SupabaseService>(context);
    final env = supabase.currentEnv;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Welcome, ${supabase.currentUser?.username ?? "User"}',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: supabase.currentUser?.isSuperAdmin == true
                                      ? Colors.purple.withValues(alpha: 0.2)
                                      : Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: supabase.currentUser?.isSuperAdmin == true
                                        ? Colors.purpleAccent
                                        : Colors.blueAccent,
                                  ),
                                ),
                                child: Text(
                                  supabase.currentUser?.role.toUpperCase() ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: supabase.currentUser?.isSuperAdmin == true
                                        ? Colors.purpleAccent
                                        : Colors.blueAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connected to ${env == AppEnvironment.dev ? "Development" : "Live Production"} Database Environment',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _loadStats,
                        tooltip: 'Refresh Stats',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Stat Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - 48) / 3;
                      return Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          _buildStatCard(
                            title: 'Total Projects',
                            value: '$_projectCount',
                            subtitle: 'Active applications managed',
                            icon: Icons.folder_special_rounded,
                            iconColor: const Color(0xFF6366F1),
                            width: cardWidth.clamp(260.0, 400.0),
                            onTap: widget.onNavigateToProjects,
                          ),
                          _buildStatCard(
                            title: 'Total Databases',
                            value: '$_databaseCount',
                            subtitle: 'Supabase client pools linked',
                            icon: Icons.storage_rounded,
                            iconColor: const Color(0xFF06B6D4),
                            width: cardWidth.clamp(260.0, 400.0),
                            onTap: widget.onNavigateToProjects,
                          ),
                          _buildStatCard(
                            title: 'System Users',
                            value: '$_userCount',
                            subtitle: '$_adminCount Admins, $_unknownUserCount Pending',
                            icon: Icons.people_alt_rounded,
                            iconColor: const Color(0xFF10B981),
                            width: cardWidth.clamp(260.0, 400.0),
                            onTap: widget.onNavigateToUsers,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Quick Actions & System Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Environment Info Card
                      Expanded(
                        flex: 3,
                        child: Container(
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
                                children: [
                                  Icon(
                                    env == AppEnvironment.dev ? Icons.bug_report : Icons.cloud_done,
                                    color: env == AppEnvironment.dev
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${env.name.toUpperCase()} Cluster Info',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              const Divider(height: 24, color: Color(0xFF334155)),
                              _buildInfoRow('Cluster Environment', env == AppEnvironment.dev ? 'Development (Dev Mode)' : 'Production (Live Mode)'),
                              const SizedBox(height: 10),
                              _buildInfoRow('Role', supabase.currentUser?.role.toUpperCase() ?? 'UNKNOWN'),
                              const SizedBox(height: 10),
                              _buildInfoRow('Account State', 'Active & Authenticated'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Quick Shortcuts
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick Management',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Divider(height: 24, color: Color(0xFF334155)),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFF334155),
                                  child: Icon(Icons.add, color: Colors.white),
                                ),
                                title: const Text('Add New Project'),
                                subtitle: const Text('Register project & link databases'),
                                trailing: const Icon(Icons.chevron_right, size: 20),
                                onTap: widget.onNavigateToProjects,
                              ),
                              if (_unknownUserCount > 0 &&
                                  (supabase.currentUser?.isAdmin == true ||
                                      supabase.currentUser?.isSuperAdmin == true)) ...[
                                const Divider(height: 16, color: Color(0xFF334155)),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.amber.withValues(alpha: 0.2),
                                    child: const Icon(Icons.person_add_alt, color: Colors.amber),
                                  ),
                                  title: Text('$_unknownUserCount Pending Approvals'),
                                  subtitle: const Text('Assign roles to new users'),
                                  trailing: const Icon(Icons.chevron_right, size: 20),
                                  onTap: widget.onNavigateToUsers,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double width,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
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
                Text(
                  title,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
