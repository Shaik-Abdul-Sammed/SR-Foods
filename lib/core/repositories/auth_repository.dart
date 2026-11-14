import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in main');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

enum UserRole {
  owner('owner', 'Business Owner'),
  supervisor('supervisor', 'Factory Supervisor'),
  delivery('delivery', 'Van Delivery Staff'),
  staff('staff', 'General Staff');

  final String id;
  final String title;
  const UserRole(this.id, this.title);

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'supervisor':
        return UserRole.supervisor;
      case 'delivery':
        return UserRole.delivery;
      default:
        return UserRole.staff;
    }
  }
}

class AuthRepository {
  final SharedPreferences prefs;

  static const String _userRoleKey = 'current_user_role';
  static const String _userNameKey = 'current_user_name';

  AuthRepository({required this.prefs});

  String get currentUserRole => prefs.getString(_userRoleKey) ?? 'owner';
  String get currentUserName => prefs.getString(_userNameKey) ?? 'SM Subhani';

  Future<void> login(String role, {String? name}) async {
    await prefs.setString(_userRoleKey, role);
    if (name != null) {
      await prefs.setString(_userNameKey, name);
    }
  }

  Future<void> logout() async {
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userNameKey);
  }

  // Role Checks
  bool get isOwner => currentUserRole == 'owner';
  bool get isSupervisor => currentUserRole == 'supervisor';
  bool get isDelivery => currentUserRole == 'delivery';
  bool get isStaff => currentUserRole == 'staff';

  // Permission Gates
  bool get canStartProduction => isOwner || isSupervisor;
  bool get canEditPrices => isOwner;
  bool get canDeleteRecords => isOwner;
  bool get canViewReports => isOwner || isSupervisor;
  bool get canManageInventory => isOwner || isSupervisor;
  bool get canAccessSettings => isOwner;
}
