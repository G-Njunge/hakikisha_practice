/// The signed-in user: Firebase Auth account plus their `users/{uid}` profile.
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.country,
    required this.role,
    required this.isVerified,
    required this.isAdmin,
  });

  final String id;
  final String email;
  final String fullName;

  /// Empty when the profile document is missing (e.g. its write failed at
  /// sign-up).
  final String country;

  /// One of `admin`, `manufacturer`, `pharmacist`, `consumer`. Display only.
  final String role;

  /// Whether the email address has been verified.
  final bool isVerified;

  /// From the `admin` custom claim, which is what the security rules trust.
  final bool isAdmin;
}
