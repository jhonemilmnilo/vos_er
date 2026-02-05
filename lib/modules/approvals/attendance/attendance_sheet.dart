import "package:flutter/material.dart";
import "package:flutter/services.dart"; // Added for Haptics
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../app_providers.dart"; // apiClientProvider, authRepositoryProvider
import "../../../core/auth/user_permissions.dart";
import "../../../data/repositories/attendance_repository.dart" hide formatTimeOfDay;
import "../overtime/overtime_filing_sheet.dart";
import "attendance_model.dart";

class AttendanceApprovalSheet extends ConsumerStatefulWidget {
  const AttendanceApprovalSheet({super.key, required this.group});

  final AttendanceApprovalGroup group;

  @override
  ConsumerState<AttendanceApprovalSheet> createState() => _AttendanceApprovalSheetState();
}

class _AttendanceApprovalSheetState extends ConsumerState<AttendanceApprovalSheet> {
  bool _processing = false;
  String? _error;
  final Set<int> _selectedLogIds = {};

  // Track if current user has permission (loaded async or from user object)
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    // No items pre-selected by default
  }

  Future<_ApproverInfo> _loadApproverInfo(AttendanceRepository attendanceRepo) async {
    final approverIdRaw = await ref.read(authRepositoryProvider).getCurrentAppUserId();

    if (approverIdRaw == null) {
      throw Exception("Invalid approverId from authRepositoryProvider: null");
    }

    final int approverId = (approverIdRaw is int)
        ? approverIdRaw
        : int.tryParse(approverIdRaw.toString()) ?? 0;

    if (approverId <= 0) {
      throw Exception("Invalid approverId from authRepositoryProvider: $approverIdRaw");
    }

    final Map<int, AppUserLite> approverMap = await attendanceRepo.fetchUsersByIds(<int>[
      approverId,
    ]);

    final String approverName = approverMap[approverId]?.displayName ?? "Unknown Approver";

    return _ApproverInfo(id: approverId, name: approverName);
  }

  void _toggleSelection(int logId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedLogIds.contains(logId)) {
        _selectedLogIds.remove(logId);
      } else {
        _selectedLogIds.add(logId);
      }
    });
  }

  void _toggleSelectAll(bool selectAll) {
    HapticFeedback.lightImpact();
    setState(() {
      if (selectAll) {
        _selectedLogIds.addAll(
          widget.group.pendingApprovals.map((approval) => approval.approvalId),
        );
      } else {
        _selectedLogIds.clear();
      }
    });
  }

  Future<void> _approveSelected() async {
    if (_processing || _selectedLogIds.isEmpty) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // Check user permissions before approving
      final service = ref.read(userPermissionsServiceProvider);
      final user = await service.getCurrentUser();
      final departmentId = widget.group.pendingApprovals.first.departmentId;

      if (user == null || !user.canApproveDepartment(departmentId)) {
        setState(() {
          _error = "Permission denied: You cannot approve for this department.";
          _processing = false;
          _hasPermission = false;
        });
        return;
      }

      final api = ref.read(apiClientProvider);
      final attendanceRepo = AttendanceRepository(api);

      final approver = await _loadApproverInfo(attendanceRepo);

      final approvedLogIds = await attendanceRepo.approveSelectedAttendance(
        logIds: _selectedLogIds.toList(),
        employeeId: widget.group.employeeId,
        approverId: approver.id,
        approverName: approver.name,
      );

      if (!mounted) return;

      if (approvedLogIds.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("No attendance records were approved.")));
      } else {
        HapticFeedback.mediumImpact();
      }

      // Close the sheet and return success
      Navigator.of(context).pop(
        AttendanceApproveOutcome(
          approvalId: widget.group.pendingApprovals.first.approvalId, // Representative ID
          newStatus: AttendanceStatus.approved,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _processing = false;
      });
    }
  }

  Future<void> _openOvertimeFilingSheet(AttendanceApprovalHeader approval) async {
    // Check if user is not admin
    final user = ref.read(currentUserProvider).value;
    if (user == null || user.isAdmin) {
      return; // Only non-admin users can file overtime
    }

    // Check if overtime exceeds 90 minutes (1h 30m)
    if (approval.overtimeMinutes < 90) {
      return; // Not enough overtime to file
    }

    // Calculate OT times
    final schedEnd = approval.scheduleEnd;
    final actualEnd = approval.actualEnd;

    if (schedEnd == null || actualEnd == null) {
      return; // Missing required data
    }

    HapticFeedback.selectionClick();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OvertimeFilingSheet(
        userId: widget.group.employeeId,
        departmentId: approval.departmentId,
        requestDate: approval.dateSchedule,
        otFrom: schedEnd, // OT starts at scheduled end time
        otTo: TimeOfDay(hour: actualEnd.hour, minute: actualEnd.minute),
        schedTimeout: schedEnd,
      ),
    );

    if (result == true && mounted) {
      // Overtime filed successfully, optionally reload
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Overtime request filed successfully"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalItems = widget.group.pendingApprovals.length;
    final selectedCount = _selectedLogIds.length;
    final isAllSelected = totalItems > 0 && selectedCount == totalItems;

    final user = ref.watch(currentUserProvider).value;
    final canApprove =
        user?.canApproveDepartment(widget.group.pendingApprovals.first.departmentId) ?? false;

    double getSheetHeight() {
      final screenHeight = MediaQuery.of(context).size.height;
      if (screenHeight < 600) return screenHeight * 0.8;
      if (screenHeight < 800) return screenHeight * 0.7;
      return screenHeight * 0.6;
    }

    return SizedBox(
      height: getSheetHeight(),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Review Attendance",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        widget.group.employeeName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.group.pendingApprovals.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Schedule: ${widget.group.pendingApprovals.first.scheduleLabel}",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 32, thickness: 1),

            // Scrollable Content
            Expanded(
              child: widget.group.pendingApprovals.isEmpty
                  ? Center(
                      child: Text("No pending logs", style: TextStyle(color: cs.outline)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Bottom padding for FAB
                      children: [
                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                            ),
                          ),

                        // Selection Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "$selectedCount of $totalItems selected",
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _toggleSelectAll(!isAllSelected),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(isAllSelected ? "Deselect All" : "Select All"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // List Items
                        ...widget.group.pendingApprovals.map((approval) {
                          final isSelected = _selectedLogIds.contains(approval.approvalId);
                          return _AttendanceLogCard(
                            approval: approval,
                            isSelected: isSelected,
                            onTap: () => _toggleSelection(approval.approvalId),
                            onFileOvertime: () => _openOvertimeFilingSheet(approval),
                            userId: widget.group.employeeId,
                            departmentId: approval.departmentId,
                          );
                        }),
                      ],
                    ),
            ),

            // Bottom Action Bar
            if (canApprove)
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _processing || selectedCount == 0 ? null : _approveSelected,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _processing
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
                          )
                        : Text(
                            "Approve $selectedCount Log${selectedCount == 1 ? '' : 's'}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ApproverInfo {
  final int id;
  final String name;
  const _ApproverInfo({required this.id, required this.name});
}

// ============================================================================
// UI Components
// ============================================================================

class _AttendanceLogCard extends StatelessWidget {
  final AttendanceApprovalHeader approval;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onFileOvertime;
  final int userId;
  final int departmentId;

  const _AttendanceLogCard({
    required this.approval,
    required this.isSelected,
    required this.onTap,
    this.onFileOvertime,
    required this.userId,
    required this.departmentId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? cs.primaryContainer.withOpacity(0.3) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? cs.primary : Colors.transparent, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox visual
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? cs.primary : cs.outline.withOpacity(0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isSelected ? Icon(Icons.check, size: 16, color: cs.onPrimary) : null,
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        approval.dateScheduleLabel,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 12),

                      // Data Grid
                      Row(
                        children: [
                          Expanded(
                            child: _DataColumn(
                              label: "Time In",
                              value: formatDateTimeToTime(approval.actualStart),
                              icon: Icons.login_rounded,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DataColumn(
                              label: "Time Out",
                              value: formatDateTimeToTime(approval.actualEnd),
                              icon: Icons.logout_rounded,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatItem(label: "Late", value: "${approval.lateMinutes}m"),
                          ),
                          Expanded(
                            child: _StatItem(
                              label: "Under",
                              value: "${approval.undertimeMinutes}m",
                            ),
                          ),
                          Expanded(
                            child: _StatItem(label: "Over", value: "${approval.overtimeMinutes}m"),
                          ),
                          Expanded(
                            child: _StatItem(
                              label: "Total",
                              value: approval.workMinutesLabel,
                              isBold: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Overtime Icon Button (show if overtime >= 90 minutes and callback provided)
                if (onFileOvertime != null && approval.overtimeMinutes >= 90)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: IconButton(
                      onPressed: onFileOvertime,
                      icon: const Icon(Icons.access_time_filled_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.orange.withOpacity(0.15),
                        foregroundColor: Colors.orange,
                      ),
                      tooltip: "File Overtime Request",
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataColumn extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DataColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _StatItem({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: isBold ? cs.primary : cs.onSurface,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class AttendanceApprovedSheet extends StatelessWidget {
  const AttendanceApprovedSheet({super.key, required this.group});

  final AttendanceApprovalGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Approved Attendance",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      group.employeeName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (group.pendingApprovals.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Schedule: ${group.pendingApprovals.first.scheduleLabel}",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 32, thickness: 1),

          // Scrollable Content
          Expanded(
            child: group.pendingApprovals.isEmpty
                ? Center(
                    child: Text("No approved logs", style: TextStyle(color: cs.outline)),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      // List Items (read-only)
                      ...group.pendingApprovals.map((approval) {
                        return _AttendanceLogCardReadOnly(approval: approval);
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceLogCardReadOnly extends StatelessWidget {
  final AttendanceApprovalHeader approval;

  const _AttendanceLogCardReadOnly({required this.approval});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  approval.dateScheduleLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Approved",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Data Grid
            Row(
              children: [
                Expanded(
                  child: _DataColumn(
                    label: "Time In",
                    value: formatDateTimeToTime(approval.actualStart),
                    icon: Icons.login_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DataColumn(
                    label: "Time Out",
                    value: formatDateTimeToTime(approval.actualEnd),
                    icon: Icons.logout_rounded,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatItem(label: "Late", value: "${approval.lateMinutes}m"),
                ),
                Expanded(
                  child: _StatItem(label: "Under", value: "${approval.undertimeMinutes}m"),
                ),
                Expanded(
                  child: _StatItem(label: "Over", value: "${approval.overtimeMinutes}m"),
                ),
                Expanded(
                  child: _StatItem(label: "Total", value: approval.workMinutesLabel, isBold: true),
                ),
              ],
            ),
            if (approval.approvedAt != null) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.verified_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Approved on ${formatDateTimeToTime(approval.approvedAt!)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
