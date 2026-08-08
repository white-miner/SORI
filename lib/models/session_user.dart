enum UserRole { guest, director, customer }

class SessionUser {
  const SessionUser({
    required this.role,
    required this.name,
    required this.phone,
    this.customerId,
  });

  final UserRole role;
  final String name;
  final String phone;
  final String? customerId;

  String get phoneDigits => phone.replaceAll(RegExp(r'\D'), '');

  String get phoneLast4 {
    final d = phoneDigits;
    if (d.length < 4) return d;
    return d.substring(d.length - 4);
  }
}
