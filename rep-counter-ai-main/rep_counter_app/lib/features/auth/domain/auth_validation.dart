/// Client-side checks matching the sign-up copy ("Use at least 10
/// characters"). The server stays the authority (leaked-password check).
abstract final class AuthValidation {
  static const minPasswordLength = 10;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static bool isPasswordLongEnough(String value) =>
      value.length >= minPasswordLength;
}
