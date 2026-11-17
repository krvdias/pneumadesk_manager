import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/project.dart';
import '../../data/models/project_database.dart';
import '../../data/models/system_app.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> _projects = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // Pagination
  int _currentPage = 1;
  final int _pageSize = 8;
  int _totalProjects = 0;

  // Selected project for detailed database management
  Project? _selectedProject;
  List<ProjectDatabase> _databases = [];
  bool _isLoadingDatabases = false;

  // Connected Client Database state
  ProjectDatabase? _connectedDb;
  SupabaseClient? _clientDbConnection;
  List<SystemAppModel> _clientApps = [];
  bool _isConnectingDb = false;

  final List<String> _availableRoles = [
    'super_admin',
    'admin',
    'group_leader',
  ];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoading = true);
    final supabase = Provider.of<SupabaseService>(context, listen: false);

    try {
      final countRes = await supabase.client.from('projects').select('id');
      _totalProjects = (countRes as List).length;

      final from = (_currentPage - 1) * _pageSize;
      final to = from + _pageSize - 1;

      var query = supabase.client
          .from('projects')
          .select('*, project_databases(count)')
          .order('created_at', ascending: false)
          .range(from, to);

      if (_searchQuery.isNotEmpty) {
        query = supabase.client
            .from('projects')
            .select('*, project_databases(count)')
            .ilike('name', '%$_searchQuery%')
            .order('created_at', ascending: false)
            .range(from, to);
      }

      final res = await query;
      final list = (res as List).map((p) {
        final dbCountList = p['project_databases'] as List?;
        final count = (dbCountList != null && dbCountList.isNotEmpty)
            ? (dbCountList[0]['count'] ?? 0)
            : 0;
        return Project.fromMap(p, databaseCount: count is int ? count : 0);
      }).toList();

      if (mounted) {
        setState(() {
          _projects = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDatabases(String projectId) async {
    setState(() => _isLoadingDatabases = true);
    final supabase = Provider.of<SupabaseService>(context, listen: false);

    try {
      final res = await supabase.client
          .from('project_databases')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      final list = (res as List).map((e) => ProjectDatabase.fromMap(e)).toList();
      if (mounted) {
        setState(() {
          _databases = list;
          _isLoadingDatabases = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDatabases = false);
    }
  }

  // Connect to the specific Database selected (Church_Mgmt_App Win_v7.3.0 exact match)
  Future<void> _connectToDatabase(ProjectDatabase db) async {
    setState(() {
      _isConnectingDb = true;
      _connectedDb = db;
      _clientApps = [];
    });

    final supabase = Provider.of<SupabaseService>(context, listen: false);

    try {
      final url = db.supabaseUrl;
      final key = (db.supabaseServiceRoleKey != null && db.supabaseServiceRoleKey!.isNotEmpty)
          ? db.supabaseServiceRoleKey!
          : db.supabaseAnonKey;

      if (url == null || url.isEmpty || key == null || key.isEmpty) {
        throw Exception('Supabase URL or Key missing for this database');
      }

      final testClient = SupabaseClient(url, key);
      _clientDbConnection = testClient;

      // 1. Fetch system_apps from connected project database
      final appsRes = await testClient.from('system_apps').select('*').order('name');
      final apps = List<Map<String, dynamic>>.from(appsRes);

      // 2. Fetch app_maintenance_roles from connected project database
      final maintenanceRes = await testClient.from('app_maintenance_roles').select('*');
      final maintenanceList = List<Map<String, dynamic>>.from(maintenanceRes);

      final parsedApps = <SystemAppModel>[];
      for (var app in apps) {
        final appId = app['id']?.toString() ?? '';
        final activeRoles = maintenanceList
            .where((m) => m['app_id'] == appId && m['is_maintenance_enabled'] == true)
            .map((m) => m['role']?.toString() ?? '')
            .where((r) => r.isNotEmpty)
            .toList();
        parsedApps.add(SystemAppModel.fromMap(app, maintenanceRoles: activeRoles));
      }

      _clientApps = parsedApps;

      await supabase.logActivity(
        action: 'CONNECT_DATABASE',
        details: 'Connected to external database: ${db.dbName} (${db.supabaseUrl})',
        entityType: 'database',
        entityId: db.id,
      );

      await supabase.sendNotification(
        title: 'Database Connected',
        message: 'Connected to database "${db.dbName}" for project "${_selectedProject?.name}"',
        type: 'success',
      );

      if (mounted) {
        setState(() => _isConnectingDb = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnectingDb = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to database: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Disconnect from the current active database
  void _disconnectDatabase() {
    if (_connectedDb == null) return;
    final dbName = _connectedDb!.dbName;

    setState(() {
      _connectedDb = null;
      _clientDbConnection = null;
      _clientApps = [];
    });

    final supabase = Provider.of<SupabaseService>(context, listen: false);
    supabase.logActivity(
      action: 'DISCONNECT_DATABASE',
      details: 'Disconnected from database: $dbName',
      entityType: 'database',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Disconnected from $dbName'),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }

  // Toggle App Active Status (Win_v7.3.0 setAppActiveStatus)
  Future<void> _toggleAppStatus(SystemAppModel app, bool newValue) async {
    setState(() => app.isActive = newValue);
    try {
      if (_clientDbConnection != null) {
        await _clientDbConnection!
            .from('system_apps')
            .update({
              'is_active': newValue,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', app.id);
      }
    } catch (_) {}

    if (!mounted) return;
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    await supabase.logActivity(
      action: 'UPDATE_SYSTEM_APP',
      details: 'App ${app.name} (${app.id}) isActive: $newValue in database ${_connectedDb?.dbName}',
      entityType: 'app',
      entityId: app.id,
    );

    await supabase.sendNotification(
      title: 'App State Changed',
      message: '${app.name} was ${newValue ? "Enabled" : "Disabled"} in ${_connectedDb?.dbName}',
      type: newValue ? 'success' : 'warning',
    );
  }

  // Toggle Maintenance Role (Win_v7.3.0 setAppMaintenanceRole)
  Future<void> _toggleMaintenanceRole(SystemAppModel app, String role, bool isEnabled) async {
    setState(() {
      final updatedList = List<String>.from(app.maintenanceRoles);
      if (isEnabled) {
        if (!updatedList.contains(role)) updatedList.add(role);
      } else {
        updatedList.remove(role);
      }
      app.maintenanceRoles = updatedList;
    });

    try {
      if (_clientDbConnection != null) {
        await _clientDbConnection!
            .from('app_maintenance_roles')
            .upsert({
              'app_id': app.id,
              'role': role,
              'is_maintenance_enabled': isEnabled,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'app_id, role');
      }
    } catch (_) {}

    if (!mounted) return;
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    await supabase.logActivity(
      action: 'MAINTENANCE_TOGGLE',
      details: 'App ${app.name} role $role maintenance: $isEnabled in ${_connectedDb?.dbName}',
      entityType: 'maintenance',
      entityId: app.id,
    );

    await supabase.sendNotification(
      title: 'Maintenance Mode Updated',
      message: '${app.name}: Maintenance for role "$role" set to ${isEnabled ? "ENABLED" : "DISABLED"}',
      type: isEnabled ? 'warning' : 'info',
    );
  }

  // Project CRUD Dialog
  void _showProjectDialog({Project? project}) {
    final nameController = TextEditingController(text: project?.name ?? '');
    final descController = TextEditingController(text: project?.description ?? '');
    final isEditing = project != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(isEditing ? 'Edit Project' : 'Create New Project'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Project Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                ),
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
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final supabase = Provider.of<SupabaseService>(context, listen: false);
                Navigator.pop(context);

                if (isEditing) {
                  await supabase.client.from('projects').update({
                    'name': name,
                    'description': descController.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', project.id);

                  await supabase.logActivity(
                    action: 'UPDATE_PROJECT',
                    details: 'Updated project "$name"',
                    entityType: 'project',
                    entityId: project.id,
                  );
                } else {
                  final inserted = await supabase.client.from('projects').insert({
                    'name': name,
                    'description': descController.text.trim(),
                  }).select().single();

                  await supabase.logActivity(
                    action: 'CREATE_PROJECT',
                    details: 'Created project "$name"',
                    entityType: 'project',
                    entityId: inserted['id'],
                  );

                  await supabase.sendNotification(
                    title: 'New Project Added',
                    message: 'Project "$name" was registered.',
                    type: 'success',
                  );
                }

                _fetchProjects();
              },
              child: Text(isEditing ? 'Save' : 'Create Project'),
            ),
          ],
        );
      },
    );
  }

  // Delete Project Confirmation
  void _confirmDeleteProject(Project project) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Delete Project'),
          content: Text('Are you sure you want to delete project "${project.name}" and all its attached databases?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final supabase = Provider.of<SupabaseService>(context, listen: false);
                Navigator.pop(context);

                await supabase.client.from('projects').delete().eq('id', project.id);

                await supabase.logActivity(
                  action: 'DELETE_PROJECT',
                  details: 'Deleted project ${project.name}',
                  entityType: 'project',
                  entityId: project.id,
                );

                if (_selectedProject?.id == project.id) {
                  setState(() {
                    _selectedProject = null;
                    _connectedDb = null;
                  });
                }

                _fetchProjects();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Database Form Dialog (with Import from TXT option)
  void _showDatabaseFormDialog({ProjectDatabase? database}) {
    if (_selectedProject == null) return;
    final isEditing = database != null;

    final dbNameCtrl = TextEditingController(text: database?.dbName ?? '');
    final urlCtrl = TextEditingController(text: database?.supabaseUrl ?? '');
    final sRoleKeyCtrl = TextEditingController(text: database?.supabaseServiceRoleKey ?? '');
    final anonKeyCtrl = TextEditingController(text: database?.supabaseAnonKey ?? '');
    final dbHostCtrl = TextEditingController(text: database?.dbHost ?? '');
    final dbPassCtrl = TextEditingController(text: database?.dbPassword ?? '');
    final smsProviderCtrl = TextEditingController(text: database?.smsProvider ?? '');
    final notifyUrlCtrl = TextEditingController(text: database?.notifyBaseUrl ?? '');
    final notifyKeyCtrl = TextEditingController(text: database?.notifyApiKey ?? '');
    final notifyUserCtrl = TextEditingController(text: database?.notifyUserId ?? '');
    final notifySenderCtrl = TextEditingController(text: database?.notifySenderId ?? '');
    final r2AccessCtrl = TextEditingController(text: database?.r2AccessKey ?? '');
    final r2SecretCtrl = TextEditingController(text: database?.r2SecretKey ?? '');
    final r2EndpointCtrl = TextEditingController(text: database?.r2Endpoint ?? '');
    final r2PublicCtrl = TextEditingController(text: database?.r2PublicUrl ?? '');

    // Function to parse a TXT / .env file
    Future<void> importFromTxt(void Function(void Function()) setDialogState) async {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'env'],
      );
      if (res.isNotEmpty && res.first.path != null) {
        final content = await File(res.first.path!).readAsString();
        final lines = content.split('\n');
        final map = <String, String>{};

        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final splitIndex = trimmed.indexOf('=');
          if (splitIndex > 0) {
            final k = trimmed.substring(0, splitIndex).trim();
            final v = trimmed.substring(splitIndex + 1).trim();
            map[k] = v;
          }
        }

        setDialogState(() {
          if (map['DB_NAME'] != null) dbNameCtrl.text = map['DB_NAME']!;
          if (map['SUPABASE_URL'] != null) urlCtrl.text = map['SUPABASE_URL']!;
          if (map['SUPABASE_SERVICE_ROLE_KEY'] != null) sRoleKeyCtrl.text = map['SUPABASE_SERVICE_ROLE_KEY']!;
          if (map['SUPABASE_ANON_KEY'] != null) anonKeyCtrl.text = map['SUPABASE_ANON_KEY']!;
          if (map['DB_HOST'] != null) dbHostCtrl.text = map['DB_HOST']!;
          if (map['DB_PASSWORD'] != null) dbPassCtrl.text = map['DB_PASSWORD']!;
          if (map['SMS_PROVIDER'] != null) smsProviderCtrl.text = map['SMS_PROVIDER']!;
          if (map['NOTIFY_BASE_URL'] != null) notifyUrlCtrl.text = map['NOTIFY_BASE_URL']!;
          if (map['NOTIFY_API_KEY'] != null) notifyKeyCtrl.text = map['NOTIFY_API_KEY']!;
          if (map['NOTIFY_USER_ID'] != null) notifyUserCtrl.text = map['NOTIFY_USER_ID']!;
          if (map['NOTIFY_SENDER_ID'] != null) notifySenderCtrl.text = map['NOTIFY_SENDER_ID']!;
          if (map['R2_ACCESS_KEY'] != null) r2AccessCtrl.text = map['R2_ACCESS_KEY']!;
          if (map['R2_SECRET_KEY'] != null) r2SecretCtrl.text = map['R2_SECRET_KEY']!;
          if (map['R2_ENDPOINT'] != null) r2EndpointCtrl.text = map['R2_ENDPOINT']!;
          if (map['R2_PUBLIC_URL'] != null) r2PublicCtrl.text = map['R2_PUBLIC_URL']!;
        });
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEditing ? 'Edit Database Config' : 'Add Database Config'),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: const Color(0xFF38BDF8),
                    ),
                    onPressed: () => importFromTxt(setDialogState),
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Import from TXT / .env'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 500,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(controller: dbNameCtrl, decoration: const InputDecoration(labelText: 'Database Name *')),
                      const SizedBox(height: 10),
                      TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'SUPABASE_URL *')),
                      const SizedBox(height: 10),
                      TextField(controller: sRoleKeyCtrl, decoration: const InputDecoration(labelText: 'SUPABASE_SERVICE_ROLE_KEY')),
                      const SizedBox(height: 10),
                      TextField(controller: anonKeyCtrl, decoration: const InputDecoration(labelText: 'SUPABASE_ANON_KEY')),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: dbHostCtrl, decoration: const InputDecoration(labelText: 'DB_HOST'))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: dbPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'DB_PASSWORD'))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: smsProviderCtrl, decoration: const InputDecoration(labelText: 'SMS_PROVIDER'))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: notifySenderCtrl, decoration: const InputDecoration(labelText: 'NOTIFY_SENDER_ID'))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: notifyUrlCtrl, decoration: const InputDecoration(labelText: 'NOTIFY_BASE_URL')),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: notifyKeyCtrl, decoration: const InputDecoration(labelText: 'NOTIFY_API_KEY'))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: notifyUserCtrl, decoration: const InputDecoration(labelText: 'NOTIFY_USER_ID'))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: r2AccessCtrl, decoration: const InputDecoration(labelText: 'R2_ACCESS_KEY'))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: r2SecretCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'R2_SECRET_KEY'))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: r2EndpointCtrl, decoration: const InputDecoration(labelText: 'R2_ENDPOINT')),
                      const SizedBox(height: 10),
                      TextField(controller: r2PublicCtrl, decoration: const InputDecoration(labelText: 'R2_PUBLIC_URL')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final dbName = dbNameCtrl.text.trim();
                    if (dbName.isEmpty) return;

                    final supabase = Provider.of<SupabaseService>(context, listen: false);
                    Navigator.pop(context);

                    final data = {
                      'project_id': _selectedProject!.id,
                      'db_name': dbName,
                      'supabase_url': urlCtrl.text.trim(),
                      'supabase_service_role_key': sRoleKeyCtrl.text.trim(),
                      'supabase_anon_key': anonKeyCtrl.text.trim(),
                      'db_password': dbPassCtrl.text.trim(),
                      'db_host': dbHostCtrl.text.trim(),
                      'sms_provider': smsProviderCtrl.text.trim(),
                      'notify_base_url': notifyUrlCtrl.text.trim(),
                      'notify_api_key': notifyKeyCtrl.text.trim(),
                      'notify_user_id': notifyUserCtrl.text.trim(),
                      'notify_sender_id': notifySenderCtrl.text.trim(),
                      'r2_access_key': r2AccessCtrl.text.trim(),
                      'r2_secret_key': r2SecretCtrl.text.trim(),
                      'r2_endpoint': r2EndpointCtrl.text.trim(),
                      'r2_public_url': r2PublicCtrl.text.trim(),
                      'updated_at': DateTime.now().toIso8601String(),
                    };

                    if (isEditing) {
                      await supabase.client.from('project_databases').update(data).eq('id', database.id);
                      await supabase.logActivity(
                        action: 'UPDATE_DATABASE',
                        details: 'Updated database configuration "$dbName"',
                        entityType: 'database',
                        entityId: database.id,
                      );
                    } else {
                      final ins = await supabase.client.from('project_databases').insert(data).select().single();
                      await supabase.logActivity(
                        action: 'CREATE_DATABASE',
                        details: 'Added database "$dbName" to project ${_selectedProject!.name}',
                        entityType: 'database',
                        entityId: ins['id'],
                      );
                      await supabase.sendNotification(
                        title: 'New Database Added',
                        message: 'Database "$dbName" was added to ${_selectedProject!.name}',
                        type: 'info',
                      );
                    }

                    _fetchDatabases(_selectedProject!.id);
                    _fetchProjects();
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Save Database'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Provider.of<SupabaseService>(context);
    final user = supabase.currentUser;
    final canDelete = user?.isAdmin == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Projects List & Pagination
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Projects', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        onPressed: () => _showProjectDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Project'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search bar
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search projects by name...',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _currentPage = 1;
                      _fetchProjects();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Project List
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _projects.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.folder_off_outlined, size: 48, color: Color(0xFF64748B)),
                                    SizedBox(height: 8),
                                    Text('No projects found', style: TextStyle(color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: _projects.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final p = _projects[index];
                                  final isSelected = _selectedProject?.id == p.id;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedProject = p;
                                        _connectedDb = null;
                                        _clientApps = [];
                                      });
                                      _fetchDatabases(p.id);
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF334155) : const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF334155),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                            child: const Icon(Icons.folder, color: Color(0xFF6366F1), size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${p.databaseCount} Database(s) connected',
                                                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            onPressed: () => _showProjectDialog(project: p),
                                          ),
                                          if (canDelete)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                              onPressed: () => _confirmDeleteProject(p),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),

                  // Pagination Bar
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing page $_currentPage of ${(_totalProjects / _pageSize).ceil().clamp(1, 999)}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? () {
                                    setState(() => _currentPage--);
                                    _fetchProjects();
                                  }
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: (_currentPage * _pageSize) < _totalProjects
                                ? () {
                                    setState(() => _currentPage++);
                                    _fetchProjects();
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 24),

            // Right Column: Project Databases & Connected Church_Mgmt_App Controls
            Expanded(
              flex: 6,
              child: _selectedProject == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.touch_app_outlined, size: 48, color: Color(0xFF64748B)),
                          SizedBox(height: 12),
                          Text('Select a project to inspect its databases and app controls',
                              style: TextStyle(color: Color(0xFF94A3B8))),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Project Sub-header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedProject!.name,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _selectedProject!.description ?? 'No description',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _showDatabaseFormDialog(),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Database'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Databases List
                          if (_isLoadingDatabases)
                            const Center(child: CircularProgressIndicator())
                          else if (_databases.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Center(
                                child: Column(
                                  children: const [
                                    Icon(Icons.storage, size: 36, color: Color(0xFF64748B)),
                                    SizedBox(height: 8),
                                    Text('No databases configured for this project',
                                        style: TextStyle(color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _databases.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final db = _databases[index];
                                final isConnected = _connectedDb?.id == db.id;

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isConnected ? const Color(0xFF10B981) : const Color(0xFF334155),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 12,
                                        runSpacing: 10,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.dns,
                                                  color: isConnected ? const Color(0xFF10B981) : const Color(0xFF06B6D4),
                                                  size: 20),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  db.dbName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              if (isConnected)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: Colors.green),
                                                  ),
                                                  child: const Text('CONNECTED',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.green,
                                                          fontWeight: FontWeight.bold)),
                                                ),
                                            ],
                                          ),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: _isConnectingDb ? null : () => _connectToDatabase(db),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isConnected
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFF6366F1),
                                                ),
                                                icon: const Icon(Icons.link, size: 16),
                                                label: Text(isConnected ? 'Re-Connect' : 'Connect'),
                                              ),
                                              if (isConnected)
                                                OutlinedButton.icon(
                                                  onPressed: _disconnectDatabase,
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.redAccent,
                                                    side: const BorderSide(color: Colors.redAccent, width: 1),
                                                  ),
                                                  icon: const Icon(Icons.link_off, size: 16),
                                                  label: const Text('Disconnect'),
                                                ),
                                              IconButton(
                                                icon: const Icon(Icons.edit, size: 18),
                                                onPressed: () => _showDatabaseFormDialog(database: db),
                                              ),
                                              if (canDelete)
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline,
                                                      color: Colors.redAccent, size: 18),
                                                  onPressed: () async {
                                                    final supabase =
                                                        Provider.of<SupabaseService>(context, listen: false);
                                                    await supabase.client
                                                        .from('project_databases')
                                                        .delete()
                                                        .eq('id', db.id);
                                                    _fetchDatabases(_selectedProject!.id);
                                                    _fetchProjects();
                                                  },
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            isConnected ? Icons.check_circle_outline : Icons.link_outlined,
                                            size: 14,
                                            color: isConnected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isConnected ? 'Database connection active' : 'Ready to connect',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                          // Connected Church_Mgmt_App system_apps and app_maintenance_roles Controls
                          if (_connectedDb != null) ...[
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 10,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.settings_applications, color: Color(0xFF10B981)),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              'Connected App Controls: ${_connectedDb!.dbName}',
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _disconnectDatabase,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(color: Colors.redAccent, width: 1),
                                        ),
                                        icon: const Icon(Icons.link_off, size: 16),
                                        label: const Text('Disconnect Database'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Manage system_apps active status and app_maintenance_roles (Church_Mgmt_App Win_v7.3.0 schema)',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                  const Divider(height: 24, color: Color(0xFF334155)),

                                  if (_clientApps.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        'No system_apps records found in this connected database.',
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                      ),
                                    )
                                  else
                                    ..._clientApps.map((app) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF334155)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // App Name and Status Switch
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      app.icon == 'receipt_long'
                                                          ? Icons.receipt_long
                                                          : app.icon == 'fact_check'
                                                              ? Icons.fact_check
                                                              : Icons.people,
                                                      color: const Color(0xFF38BDF8),
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                              app.name,
                                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                            ),
                                                            if (app.isSystem) ...[
                                                              const SizedBox(width: 8),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.blue.withValues(alpha: 0.2),
                                                                  borderRadius: BorderRadius.circular(4),
                                                                ),
                                                                child: const Text('System', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        Text('ID: ${app.id}',
                                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      app.isActive ? 'ACTIVE' : 'INACTIVE',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: app.isActive ? const Color(0xFF10B981) : Colors.redAccent,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Switch(
                                                      value: app.isActive,
                                                      activeThumbColor: const Color(0xFF10B981),
                                                      onChanged: (val) => _toggleAppStatus(app, val),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),

                                            if (app.description != null && app.description!.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                app.description!,
                                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                              ),
                                            ],

                                            const SizedBox(height: 12),
                                            const Divider(height: 1, color: Color(0xFF1E293B)),
                                            const SizedBox(height: 10),

                                            // Maintenance Mode per Role for this App
                                            const Text(
                                              'Maintenance Mode per Role:',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: _availableRoles.map((role) {
                                                final isInMaintenance = app.maintenanceRoles.contains(role);
                                                return FilterChip(
                                                  label: Text(
                                                    '${role.toUpperCase()}: ${isInMaintenance ? "MAINTENANCE ON" : "NORMAL"}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isInMaintenance ? Colors.amber : Colors.white70,
                                                      fontWeight: isInMaintenance ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                  selected: isInMaintenance,
                                                  selectedColor: Colors.amber.withValues(alpha: 0.2),
                                                  backgroundColor: const Color(0xFF1E293B),
                                                  side: BorderSide(
                                                    color: isInMaintenance ? Colors.amber : const Color(0xFF334155),
                                                  ),
                                                  onSelected: (selected) {
                                                    _toggleMaintenanceRole(app, role, selected);
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
