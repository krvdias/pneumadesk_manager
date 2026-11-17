class SystemAppModel {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final bool isSystem;
  bool isActive;
  List<String> maintenanceRoles;

  SystemAppModel({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.isSystem = false,
    this.isActive = true,
    this.maintenanceRoles = const [],
  });

  factory SystemAppModel.fromMap(Map<String, dynamic> map, {List<String>? maintenanceRoles}) {
    return SystemAppModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? map['app_name']?.toString() ?? '',
      description: map['description']?.toString(),
      icon: map['icon']?.toString(),
      isSystem: map['is_system'] == true,
      isActive: map['is_active'] ?? map['is_enabled'] ?? true,
      maintenanceRoles: maintenanceRoles ?? 
          (map['maintenance_roles'] is List 
              ? (map['maintenance_roles'] as List).map((e) => e.toString()).toList() 
              : []),
    );
  }
}

class AppMaintenanceRoleModel {
  final String id;
  final String appId;
  final String role;
  bool isMaintenanceEnabled;

  AppMaintenanceRoleModel({
    required this.id,
    required this.appId,
    required this.role,
    this.isMaintenanceEnabled = false,
  });

  factory AppMaintenanceRoleModel.fromMap(Map<String, dynamic> map) {
    return AppMaintenanceRoleModel(
      id: map['id']?.toString() ?? '',
      appId: map['app_id']?.toString() ?? '',
      role: map['role']?.toString() ?? map['role_name']?.toString() ?? '',
      isMaintenanceEnabled: map['is_maintenance_enabled'] ?? map['is_maintenance_mode'] ?? false,
    );
  }
}
