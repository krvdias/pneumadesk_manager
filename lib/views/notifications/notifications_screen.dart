import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/app_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    final user = supabase.currentUser;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Fetch notifications:
      // Must be targetRole == null OR targetRole == user.role
      // AND targetUserId == null OR targetUserId == user.id
      final res = await supabase.client
          .from('notifications')
          .select()
          .order('created_at', ascending: false);

      final list = (res as List).map((e) => AppNotification.fromMap(e)).where((n) {
        // User-wise and role-wise filtering
        final matchesRole = n.targetRole == null || n.targetRole == user.role;
        final matchesUser = n.targetUserId == null || n.targetUserId == user.id;
        return matchesRole && matchesUser;
      }).toList();

      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    for (var n in _notifications) {
      if (!n.isRead) {
        await supabase.client
            .from('notifications')
            .update({'is_read': true})
            .eq('id', n.id);
      }
    }
    _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('System Notifications', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      'Filtered according to your user identity and assigned role permissions',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _fetchNotifications,
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _markAllAsRead,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Mark all as read'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Notifications List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.notifications_none, size: 48, color: Color(0xFF64748B)),
                              SizedBox(height: 12),
                              Text('No notifications for your role', style: TextStyle(color: Color(0xFF94A3B8))),
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
                              itemCount: _notifications.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF334155)),
                              itemBuilder: (context, index) {
                                final n = _notifications[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  leading: CircleAvatar(
                                    backgroundColor: _getTypeColor(n.type).withValues(alpha: 0.15),
                                    child: Icon(_getTypeIcon(n.type), color: _getTypeColor(n.type), size: 20),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        n.title,
                                        style: TextStyle(
                                          fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (!n.isRead) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF6366F1),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (n.createdAt != null)
                                        Text(
                                          DateFormat.yMMMd().add_jm().format(n.createdAt!),
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      n.message,
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.check, size: 18),
                                    tooltip: 'Mark read',
                                    onPressed: () async {
                                      final supabase = Provider.of<SupabaseService>(context, listen: false);
                                      await supabase.client
                                          .from('notifications')
                                          .update({'is_read': true})
                                          .eq('id', n.id);
                                      _fetchNotifications();
                                    },
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

  Color _getTypeColor(String type) {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.amber;
      case 'error':
        return Colors.redAccent;
      default:
        return const Color(0xFF38BDF8); // Light Blue
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }
}
