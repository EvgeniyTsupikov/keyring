class Folder {
  final int? id;
  final String name;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  Folder({
    this.id,
    required this.name,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as int?,
        name: json['name'] as String,
        color: json['color'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Folder copyWith({
    int? id,
    String? name,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

