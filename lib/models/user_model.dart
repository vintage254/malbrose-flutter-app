class User {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final String email;
  final String role;
  final String permissions;
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.email,
    this.role = 'USER',
    String? permissions,
    DateTime? createdAt,
    this.lastLogin,
  }) : permissions = permissions ?? (role == 'ADMIN' ? 'FULL_ACCESS' : 'BASIC'),
       createdAt = createdAt ?? DateTime.now();

  bool get isAdmin => role == 'ADMIN';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': username,
      'password': password,
      'full_name': fullName,
      'email': email,
      'role': role,
      'permissions': permissions,
      'created_at': createdAt.toIso8601String(),
      if (lastLogin != null) 'last_login': lastLogin!.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    // Ensure all required fields are present
    if (!map.containsKey('username') || 
        !map.containsKey('password') || 
        !map.containsKey('full_name') || 
        !map.containsKey('email') || 
        !map.containsKey('created_at')) {
      throw FormatException('Missing required fields in User.fromMap: ${map.keys}');
    }
    
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String,
      role: map['role'] as String? ?? 'USER',
      permissions: map['permissions'] as String? ?? 'BASIC',
      createdAt: DateTime.parse(map['created_at'] as String),
      lastLogin: map['last_login'] != null ? DateTime.parse(map['last_login'] as String) : null,
    );
  }

  User copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    String? email,
    String? role,
    String? permissions,
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
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
} 