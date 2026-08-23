class Profile {
  final int id;
  final String username;
  final String? email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final bool hasProfileImage;

  Profile({
    required this.id,
    required this.username,
    this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    required this.hasProfileImage,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as int,
        username: json['username'] as String? ?? '',
        email: json['email'] as String?,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phoneNumber: json['phoneNumber'] as String?,
        hasProfileImage: json['hasProfileImage'] as bool? ?? false,
      );
}
