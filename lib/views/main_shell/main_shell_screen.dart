import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/supabase_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../users/user_management_screen.dart';
import '../notifications/notifications_screen.dart';
import '../projects/projects_screen.dart';
import '../activity_log/activity_log_screen.dart';
import '../profile/user_profile_screen.dart';
import '../common/static_page_dialog.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final supabase = Provider.of<SupabaseService>(context);
    final user = supabase.currentUser;
    final env = supabase.currentEnv;

    final List<Widget> pages = [
      DashboardScreen(
        onNavigateToProjects: () => setState(() => _selectedIndex = 3),
        onNavigateToUsers: () => setState(() => _selectedIndex = 1),
      ),
      const UserManagementScreen(),
      const NotificationsScreen(),
      const ProjectsScreen(),
      const ActivityLogScreen(),
      const UserProfileScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(right: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            child: Column(
              children: [
                // Brand Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.dns_rounded, size: 22, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PnumaDesk',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Manager Console',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Environment Indicator Chip
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: env == AppEnvironment.dev ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${env.name.toUpperCase()} MODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: env == AppEnvironment.dev ? const Color(0xFF818CF8) : const Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Nav items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined, Icons.dashboard),
                      _buildNavItem(1, 'User Management', Icons.people_outline, Icons.people),
                      _buildNavItem(2, 'Notifications', Icons.notifications_none, Icons.notifications),
                      _buildNavItem(3, 'Projects', Icons.folder_open, Icons.folder),
                      _buildNavItem(4, 'Activity Log', Icons.history, Icons.history_toggle_off),
                      _buildNavItem(5, 'User Profile', Icons.person_outline, Icons.person),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFF334155)),
                      const SizedBox(height: 12),

                      // Footer links
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => StaticPageDialog.showPrivacyPolicy(context),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text('Privacy Policy', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                            ),
                            InkWell(
                              onTap: () => StaticPageDialog.showTermsAndConditions(context),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text('Terms & Conditions', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                            ),
                            InkWell(
                              onTap: () => StaticPageDialog.showContactUs(context),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text('Contact Us', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'v1.0.0 (Production Release)',
                              style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom User Profile info & Logout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    border: Border(top: BorderSide(color: Color(0xFF334155))),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        child: const Icon(Icons.person, size: 18, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user?.username ?? 'User',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              user?.role.toUpperCase() ?? '',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                        tooltip: 'Sign Out',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: Row(
                                children: const [
                                  Icon(Icons.logout, color: Colors.amber, size: 22),
                                  SizedBox(width: 8),
                                  Text('Confirm Logout'),
                                ],
                              ),
                              content: const Text('Are you sure you want to log out of your session?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () {
                                    Navigator.pop(dialogCtx);
                                    supabase.logout();
                                  },
                                  child: const Text('Log Out'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Screen Content Area
          Expanded(
            child: Container(
              color: const Color(0xFF0F172A),
              child: pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, IconData activeIcon) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }
}
