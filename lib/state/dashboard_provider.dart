import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../core/auth/user_permissions.dart';
import '../core/network/api_client.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/auth_repository.dart';

// =============================
// PROVIDERS
// =============================

/*
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final api = ref.read(apiClientProvider);
  final attendanceRepo = AttendanceRepository(api);
  final leaveRepo = LeaveRepository(api);
  final overtimeRepo = OvertimeRepository(api);

  return DashboardRepository(api, attendanceRepo, leaveRepo, overtimeRepo);
});

final dashboardDataProvider =
    StateNotifierProvider.autoDispose<DashboardNotifier, AsyncValue<DashboardData?>>((ref) {
      final repo = ref.read(dashboardRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);
      final permissionsService = ref.read(userPermissionsServiceProvider);
      return DashboardNotifier(repo, authRepo, permissionsService);
    });

// =============================
// NOTIFIER
// =============================

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardData?>> {
  DashboardNotifier(this._repo, this._authRepo, this._permissionsService)
    : super(const AsyncValue.loading()) {
    loadDashboardData();
  }

  final DashboardRepository _repo;
  final AuthRepository _authRepo;
  final UserPermissionsService _permissionsService;

  Future<List<int>?> _getAllowedDepartmentIds() async {
    try {
      final user = await _permissionsService.getCurrentUser();
      if (user == null) return null;

      // Check current department port
      final currentDept = await _getCurrentDepartment();
      final port = currentDept?.port;

      // Special rules for full access
      if ((port == 8091 || port == 8092) && user.departmentId == 2 && user.isAdmin) {
        return null; // Full access
      }
      if (port == 8090 && user.departmentId == 6 && user.isAdmin) {
        return null; // Full access
      }

      // For other departments, users can only see their own department
      return user.departmentId != null ? [user.departmentId!] : [];
    } catch (e) {
      debugPrint('Failed to retrieve user permissions: $e');
      return null;
    }
  }

  Future<Department?> _getCurrentDepartment() async {
    // Assuming we can get the current department from shared preferences or similar
    // This might need to be implemented based on how the app stores the current department
    // For now, return null to avoid breaking existing logic
    return null;
  }

  Future<void> loadDashboardData() async {
    state = const AsyncValue.loading();

    try {
      final userId = await _authRepo.getCurrentAppUserId();
      final allowedDepartmentIds = await _getAllowedDepartmentIds();
      final data = await _repo.fetchDashboardData(
        userId: userId,
        allowedDepartmentIds: allowedDepartmentIds,
      );

      state = AsyncValue.data(data);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refreshDashboardData() async {
    await loadDashboardData();
  }
}

// =============================
// SELECTED PROVIDERS
// =============================

final dashboardMetricsProvider = Provider.autoDispose<DashboardMetrics?>((ref) {
  final dashboardState = ref.watch(dashboardDataProvider);
  return dashboardState.maybeWhen(data: (data) => data?.metrics, orElse: () => null);
});

final attendanceTrendsProvider = Provider.autoDispose<List<AttendanceTrendPoint>>((ref) {
  final dashboardState = ref.watch(dashboardDataProvider);
  return dashboardState.maybeWhen(data: (data) => data?.attendanceTrends ?? [], orElse: () => []);
});

final justClockedInProvider = Provider.autoDispose<List<JustClockedInEntry>>((ref) {
  final dashboardState = ref.watch(dashboardDataProvider);
  return dashboardState.maybeWhen(data: (data) => data?.justClockedIn ?? [], orElse: () => []);
});

final pendingApprovalsProvider = Provider.autoDispose<List<PendingApproval>>((ref) {
  final dashboardState = ref.watch(dashboardDataProvider);
  return dashboardState.maybeWhen(data: (data) => data?.pendingApprovals ?? [], orElse: () => []);
});

final anomalyAlertsProvider = Provider.autoDispose<List<AnomalyAlert>>((ref) {
  final dashboardState = ref.watch(dashboardDataProvider);
  return dashboardState.maybeWhen(data: (data) => data?.anomalyAlerts ?? [], orElse: () => []);
});

final departmentEfficiencyProvider = Provider.autoDispose<List<DepartmentEfficiency>>((ref) {
  final dashboardState = ref.watch(dashboardDataProvider);
  return dashboardState.maybeWhen(
    data: (data) => data?.departmentEfficiency ?? [],
    orElse: () => [],
  );
});

// =============================
// LOADING STATE PROVIDERS
// =============================

final dashboardLoadingProvider = Provider.autoDispose<bool>((ref) {
  final dashboardState = ref.watch(dashboardDataProvider);
  return dashboardState.isLoading;
});

final dashboardErrorProvider = Provider.autoDispose<String?>((ref) {
  final dashboardState = ref.watch(dashboardDataProvider);
  return dashboardState.maybeWhen(error: (error, _) => error.toString(), orElse: () => null);
});
*/

// =============================
// PROFILE PROVIDERS
// =============================

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return ProfileRepository(api);
});

final profileDataProvider =
    StateNotifierProvider.autoDispose<ProfileNotifier, AsyncValue<UserProfile?>>((ref) {
      final repo = ref.read(profileRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);
      final permissionsService = ref.read(userPermissionsServiceProvider);
      return ProfileNotifier(repo, authRepo, permissionsService);
    });

// =============================
// PROFILE NOTIFIER
// =============================

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileNotifier(this._repo, this._authRepo, this._permissionsService)
    : super(const AsyncValue.loading()) {
    loadProfileData();
  }

  final ProfileRepository _repo;
  final AuthRepository _authRepo;
  final UserPermissionsService _permissionsService;

  Future<void> loadProfileData() async {
    state = const AsyncValue.loading();

    try {
      final userId = await _authRepo.getCurrentAppUserId();
      if (userId == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final profile = await _repo.fetchUserProfile(userId);
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refreshProfileData() async {
    // Clear user permissions cache to ensure department updates are reflected
    _permissionsService.clearUser();
    await loadProfileData();
  }
}

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<UserProfile> fetchUserProfile(int userId) async {
    final json = await _api.getJson("/items/user/$userId");
    return UserProfile.fromJson(json['data'] as Map<String, dynamic>);
  }
}
