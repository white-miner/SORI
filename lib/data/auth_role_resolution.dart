import '../models/customer.dart';
import '../models/session_user.dart';
import '../models/shop.dart';

/// Auth 유저 → 원장(shops) / 고객(customers) 판별 결과.
class AuthRoleResolution {
  const AuthRoleResolution._({
    this.role,
    this.shop,
    this.customer,
  });

  const AuthRoleResolution.director(Shop shop)
      : this._(role: UserRole.director, shop: shop);

  const AuthRoleResolution.customer(Customer customer)
      : this._(role: UserRole.customer, customer: customer);

  const AuthRoleResolution.unknown() : this._();

  final UserRole? role;
  final Shop? shop;
  final Customer? customer;

  bool get isDirector => role == UserRole.director && shop != null;
  bool get isCustomer => role == UserRole.customer && customer != null;
  bool get isKnown => isDirector || isCustomer;
}
