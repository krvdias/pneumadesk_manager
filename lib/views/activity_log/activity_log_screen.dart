import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/activity_log.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<ActivityLog> _logs = [];
  bool _isLoading = true;
  String _filterAction = 'all';

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final supabase = Provider.of<SupabaseService>(context, listen: false);

    try {
      final res = await supabase.client
          .from('activity_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(200);

      final list = (res as List).map((e) => ActivityLog.fromMap(e)).toList();

      if (mounted) {
        setState(() {
          _logs = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _logs.where((l) {
      if (_filterAction == 'all') return true;
      return l.action.toLowerCase().contains(_filterAction.toLowerCase());
    }).toList();

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
                    Text('Activity Logs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      'Auditing track of all administrative actions, logins, mutations and connections',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _fetchLogs,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Actions', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Auth', 'login'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Users', 'user'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Projects', 'project'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Databases', 'database'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Maintenance', 'maintenance'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Log List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.history_toggle_off, size: 48, color: Color(0xFF64748B)),
                              SizedBox(height: 12),
                              Text('No logs recorded', style: TextStyle(color: Color(0xFF94A3B8))),
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
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF334155)),
                              itemBuilder: (context, index) {
                                final log = filtered[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF334155),
                                    child: Icon(_getActionIcon(log.action), size: 18, color: Colors.white70),
                                  ),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF334155)),
                                        ),
                                        child: Text(
                                          log.action,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF38BDF8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'By ${log.username ?? "Unknown"}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      const Spacer(),
                                      if (log.createdAt != null)
                                        Text(
                                          DateFormat.yMMMd().add_jms().format(log.createdAt!),
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      log.details ?? 'No details attached',
                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                    ),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterAction == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filterAction = value),
      selectedColor: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF1E293B),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  IconData _getActionIcon(String action) {
    if (action.contains('LOGIN') || action.contains('LOGOUT')) return Icons.login;
    if (action.contains('USER')) return Icons.person;
    if (action.contains('PROJECT')) return Icons.folder;
    if (action.contains('DATABASE') || action.contains('CONNECT')) return Icons.storage;
    if (action.contains('MAINTENANCE') || action.contains('APP')) return Icons.settings_applications;
    return Icons.info_outline;
  }
}
