// lib/models/user_model.dart
// 사용자 모델 — 앱 내 인증/세션 상태를 표현

enum UserRole { owner, viewer }

class UserModel {
  final String id;
  final String email;
  final UserRole role;
  final bool isMfaEnabled;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.isMfaEnabled,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: (json['role'] as String?) == 'viewer'
          ? UserRole.viewer
          : UserRole.owner,
      isMfaEnabled: (json['isMfaEnabled'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role.name,
        'isMfaEnabled': isMfaEnabled,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
      };

  UserModel copyWith({
    String? email,
    bool? isMfaEnabled,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id,
      email: email ?? this.email,
      role: role,
      isMfaEnabled: isMfaEnabled ?? this.isMfaEnabled,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
