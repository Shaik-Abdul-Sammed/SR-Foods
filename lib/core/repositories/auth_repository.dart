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

class AuthRepository {
  final SharedPreferences prefs;

  static const String _userRoleKey = 'current_user_role';

  AuthRepository({required this.prefs});

  String get currentUserRole => prefs.getString(_userRoleKey) ?? 'owner';

  Future<void> login(String role) async {
    await prefs.setString(_userRoleKey, role);
  }

  Future<void> logout() async {
    await prefs.remove(_userRoleKey);
  }

  bool get isOwner => currentUserRole == 'owner';
  bool get isDelivery => currentUserRole == 'delivery';
  bool get isConsumer => currentUserRole == 'consumer'; // future addition
}
