class AuthUser {
  final int id;
  final String username;
  final String? email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String role;

  AuthUser({
    required this.id,
    required this.username,
    this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        username: json['username'] as String? ?? '',
        email: json['email'] as String?,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String?,
        role: json['role'] as String? ?? '',
      );
}
