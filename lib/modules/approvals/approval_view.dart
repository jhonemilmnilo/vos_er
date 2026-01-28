// lib/modules/approvals/approval_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/auth/user_permissions.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/leave_repository.dart';
import '../../data/repositories/overtime_repository.dart';
import 'attendance/attendance_view.dart';
import 'leave/leave_view.dart';
import 'overtime/overtime_view.dart';

// ============================================================================
// Domain Models (UNCHANGED)
// ============================================================================

@immutable
class ApprovalCount {
  final bool isLoading;
  final int count;
  final String? error;

  const ApprovalCount({this.isLoading = true, this.count = 0, this.error});

  ApprovalCount copyWith({bool? isLoading, int? count, String? error}) {
    return ApprovalCount(
      isLoading: isLoading ?? this.isLoading,
      count: count ?? this.count,
      error: error ?? this.error,
    );
  }

  bool get hasError => error != null;
  bool get hasPending => count > 0;
}

@immutable
class ApprovalState {
  final ApprovalCount overtime;
  final ApprovalCount leave;
  final ApprovalCount attendance;

  const ApprovalState({
    this.overtime = const ApprovalCount(),
    this.leave = const ApprovalCount(),
    this.attendance = const ApprovalCount(),
  });

  int get totalPending => overtime.count + leave.count + attendance.count;
  bool get isLoading => overtime.isLoading || leave.isLoading || attendance.isLoading;
  bool get hasErrors => overtime.hasError || leave.hasError || attendance.hasError;

  List<String> get errorMessages {
    final errors = <String>[];
    if (overtime.hasError) errors.add('Overtime: ${overtime.error}');
    if (leave.hasError) errors.add('Leave: ${leave.error}');
    if (attendance.hasError) errors.add('Attendance: ${attendance.error}');
    return errors;
  }

  ApprovalState copyWith({
    ApprovalCount? overtime,
    ApprovalCount? leave,
    ApprovalCount? attendance,
  }) {
    return ApprovalState(
      overtime: overtime ?? this.overtime,
      leave: leave ?? this.leave,
      attendance: attendance ?? this.attendance,
    );
  }
}

@immutable
class ApprovalCardConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Widget Function(BuildContext) destinationBuilder;

  const ApprovalCardConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.destinationBuilder,
  });
}

// ============================================================================
// Main View
// ============================================================================

class ApprovalView extends ConsumerStatefulWidget {
  const ApprovalView({super.key});

  @override
  ConsumerState<ApprovalView> createState() => _ApprovalViewState();
}

class _ApprovalViewState extends ConsumerState<ApprovalView> {
  ApprovalState _state = const ApprovalState();

  /// Approval card configurations
  static const _approvalCards = [
    ApprovalCardConfig(
      title: 'Overtime',
      subtitle: 'Review pending overtime requests',
      icon: Icons.access_time_filled_rounded,
      iconColor: Color(0xFF059669), // Emerald 600
      iconBackground: Color(0xFFD1FAE5), // Emerald 100
      destinationBuilder: _buildOvertimeView,
    ),
    ApprovalCardConfig(
      title: 'Leave',
      subtitle: 'Review pending leave requests',
      icon: Icons.calendar_month_rounded,
      iconColor: Color(0xFF7C3AED), // Violet 600
      iconBackground: Color(0xFFEDE9FE), // Violet 100
      destinationBuilder: _buildLeaveView,
    ),
    ApprovalCardConfig(
      title: 'Attendance',
      subtitle: 'Review attendance discrepancies',
      icon: Icons.co_present_rounded,
      iconColor: Color(0xFFDC2626), // Red 600
      iconBackground: Color(0xFFFEE2E2), // Red 100
      destinationBuilder: _buildAttendanceView,
    ),
  ];

  static Widget _buildOvertimeView(BuildContext context) => const OvertimeApprovalView();
  static Widget _buildLeaveView(BuildContext context) => const LeaveApprovalView();
  static Widget _buildAttendanceView(BuildContext context) => const AttendanceApprovalView();

  @override
  void initState() {
    super.initState();
    _loadApprovalCounts();
  }

  // --- LOGIC SECTION (UNCHANGED) ---

  Future<List<int>?> _getAllowedDepartmentIds() async {
    try {
      final service = ref.read(userPermissionsServiceProvider);
      final user = await service.getCurrentUser();
      if (user == null) return null;

      // Special rule for department 6 (can see all departments like department 2)
      if (user.departmentId == 6) {
        // Department 6 can see all departments
        return null;
      } else {
        // For other departments, users can only see their own department
        return user.departmentId != null ? [user.departmentId!] : [];
      }
    } catch (e) {
      debugPrint('Failed to retrieve user permissions: $e');
      return null;
    }
  }

  Future<int> _fetchAttendanceCount() async {
    final api = ref.read(apiClientProvider);
    final repo = AttendanceRepository(api);
    final allowedDepartmentIds = await _getAllowedDepartmentIds();

    final page = await repo.fetchAttendanceApprovalsPaged(
      status: 'pending',
      search: null,
      limit: -1,
      offset: 0,
      allowedDepartmentIds: allowedDepartmentIds,
    );

    final groupedByEmployee = <int, List<dynamic>>{};
    for (final item in page.items) {
      groupedByEmployee.putIfAbsent(item.employeeId, () => []).add(item);
    }

    return groupedByEmployee.values.fold<int>(0, (total, items) => total + items.length);
  }

  Future<int> _fetchOvertimeCount() async {
    final api = ref.read(apiClientProvider);
    final repo = OvertimeRepository(api);
    final allowedDepartmentIds = await _getAllowedDepartmentIds();

    final page = await repo.fetchOvertimeApprovalsPaged(
      status: 'pending',
      search: null,
      limit: -1,
      offset: 0,
      allowedDepartmentIds: allowedDepartmentIds,
    );

    return page.items.length;
  }

  Future<int> _fetchLeaveCount() async {
    final api = ref.read(apiClientProvider);
    final repo = LeaveRepository(api);
    final allowedDepartmentIds = await _getAllowedDepartmentIds();

    final page = await repo.fetchLeaveApprovalsPaged(
      status: 'pending',
      search: null,
      limit: -1,
      offset: 0,
      allowedDepartmentIds: allowedDepartmentIds,
    );

    return page.items.length;
  }

  Future<void> _loadApprovalCounts() async {
    setState(() => _state = const ApprovalState());

    final results = await Future.wait([
      _safeExecute(_fetchOvertimeCount),
      _safeExecute(_fetchLeaveCount),
      _safeExecute(_fetchAttendanceCount),
    ]);

    if (!mounted) return;

    setState(() {
      _state = ApprovalState(
        overtime: _buildApprovalCount(results[0]),
        leave: _buildApprovalCount(results[1]),
        attendance: _buildApprovalCount(results[2]),
      );
    });
  }

  Future<_AsyncResult<int>> _safeExecute(Future<int> Function() operation) async {
    try {
      final count = await operation();
      return _AsyncResult.success(count);
    } catch (e) {
      debugPrint('Error loading approval count: $e');
      return _AsyncResult.failure('Failed to load');
    }
  }

  ApprovalCount _buildApprovalCount(_AsyncResult<int> result) {
    return ApprovalCount(isLoading: false, count: result.data ?? 0, error: result.error);
  }

  // --- UI SECTION (AESTHETIC UPGRADE) ---

  @override
  Widget build(BuildContext context) {
    // Using a slightly off-white background makes white cards pop more
    const backgroundColor = Color(0xFFF8F9FC);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadApprovalCounts,
        edgeOffset: 120,
        backgroundColor: Colors.white,
        color: Theme.of(context).primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context, backgroundColor),
            _buildSummaryHeader(context),
            if (_state.hasErrors) _buildErrorSection(context),
            _buildApprovalList(context),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Color backgroundColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverAppBar.large(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 110,
      pinned: true,
      centerTitle: false,
      title: Text(
        'Approvals',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -0.8, // Tighter tracking for modern look
          fontSize: 32,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: _state.isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.primary),
                )
              : IconButton.filledTonal(
                  onPressed: _loadApprovalCounts,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: colorScheme.onSurfaceVariant,
                    elevation: 0,
                    side: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: _DashboardStatusCard(totalPending: _state.totalPending, isLoading: _state.isLoading),
      ),
    );
  }

  Widget _buildErrorSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: _state.errorMessages
              .map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ErrorCard(message: message),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildApprovalList(BuildContext context) {
    final approvalCounts = [_state.overtime, _state.leave, _state.attendance];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final config = _approvalCards[index];
          final count = approvalCounts[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PremiumApprovalCard(
              config: config,
              approvalCount: count,
              onTap: () => _navigateToApprovalView(config.destinationBuilder(context)),
            ),
          );
        }, childCount: _approvalCards.length),
      ),
    );
  }

  void _navigateToApprovalView(Widget destination) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
  }
}

// ============================================================================
// Result Type (UNCHANGED)
// ============================================================================

@immutable
class _AsyncResult<T> {
  final T? data;
  final String? error;

  const _AsyncResult._({this.data, this.error});

  factory _AsyncResult.success(T data) => _AsyncResult._(data: data);
  factory _AsyncResult.failure(String error) => _AsyncResult._(error: error);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}

// ============================================================================
// Aesthetic UI Components
// ============================================================================

class _DashboardStatusCard extends StatelessWidget {
  final int totalPending;
  final bool isLoading;

  const _DashboardStatusCard({required this.totalPending, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPending = totalPending > 0;

    return Container(
      width: double.infinity,
      height: 140, // Fixed height for consistent layout
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hasPending ? null : Colors.white,
        gradient: hasPending
            ? LinearGradient(
                colors: [
                  colorScheme.primary,
                  Color.lerp(colorScheme.primary, Colors.black, 0.1)!,
                  colorScheme.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.6, 1.0],
              )
            : null,
        borderRadius: BorderRadius.circular(28),
        boxShadow: hasPending
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: -5,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
        border: hasPending ? null : Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          // Decorative Background Element
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              hasPending ? Icons.mark_email_unread_rounded : Icons.check_circle_rounded,
              size: 140,
              color: hasPending
                  ? Colors.white.withOpacity(0.15)
                  : colorScheme.surfaceContainerHigh.withOpacity(0.5),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasPending
                            ? Colors.white.withOpacity(0.2)
                            : colorScheme.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasPending ? Icons.notifications_active : Icons.check,
                        color: hasPending ? Colors.white : colorScheme.onSurfaceVariant,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Status Overview',
                      style: TextStyle(
                        color: hasPending
                            ? Colors.white.withOpacity(0.9)
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                // Main Stats
                if (isLoading)
                  _buildLoadingState(hasPending)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPending ? '$totalPending' : 'All Clear',
                        style: TextStyle(
                          color: hasPending ? Colors.white : colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasPending
                            ? 'Request${totalPending == 1 ? '' : 's'} awaiting your review'
                            : 'You are all caught up for today',
                        style: TextStyle(
                          color: hasPending
                              ? Colors.white.withOpacity(0.8)
                              : colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool hasPending) {
    return SizedBox(
      height: 24,
      width: 24,
      child: CircularProgressIndicator(strokeWidth: 2, color: hasPending ? Colors.white : null),
    );
  }
}

class _PremiumApprovalCard extends StatelessWidget {
  final ApprovalCardConfig config;
  final ApprovalCount approvalCount;
  final VoidCallback onTap;

  const _PremiumApprovalCard({
    required this.config,
    required this.approvalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPending = !approvalCount.isLoading && approvalCount.count > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // Soft, diffused shadow for "floating" effect
          BoxShadow(
            color: const Color(0xFF1F2937).withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: config.iconColor.withOpacity(0.05),
          highlightColor: config.iconColor.withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon Section
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: config.iconBackground,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(config.icon, color: config.iconColor, size: 28),
                ),
                const SizedBox(width: 20),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          height: 1.1,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        config.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Trailing Status
                if (approvalCount.isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.outline.withOpacity(0.3),
                    ),
                  )
                else if (hasPending)
                  Container(
                    constraints: const BoxConstraints(minWidth: 28),
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: config.iconColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: config.iconColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '${approvalCount.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: colorScheme.outline.withOpacity(0.5),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
