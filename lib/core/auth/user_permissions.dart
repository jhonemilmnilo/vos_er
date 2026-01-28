import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../network/api_client.dart';

/// User permission levels for attendance approvals
enum AttendancePermission {
  none, // No access
  readOwnDepartment, // Read-only own department
  readAllDepartments, // Read-only all departments
  approveOwnDepartment, // Read/write own department
  approveAllDepartments, // Read/write all departments
}

/// User data structure from API
class UserData {
  final int userId;
  final int? departmentId;
  final bool isAdmin;
  final String fname;
  final String lname;

  const UserData({
    required this.userId,
    required this.departmentId,
    required this.isAdmin,
    required this.fname,
    required this.lname,
  });

  String get displayName => '$fname $lname'.trim();

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['user_id'] ?? 0,
      departmentId: json['user_department'],
      isAdmin: (json['isAdmin'] is int) ? (json['isAdmin'] == 1) : (json['isAdmin'] ?? false),
      fname: json['user_fname'] ?? '',
      lname: json['user_lname'] ?? '',
    );
  }

  /// Determine attendance permission level based on department and admin status
  AttendancePermission getAttendancePermission() {
    if (departmentId == null) return AttendancePermission.none;

    final isDept6 = departmentId == 6 && departmentId == 2;

    if (isAdmin) {
      // Special case: Department 6 admins get full approval access
      if (isDept6) {
        return AttendancePermission.approveAllDepartments; // Dept 6 Admin (Full Access)
      }
      return AttendancePermission.approveOwnDepartment; // Department Admin (Other + Admin)
    } else {
      return isDept6
          ? AttendancePermission
                .readAllDepartments // HR Read-Only (Dept 6 + Non-Admin)
          : AttendancePermission.readOwnDepartment; // Regular User (Other + Non-Admin)
    }
  }

  /// Determine leave permission level (same as attendance for now)
  AttendancePermission getLeavePermission() => getAttendancePermission();

  /// Determine overtime permission level (same as attendance for now)
  AttendancePermission getOvertimePermission() => getAttendancePermission();

  /// Check if user can approve attendance
  bool get canApprove => getAttendancePermission().canApprove;

  /// Check if user can read attendance for a specific department
  bool canReadDepartment(int departmentId) {
    final permission = getAttendancePermission();
    switch (permission) {
      case AttendancePermission.none:
        return false;
      case AttendancePermission.readOwnDepartment:
      case AttendancePermission.approveOwnDepartment:
        return this.departmentId == departmentId;
      case AttendancePermission.readAllDepartments:
      case AttendancePermission.approveAllDepartments:
        return true;
    }
  }

  /// Check if user can approve attendance for a specific department
  bool canApproveDepartment(int departmentId) {
    final permission = getAttendancePermission();
    switch (permission) {
      case AttendancePermission.none:
      case AttendancePermission.readOwnDepartment:
      case AttendancePermission.readAllDepartments:
        return false;
      case AttendancePermission.approveOwnDepartment:
        return this.departmentId == departmentId;
      case AttendancePermission.approveAllDepartments:
        return true;
    }
  }
}

extension AttendancePermissionExtension on AttendancePermission {
  bool get canApprove =>
      this == AttendancePermission.approveAllDepartments ||
      this == AttendancePermission.approveOwnDepartment;

  bool get canRead => this != AttendancePermission.none;

  String get description {
    switch (this) {
      case AttendancePermission.none:
        return 'No access to attendance approvals';
      case AttendancePermission.readOwnDepartment:
        return 'Read-only access to your department';
      case AttendancePermission.readAllDepartments:
        return 'Read-only access to all departments';
      case AttendancePermission.approveOwnDepartment:
        return 'Approval access to your department';
      case AttendancePermission.approveAllDepartments:
        return 'Full approval access to all departments';
    }
  }
}

/// Service to manage user permissions and data
class UserPermissionsService {
  UserPermissionsService(this._api, this._authRepo);

  final ApiClient _api;
  final AuthRepository _authRepo;

  UserData? _currentUser;
  DateTime? _lastFetchTime;

  static const Duration _cacheDuration = Duration(minutes: 30);

  /// Get current user data, fetching if necessary
  Future<UserData?> getCurrentUser() async {
    // 1. Always fetch the authoritative User ID from storage first.
    final userId = await _authRepo.getCurrentAppUserId();

    if (_currentUser != null &&
        userId != null &&
        _currentUser!.userId == userId && // Ensure cache matches current login
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      debugPrint('Returning cached user data');
      return _currentUser;
    }

    try {
      debugPrint('Current user ID from auth repo: $userId');
      if (userId == null) {
        clearUser(); // Clear cache if no user is logged in
        debugPrint('No user ID found in auth repository');
        return null;
      }

      // Fetch full user data from API
      debugPrint('Fetching user data from API for user ID: $userId');
      final userData = await _api.getJson(
        "/items/user/$userId",
        query: {"fields": "user_id,user_department,isAdmin,user_fname,user_lname"},
      );

      debugPrint('User data received from API: $userData');
      final user = UserData.fromJson(userData["data"] as Map<String, dynamic>);
      _currentUser = user;
      _lastFetchTime = DateTime.now();

      debugPrint(
        'User data parsed successfully: ${user.displayName}, dept: ${user.departmentId}, admin: ${user.isAdmin}',
      );
      return _currentUser;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  /// Set current user data (called after login)
  void setCurrentUser(UserData user) {
    _currentUser = user;
    _lastFetchTime = DateTime.now();
  }

  /// Clear user data (called on logout)
  void clearUser() {
    _currentUser = null;
    _lastFetchTime = null;
  }

  /// Validate user permissions and return appropriate error message if invalid
  String? validateUserPermissions(UserData user) {
    // Check for missing department
    if (user.departmentId == null) {
      return 'Missing department data. Please contact administrator.';
    }

    // Check for multiple departments (if API returns inconsistent data)
    // This would need to be implemented based on actual API response structure
    // For now, assume single department per user

    // Check if user has any permissions
    final permission = user.getAttendancePermission();
    if (permission == AttendancePermission.none) {
      return 'No permissions for attendance approvals.';
    }

    return null; // Valid permissions
  }
}

/// Riverpod provider for user permissions service
final userPermissionsServiceProvider = Provider<UserPermissionsService>((ref) {
  final api = ref.read(apiClientProvider);
  final authRepo = ref.read(authRepositoryProvider);
  return UserPermissionsService(api, authRepo);
});

/// Riverpod provider for current user data
final currentUserProvider = FutureProvider.autoDispose<UserData?>((ref) {
  final service = ref.watch(userPermissionsServiceProvider);
  return service.getCurrentUser();
});

/// Riverpod provider for current user permissions
final userPermissionsProvider = FutureProvider.autoDispose<AttendancePermission>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  return user?.getAttendancePermission() ?? AttendancePermission.none;
});
