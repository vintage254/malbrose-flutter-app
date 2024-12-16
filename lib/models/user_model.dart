class User {
  final int? id;
  final String username;
  final String password; // We should hash this before storing
  final String fullName;
  final String email;
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.email,
    this.isAdmin = false,
    DateTime? createdAt,
    this.lastLogin,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password, // TODO: Add password hashing
      'full_name': fullName,
      'email': email,
      'is_admin': isAdmin ? 1 : 0,
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
      isAdmin: map['is_admin'] == 1,
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
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
} 