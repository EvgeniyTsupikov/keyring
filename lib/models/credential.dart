class Credential {
  final int? id;
  final String title;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final int? folderId;
  final Map<String, String> customFields; // Кастомные поля
  final Map<String, String> customFieldTypes; // Типы кастомных полей ('text' или 'password')
  final DateTime createdAt;
  final DateTime updatedAt;

  Credential({
    this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url,
    this.notes,
    this.folderId,
    Map<String, String>? customFields,
    Map<String, String>? customFieldTypes,
    required this.createdAt,
    required this.updatedAt,
  }) : customFields = customFields ?? {},
       customFieldTypes = customFieldTypes ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'folderId': folderId,
        'customFields': customFields,
        'customFieldTypes': customFieldTypes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Credential.fromJson(Map<String, dynamic> json) {
    Map<String, String> customFields = {};
    if (json['customFields'] != null) {
      final fields = json['customFields'] as Map;
      customFields = fields.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    
    Map<String, String> customFieldTypes = {};
    if (json['customFieldTypes'] != null) {
      final types = json['customFieldTypes'] as Map;
      customFieldTypes = types.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    
    return Credential(
      id: json['id'] as int?,
      title: json['title'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      url: json['url'] as String?,
      notes: json['notes'] as String?,
      folderId: json['folderId'] as int?,
      customFields: customFields,
      customFieldTypes: customFieldTypes,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Credential copyWith({
    int? id,
    String? title,
    String? username,
    String? password,
    String? url,
    String? notes,
    int? folderId,
    Map<String, String>? customFields,
    Map<String, String>? customFieldTypes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Credential(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      folderId: folderId ?? this.folderId,
      customFields: customFields ?? this.customFields,
      customFieldTypes: customFieldTypes ?? this.customFieldTypes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

