// lib/models/user_model.dart
// 사용자 모델 — 백엔드 API 연동 버전

enum UserRole { owner, viewer, system }

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final bool isMfaEnabled;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.id,
    required this.email,
    this.name = '',
    required this.role,
    required this.isMfaEnabled,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    UserRole parseRole(String? r) {
      switch ((r ?? '').toUpperCase()) {
        case 'VIEWER':
          return UserRole.viewer;
        case 'SYSTEM':
          return UserRole.system;
        default:
          return UserRole.owner;
      }
    }

    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: parseRole(json['role'] as String?),
      isMfaEnabled: (json['isMfaEnabled'] as bool?) ??
          ((json['mfa_enabled'] as int?) == 1),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
              : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'] as String)
          : json['last_login_at'] != null
              ? DateTime.tryParse(json['last_login_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.name,
        'isMfaEnabled': isMfaEnabled,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
      };

  UserModel copyWith({
    String? email,
    String? name,
    bool? isMfaEnabled,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role,
      isMfaEnabled: isMfaEnabled ?? this.isMfaEnabled,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  String get displayName => name.isNotEmpty ? name : email.split('@').first;
}
