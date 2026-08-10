/// Holds the currently authenticated admin (JWT + claims) for the app session.
class Authorization {
  static String? token;
  static int? userId;
  static String? username;
  static String? firstName;
  static String? lastName;
  static String? role;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;
  static bool get isAdmin => role == 'Admin';

  static String get displayName {
    final parts = [firstName, lastName].where((s) => s != null && s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(' ') : (username ?? '');
  }

  static void clear() {
    token = null;
    userId = null;
    username = null;
    firstName = null;
    lastName = null;
    role = null;
  }
}
