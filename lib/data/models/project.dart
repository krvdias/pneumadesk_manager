class Project {
  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;
  final int databaseCount;

  Project({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.databaseCount = 0,
  });

  factory Project.fromMap(Map<String, dynamic> map, {int databaseCount = 0}) {
    return Project(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      databaseCount: databaseCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
    };
  }
}
