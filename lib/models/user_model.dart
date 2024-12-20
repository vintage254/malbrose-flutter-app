class User {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final String email;
  final String? role;
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.email,
    this.role = 'USER',
    required this.createdAt,
    this.lastLogin,
  });

  bool get isAdmin => role == 'ADMIN';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'full_name': fullName,
      'email': email,
      'role': role ?? 'USER',
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      fullName: map['full_name'],
      email: map['email'],
      role: map['role'] ?? 'USER',
      createdAt: DateTime.parse(map['created_at']),
      lastLogin: map['last_login'] != null 
          ? DateTime.parse(map['last_login'])
          : null,
    );
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    String? email,
    String? role,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
} 