import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_providers.dart';
import '../core/network/api_client.dart';
import '../data/models/dashboard_models.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/leave_repository.dart';
import '../data/repositories/overtime_repository.dart';

// =============================
// PROVIDERS
// =============================

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
      return DashboardNotifier(repo, authRepo);
    });

// =============================
// NOTIFIER
// =============================

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardData?>> {
  DashboardNotifier(this._repo, this._authRepo) : super(const AsyncValue.loading()) {
    loadDashboardData();
  }

  final DashboardRepository _repo;
  final AuthRepository _authRepo;

  Future<void> loadDashboardData() async {
    state = const AsyncValue.loading();

    try {
      final userId = await _authRepo.getCurrentAppUserId();
      final data = await _repo.fetchDashboardData(
        userId: userId,
        allowedDepartmentIds: null, // TODO: Get from permissions
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
