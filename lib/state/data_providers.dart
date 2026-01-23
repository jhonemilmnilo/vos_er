import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserData {
  final int id;
  final String name;
  final String email;

  const UserData({required this.id, required this.name, required this.email});
}

enum AttendancePermission { view, approve, manage }

class PagedResult<T> {
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;

  const PagedResult({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}

// Providers
final userPermissionsServiceProvider = Provider<UserPermissionsService>((ref) {
  return UserPermissionsService();
});

final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, UserData?>((ref) {
  return CurrentUserNotifier();
});

class UserPermissionsService {
  // Stub implementation
  bool hasPermission(AttendancePermission permission) {
    return true; // Allow all for now
  }
}

class CurrentUserNotifier extends StateNotifier<UserData?> {
  CurrentUserNotifier() : super(null);

  void setUser(UserData user) {
    state = user;
  }

  void clearUser() {
    state = null;
  }
}
