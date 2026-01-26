class BadgeModel {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? category;
  final String? conditionType;
  final int? conditionValue;
  final DateTime? createdAt;
  final DateTime? earnedAt; // 사용자가 획득한 경우

  BadgeModel({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.category,
    this.conditionType,
    this.conditionValue,
    this.createdAt,
    this.earnedAt,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      category: json['category'] as String?,
      conditionType: json['condition_type'] as String?,
      conditionValue: json['condition_value'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      earnedAt: json['earned_at'] != null
          ? DateTime.tryParse(json['earned_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'category': category,
      'condition_type': conditionType,
      'condition_value': conditionValue,
      'created_at': createdAt?.toIso8601String(),
      'earned_at': earnedAt?.toIso8601String(),
    };
  }

  BadgeModel copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? category,
    String? conditionType,
    int? conditionValue,
    DateTime? createdAt,
    DateTime? earnedAt,
  }) {
    return BadgeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      conditionType: conditionType ?? this.conditionType,
      conditionValue: conditionValue ?? this.conditionValue,
      createdAt: createdAt ?? this.createdAt,
      earnedAt: earnedAt ?? this.earnedAt,
    );
  }
}
