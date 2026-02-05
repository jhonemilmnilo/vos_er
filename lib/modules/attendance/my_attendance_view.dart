// lib/modules/attendance/my_attendance_view.dart
import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:vos_er/app_providers.dart";

import "../../data/repositories/attendance_repository.dart";
import "../../data/repositories/overtime_repository.dart";
import "../approvals/attendance/attendance_model.dart";
import "../approvals/overtime/overtime_filing_sheet.dart";

/// Page for users to view their own attendance history and file overtime
class MyAttendanceView extends ConsumerStatefulWidget {
  const MyAttendanceView({super.key});

  @override
  ConsumerState<MyAttendanceView> createState() => _MyAttendanceViewState();
}

class _MyAttendanceViewState extends ConsumerState<MyAttendanceView> {
  final ScrollController _scrollCtrl = ScrollController();

  bool _loading = true;
  String? _error;
  bool _loadingMore = false;
  bool _hasMore = true;

  late final AttendanceRepository _repo;
  late final OvertimeRepository _overtimeRepo;

  final List<AttendanceApprovalHeader> _items = [];
  final Set<int> _logIdsWithOT = {}; // Track which log_ids have OT requests
  final int _limit = 20;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _repo = AttendanceRepository(ref.read(apiClientProvider));
    _overtimeRepo = OvertimeRepository(ref.read(apiClientProvider));
    _scrollCtrl.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _logIdsWithOT.clear();
      _offset = 0;
      _hasMore = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final userId = await authRepo.getCurrentAppUserId();

      if (userId == null) {
        throw Exception("User not logged in");
      }

      final userIdInt = userId;

      final page = await _repo.fetchMyAttendancePaged(
        userId: userIdInt,
        limit: _limit,
        offset: _offset,
        period: "current",
      );

      if (!mounted) return;

      // Fetch log_ids that have existing OT requests
      final logIds = page.items.map((item) => item.approvalId).toList();
      final logIdsWithOT = await _repo.getLogIdsWithOvertimeRequestsForUser(userIdInt, logIds);

      setState(() {
        _items.addAll(page.items);
        _logIdsWithOT.addAll(logIdsWithOT);
        _offset += page.items.length;
        _hasMore = page.items.length == _limit;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() {
      _loadingMore = true;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final userId = await authRepo.getCurrentAppUserId();

      if (userId == null) {
        throw Exception("User not logged in");
      }

      final userIdInt = userId;

      final page = await _repo.fetchMyAttendancePaged(
        userId: userIdInt,
        limit: _limit,
        offset: _offset,
        period: "current",
      );

      if (!mounted) return;

      // Fetch log_ids that have existing OT requests
      final logIds = page.items.map((item) => item.approvalId).toList();
      final logIdsWithOT = await _repo.getLogIdsWithOvertimeRequestsForUser(userIdInt, logIds);

      setState(() {
        _items.addAll(page.items);
        _logIdsWithOT.addAll(logIdsWithOT);
        _offset += page.items.length;
        _hasMore = page.items.length == _limit;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMore = false;
      });
    }
  }

  Future<void> _openOvertimeFilingSheet(AttendanceApprovalHeader attendance) async {
    final schedEnd = attendance.scheduleEnd;
    final actualEnd = attendance.actualEnd;

    if (schedEnd == null || actualEnd == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Missing schedule or actual time data")));
      return;
    }

    HapticFeedback.selectionClick();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OvertimeFilingSheet(
        userId: attendance.employeeId,
        departmentId: attendance.departmentId,
        requestDate: attendance.dateSchedule,
        otFrom: schedEnd,
        otTo: TimeOfDay(hour: actualEnd.hour, minute: actualEnd.minute),
        schedTimeout: schedEnd,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Overtime request filed successfully"),
          backgroundColor: Colors.green,
        ),
      );
      _reload(); // Reload to refresh the list
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const backgroundColor = Color(0xFFF8F9FC);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'My Attendance',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: cs.primary,
        backgroundColor: Colors.white,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _reload)
            : _items.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(20),
                itemCount: _items.length + 1,
                itemBuilder: (context, i) {
                  if (i == _items.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 32),
                      child: Center(
                        child: _loadingMore
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : (!_hasMore
                                  ? Text(
                                      "End of list",
                                      style: TextStyle(
                                        color: cs.outline,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : const SizedBox.shrink()),
                      ),
                    );
                  }

                  final attendance = _items[i];
                  final hasExistingOT = _logIdsWithOT.contains(attendance.approvalId);

                  // Calculate time between work_end and time_out
                  bool canFileOT = false;
                  if (!hasExistingOT &&
                      attendance.scheduleEnd != null &&
                      attendance.actualEnd != null) {
                    final schedEnd = attendance.scheduleEnd!;
                    final actualEnd = attendance.actualEnd!;

                    // Convert TimeOfDay to DateTime for comparison
                    final schedEndDateTime = DateTime(
                      attendance.dateSchedule.year,
                      attendance.dateSchedule.month,
                      attendance.dateSchedule.day,
                      schedEnd.hour,
                      schedEnd.minute,
                    );

                    // Check if actual end is after scheduled end
                    if (actualEnd.isAfter(schedEndDateTime)) {
                      final overtimeMinutes = actualEnd.difference(schedEndDateTime).inMinutes;
                      canFileOT = overtimeMinutes >= 90;
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _AttendanceCard(
                      attendance: attendance,
                      canFileOT: canFileOT,
                      hasExistingOT: hasExistingOT,
                      onFileOT: canFileOT ? () => _openOvertimeFilingSheet(attendance) : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final AttendanceApprovalHeader attendance;
  final bool canFileOT;
  final bool hasExistingOT;
  final VoidCallback? onFileOT;

  const _AttendanceCard({
    required this.attendance,
    required this.canFileOT,
    required this.hasExistingOT,
    this.onFileOT,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Determine if we should show the OT icon
    final showOTIcon = canFileOT && onFileOT != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2937).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  attendance.dateScheduleLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                if (showOTIcon)
                  IconButton(
                    onPressed: onFileOT,
                    icon: const Icon(Icons.access_time_filled_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange.withOpacity(0.15),
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.all(8),
                    ),
                    tooltip: "File Overtime Request",
                  )
                else if (hasExistingOT)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          "OT Requested",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Time In/Out
            Row(
              children: [
                Expanded(
                  child: _InfoColumn(
                    label: "Time In",
                    value: formatDateTimeToTime(attendance.actualStart),
                    icon: Icons.login_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoColumn(
                    label: "Time Out",
                    value: formatDateTimeToTime(attendance.actualEnd),
                    icon: Icons.logout_rounded,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 12),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: "Late",
                    value: "${attendance.lateMinutes}m",
                    color: attendance.lateMinutes > 0 ? Colors.red : cs.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: "Under",
                    value: "${attendance.undertimeMinutes}m",
                    color: attendance.undertimeMinutes > 0 ? Colors.orange : cs.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: "Over",
                    value: "${attendance.overtimeMinutes}m",
                    color: attendance.overtimeMinutes > 0 ? Colors.blue : cs.outline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: "Total",
                    value: attendance.workMinutesLabel,
                    color: cs.primary,
                    isBold: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_available_rounded, size: 48, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              "No Attendance Records",
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Your attendance records will appear here",
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              "Sync Failed",
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Try Again"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
