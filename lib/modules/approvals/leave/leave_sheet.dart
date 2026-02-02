// lib/modules/approvals/leave/leave_sheet.dart
import "package:flutter/material.dart";
import "package:flutter/services.dart"; // For Haptics
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "package:vos_er/app_providers.dart";

import "../../../core/auth/user_permissions.dart";
import "../../../data/repositories/leave_repository.dart";
import "leave_models.dart";

class LeaveApprovalSheet extends ConsumerStatefulWidget {
  const LeaveApprovalSheet({super.key, required this.header});

  final LeaveApprovalHeader header;

  @override
  ConsumerState<LeaveApprovalSheet> createState() => _LeaveApprovalSheetState();
}

class _LeaveApprovalSheetState extends ConsumerState<LeaveApprovalSheet> {
  bool _processing = false;
  String? _error;

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('MMM dd, yyyy').format(d);
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    return DateFormat('MMM dd, yyyy hh:mm a').format(d);
  }

  String _formatTotalDays(String days) {
    String clean = days.toLowerCase().replaceAll("days", "").replaceAll("day", "").trim();
    double? num = double.tryParse(clean);
    if (num != null) {
      if (num % 1 == 0) {
        return '${num.toInt()} days';
      } else {
        return '$num days';
      }
    }
    return "$clean days";
  }

  Future<_ApproverInfo> _loadApproverInfo(LeaveRepository leaveRepo) async {
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

    final Map<int, AppUserLite> approverMap = await leaveRepo.fetchUsersByIds(<int>[approverId]);
    final String approverName = approverMap[approverId]?.displayName ?? "Unknown Approver";

    return _ApproverInfo(id: approverId, name: approverName);
  }

  Future<void> _approve() async {
    if (_processing) return;
    HapticFeedback.selectionClick();

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // Check permissions
      final userPermissionsService = ref.read(userPermissionsServiceProvider);
      final user = await userPermissionsService.getCurrentUser();
      if (user == null) throw Exception("User not found");

      if (!user.canApproveDepartment(widget.header.departmentId)) {
        throw Exception("You do not have permission to approve leave for this department");
      }

      final api = ref.read(apiClientProvider);
      final leaveRepo = LeaveRepository(api);
      final approver = await _loadApproverInfo(leaveRepo);

      await leaveRepo.approveLeave(
        leaveId: widget.header.leaveId,
        approverId: approver.id,
        approverName: approver.name,
        requestDateIso: widget.header.requestDateLabel,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(
        context,
      ).pop(LeaveApproveOutcome(leaveId: widget.header.leaveId, newStatus: LeaveStatus.approved));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _processing = false;
      });
    }
  }

  Future<void> _reject() async {
    if (_processing) return;
    HapticFeedback.lightImpact();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Leave?"),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final leaveRepo = LeaveRepository(api);
      final approver = await _loadApproverInfo(leaveRepo);

      await leaveRepo.rejectLeave(
        leaveId: widget.header.leaveId,
        approverId: approver.id,
        approverName: approver.name,
        requestDateIso: widget.header.requestDateLabel,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(
        context,
      ).pop(LeaveApproveOutcome(leaveId: widget.header.leaveId, newStatus: LeaveStatus.rejected));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final h = widget.header;

    double getSheetHeight() {
      final screenHeight = MediaQuery.of(context).size.height;
      if (screenHeight < 600) return screenHeight * 0.8;
      if (screenHeight < 800) return screenHeight * 0.7;
      return screenHeight * 0.6;
    }

    return SizedBox(
      height: getSheetHeight(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      "Leave Review",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        h.leaveType.label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 24, thickness: 0.5),

              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.errorContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.error.withOpacity(0.5)),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                        ),
                      ),

                    // Employee Profile Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            h.employeeName.isNotEmpty ? h.employeeName[0] : '?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.employeeName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                h.departmentName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Date & Stats Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Timeline Visual for Dates
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TimelineDate(
                                label: "Filed On",
                                date: _fmtDateTime(h.filedAt),
                                isTop: true,
                              ),
                              _TimelineDate(label: "Start", date: _fmtDate(h.leaveStart)),
                              _TimelineDate(
                                label: "End",
                                date: _fmtDate(h.leaveEnd),
                                isBottom: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Right: Total Days Card
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "TOTAL",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSecondaryContainer.withOpacity(0.7),
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTotalDays(
                                    h.totalDaysLabel,
                                  ).replaceAll(" days", ""), // Just the number
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: cs.primary,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  "Days",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Reason Section
                    Text(
                      "REASON",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        h.reason.isEmpty ? "No specific reason provided." : h.reason,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface,
                          height: 1.5,
                        ),
                      ),
                    ),

                    // Extra padding for scroll
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // Bottom Action Buttons
              Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(context).padding.bottom + 16,
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
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _processing ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: cs.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          foregroundColor: cs.error,
                        ),
                        child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _processing ? null : _approve,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: cs.primary,
                        ),
                        child: _processing
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Text("Approve", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

// Aesthetic Vertical Timeline Component
class _TimelineDate extends StatelessWidget {
  final String label;
  final String date;
  final bool isTop;
  final bool isBottom;

  const _TimelineDate({
    required this.label,
    required this.date,
    this.isTop = false,
    this.isBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Top line connector
                Expanded(
                  child: isTop ? const SizedBox() : Container(width: 2, color: cs.primaryContainer),
                ),
                // Dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                    boxShadow: [
                      BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                ),
                // Bottom line connector
                Expanded(
                  child: isBottom
                      ? const SizedBox()
                      : Container(width: 2, color: cs.primaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                if (isTop) const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
