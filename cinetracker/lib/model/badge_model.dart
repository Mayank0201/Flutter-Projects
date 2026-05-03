/// Represents a gamification badge from the backend's Badge entity.
class Badge {
  final int id;
  final String name;
  final String description;
  final String iconUrl;
  final String criteriaType;

  const Badge({
    required this.id,
    required this.name,
    this.description = '',
    this.iconUrl = '',
    this.criteriaType = '',
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      iconUrl: (json['iconUrl'] ?? '').toString(),
      criteriaType: (json['criteriaType'] ?? '').toString(),
    );
  }
}
