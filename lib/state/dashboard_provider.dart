import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
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

      // Special rule for department 6
      if (user.departmentId == 2) {
        if (user.isAdmin == true) {
          // Admin in department 6 can see all departments
          return null;
        } else {
          // Non-admin in department 6 can only see department 6
          return [6];
        }
      } else {
        // For other departments, users can only see their own department
        return user.departmentId != null ? [user.departmentId!] : [];
      }
    } catch (e) {
      debugPrint('Failed to retrieve user permissions: $e');
      return null;
    }
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
      return ProfileNotifier(repo, authRepo);
    });

// =============================
// PROFILE NOTIFIER
// =============================

class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileNotifier(this._repo, this._authRepo) : super(const AsyncValue.loading()) {
    loadProfileData();
  }

  final ProfileRepository _repo;
  final AuthRepository _authRepo;

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
