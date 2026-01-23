// lib/modules/approvals/overtime/overtime_sheet.dart
import "package:flutter/material.dart";
import "package:flutter/services.dart"; // Added for Haptics
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../app.dart"; // apiClientProvider, authRepositoryProvider
import "../../../data/repositories/overtime_repository.dart";
import "overtime_models.dart";

class OvertimeApprovalSheet extends ConsumerStatefulWidget {
  const OvertimeApprovalSheet({super.key, required this.header});

  final OvertimeApprovalHeader header;

  @override
  ConsumerState<OvertimeApprovalSheet> createState() => _OvertimeApprovalSheetState();
}

class _OvertimeApprovalSheetState extends ConsumerState<OvertimeApprovalSheet> {
  bool _processing = false;
  String? _error;

  Future<_ApproverInfo> _loadApproverInfo(OvertimeRepository overtimeRepo) async {
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

    final Map<int, AppUserLite> approverMap = await overtimeRepo.fetchUsersByIds(<int>[approverId]);

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
      final api = ref.read(apiClientProvider);
      final overtimeRepo = OvertimeRepository(api);

      final approver = await _loadApproverInfo(overtimeRepo);

      await overtimeRepo.approveOvertime(
        overtimeId: widget.header.overtimeId,
        approverId: approver.id,
        approverName: approver.name,
        requestDateIso: widget.header.requestDateLabel, 
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(
        OvertimeApproveOutcome(
          overtimeId: widget.header.overtimeId,
          newStatus: OvertimeStatus.approved,
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

  Future<void> _reject() async {
    if (_processing) return;
    HapticFeedback.lightImpact();

    // Confirm reject
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Overtime?"),
        content: const Text("This action cannot be undone. Are you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
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
      final overtimeRepo = OvertimeRepository(api);

      final approver = await _loadApproverInfo(overtimeRepo);

      await overtimeRepo.rejectOvertime(
        overtimeId: widget.header.overtimeId,
        approverId: approver.id,
        approverName: approver.name,
        requestDateIso: widget.header.requestDateLabel,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(
        OvertimeApproveOutcome(
          overtimeId: widget.header.overtimeId,
          newStatus: OvertimeStatus.rejected,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final h = widget.header;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
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
                      "Review Overtime",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      "Request details",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
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
                      style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.bold),
                    ),
                  ),

                // Employee Section
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        h.employeeName.isNotEmpty ? h.employeeName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.w700,
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
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            h.departmentName,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                // Timeline Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DetailItem(
                              label: "Filed On",
                              value: h.filedAtLabel, // Assuming you have this or similar in model
                              icon: Icons.history_rounded,
                            ),
                          ),
                          Container(width: 1, height: 40, color: cs.outlineVariant),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: _DetailItem(
                                label: "Request Date",
                                value: _formatSimpleDate(h.requestDateLabel),
                                icon: Icons.event_available_rounded,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Main Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label("SCHEDULE"),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 16, color: cs.primary),
                              const SizedBox(width: 6),
                              Text(
                                h.timeRangeLabel,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const _Label("STATUS"),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              h.status.label.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DURATION",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: cs.onSecondaryContainer.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              h.durationLabel,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cs.onSecondaryContainer,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Purpose
                const _Label("PURPOSE"),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Text(
                    h.purpose.trim().isEmpty ? "No purpose provided." : h.purpose,
                    style: TextStyle(
                      color: cs.onSurface,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Actions
          Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      "Reject",
                      style: TextStyle(color: cs.error, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _processing ? null : _approve,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _processing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Text(
                            "Approve",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSimpleDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${date.day} ${months[date.month - 1]}, ${date.year}";
    } catch (e) {
      return dateStr;
    }
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.outline,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}