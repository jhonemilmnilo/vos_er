// lib/modules/approvals/approval_view.dart
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../app.dart";
import "../../core/auth/user_permissions.dart";
import "../../data/repositories/attendance_repository.dart";
import "../../data/repositories/leave_repository.dart";
import "../../data/repositories/overtime_repository.dart";
// import '../../data/repositories/leave_repository.dart';
import "attendance/attendance_view.dart";
import 'leave/leave_view.dart';
import "overtime/overtime_view.dart";

class ApprovalView extends ConsumerStatefulWidget {
  const ApprovalView({super.key});

  @override
  ConsumerState<ApprovalView> createState() => _ApprovalViewState();
}

class _ApprovalViewState extends ConsumerState<ApprovalView> {
  // Stock Transfer badge
  bool _stLoading = true;
  String? _stError;
  int _requestedCount = 0;

  // Sales Order badge
  bool _soLoading = true;
  String? _soError;
  int _soForApprovalCount = 0;

  // Overtime badge
  bool _otLoading = true;
  String? _otError;
  int _otPendingCount = 0;

  // Disbursement badge
  bool _dbLoading = true;
  String? _dbError;
  int _dbPendingCount = 0;

  // Dispatch Plan badge
  bool _dpLoading = true;
  String? _dpError;
  int _dpPendingCount = 0;

  // Attendance badge
  bool _atLoading = true;
  String? _atError;
  int _atPendingCount = 0;

  // Leave badge
  bool _lvLoading = true;
  String? _lvError;
  int _lvPendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<List<int>?> _getAllowedDepartmentIds() async {
    try {
      final service = ref.read(userPermissionsServiceProvider);
      final user = await service.getCurrentUser();
      if (user == null) return null;

      final permission = user.getAttendancePermission();
      switch (permission) {
        case AttendancePermission.none:
          return [];
        case AttendancePermission.readOwnDepartment:
        case AttendancePermission.approveOwnDepartment:
          return user.departmentId != null ? [user.departmentId!] : [];
        case AttendancePermission.readAllDepartments:
        case AttendancePermission.approveAllDepartments:
          return null; // null means all departments
      }
    } catch (e) {
      debugPrint('Error getting user permissions: $e');
      return null;
    }
    // return null;
  }

  Future<void> _loadCounts() async {
    setState(() {
      _stLoading = true;
      _stError = null;

      _soLoading = true;
      _soError = null;

      _otLoading = true;
      _otError = null;

      _dbLoading = true;
      _dbError = null;

      _dpLoading = true;
      _dpError = null;

      _atLoading = true;
      _atError = null;

      _lvLoading = true;
      _lvError = null;
    });

    final api = ref.read(apiClientProvider);

    final otRepo = OvertimeRepository(api);
    final lvRepo = LeaveRepository(api);

    final atRepo = AttendanceRepository(api);

    // Run in parallel, but isolate failures cleanly.
    // final stFuture = stRepo.fetchRequestedHeaderCount();

    final otFuture = otRepo.fetchOvertimePendingCount();
    final lvFuture = lvRepo.fetchLeavePendingCount();

    // Pending disbursements: approver_id IS NULL AND date_approved IS NULL

    // Dispatch Plan: use paged fetch with limit=1 to get total count from meta

    // Attendance: fetch pending count filtered by user permissions (same as attendance_view)
    final atFuture = Future<int>(() async {
      try {
        final allowedIds = await _getAllowedDepartmentIds();
        final page = await atRepo.fetchAttendanceApprovalsPaged(
          status: "pending",
          search: null,
          limit: -1, // Load all to match attendance_view logic
          offset: 0,
          allowedDepartmentIds: allowedIds,
        );

        // Group by employee and sum pendingCount, same as attendance_view
        final Map<int, List<dynamic>> grouped = {};
        for (final item in page.items) {
          grouped.putIfAbsent(item.employeeId, () => []).add(item);
        }

        int totalPending = 0;
        for (final entries in grouped.values) {
          totalPending += entries.length;
        }

        return totalPending;
      } catch (e) {
        debugPrint('Error loading attendance count: $e');
        return 0;
      }
    });

    final results = await Future.wait([
      Future.value(0), // stFuture placeholder
      Future.value(0), // soFuture placeholder
      otFuture.catchError((e) => 0),
      lvFuture.catchError((e) => 0),
      Future.value(0), // dbFuture placeholder
      Future.value(0), // dpFuture placeholder
      atFuture,
    ]);

    if (!mounted) return;

    // Stock Transfer result
    final stRes = results[0];
    _requestedCount = stRes;
    _stLoading = false;
    _stError = null;

    // Sales Order result
    final soRes = results[1];
    _soForApprovalCount = soRes;
    _soLoading = false;
    _soError = null;

    // Overtime result
    final otRes = results[2];
    _otPendingCount = otRes;
    _otLoading = false;
    _otError = null;

    // Leave result
    final lvRes = results[3];
    _lvPendingCount = lvRes;
    _lvLoading = false;
    _lvError = null;

    // Disbursement result
    final dbRes = results[4];
    _dbPendingCount = dbRes;
    _dbLoading = false;
    _dbError = null;

    // Dispatch Plan result
    final dpRes = results[5];
    _dpPendingCount = dpRes;
    _dpLoading = false;
    _dpError = null;

    // Attendance result
    final atRes = results[6];
    _atPendingCount = atRes;
    _atLoading = false;
    _atError = null;

    setState(() {});
  }

  int get _totalPending =>
      _requestedCount +
      _soForApprovalCount +
      _otPendingCount +
      _lvPendingCount +
      _dbPendingCount +
      _dpPendingCount +
      _atPendingCount;

  bool get _hasErrors =>
      _stError != null ||
      _soError != null ||
      _otError != null ||
      _lvError != null ||
      _dbError != null ||
      _dpError != null ||
      _atError != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCounts,
          child: CustomScrollView(
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 5, 50, 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text(
                      //   "",
                      //   style: theme.textTheme.headlineMedium?.copyWith(
                      //     fontWeight: FontWeight.w700,
                      //     letterSpacing: -0.5,
                      //   ),
                      // ),
                      const SizedBox(height: 8),
                      if (_stLoading ||
                          _soLoading ||
                          _otLoading ||
                          _dbLoading ||
                          _dpLoading ||
                          _atLoading)
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Refreshing counts...",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _totalPending > 0
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _totalPending > 0
                                        ? Icons.notification_important_rounded
                                        : Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: _totalPending > 0
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _totalPending > 0
                                        ? "$_totalPending pending approval${_totalPending > 1 ? 's' : ''}"
                                        : "All caught up",
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: _totalPending > 0
                                          ? cs.onPrimaryContainer
                                          : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // Error Messages
              if (_hasErrors)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      children: [
                        if (_stError != null) _InlineError(message: "Stock Transfer: $_stError"),
                        if (_stError != null &&
                            (_soError != null || _otError != null || _dbError != null))
                          const SizedBox(height: 8),
                        if (_soError != null) _InlineError(message: "Sales Order: $_soError"),
                        if (_soError != null && (_otError != null || _dbError != null))
                          const SizedBox(height: 8),
                        if (_otError != null) _InlineError(message: "Overtime: $_otError"),
                        if (_otError != null && (_lvError != null || _dbError != null))
                          const SizedBox(height: 8),
                        if (_lvError != null) _InlineError(message: "Leave: $_lvError"),
                        if (_lvError != null && _dbError != null) const SizedBox(height: 8),
                        if (_dbError != null) _InlineError(message: "Disbursement: $_dbError"),
                        if (_dbError != null && _dpError != null) const SizedBox(height: 8),
                        if (_dpError != null) _InlineError(message: "Dispatch Plan: $_dpError"),
                        if (_dpError != null && _atError != null) const SizedBox(height: 8),
                        if (_atError != null) _InlineError(message: "Attendance: $_atError"),
                      ],
                    ),
                  ),
                ),

              // Approval Cards
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _ApprovalCard(
                      title: "Overtime",
                      subtitle: "Review pending overtime requests",
                      icon: Icons.work_rounded,
                      iconColor: const Color(0xFF059669),
                      iconBackground: const Color(0xFFD1FAE5),
                      loading: _otLoading,
                      badgeCount: _otPendingCount,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const OvertimeApprovalView()));
                      },
                    ),
                    const SizedBox(height: 12),
                    _ApprovalCard(
                      title: "Leave",
                      subtitle: "Review pending leave requests",
                      icon: Icons.beach_access_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      iconBackground: const Color(0xFFF3E8FF),
                      loading: _lvLoading,
                      badgeCount: _lvPendingCount,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const LeaveApprovalView()));
                      },
                    ),
                    const SizedBox(height: 12),
                    _ApprovalCard(
                      title: "Attendance",
                      subtitle: "Review attendance discrepancies",
                      icon: Icons.access_time_rounded,
                      iconColor: const Color(0xFFDC2626),
                      iconBackground: const Color(0xFFFEE2E2),
                      loading: _atLoading,
                      badgeCount: _atPendingCount,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const AttendanceApprovalView()));
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final bool loading;
  final int badgeCount;
  final VoidCallback onTap;

  const _ApprovalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.loading,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (!loading && badgeCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                badgeCount > 99 ? "99+" : "$badgeCount",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (loading)
                        Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Loading...",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: badgeCount > 0 ? iconColor : cs.outline,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              badgeCount == 0 ? "No pending requests" : "$badgeCount pending",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: badgeCount > 0 ? iconColor : cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
