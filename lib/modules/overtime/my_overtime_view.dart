// lib/modules/overtime/my_overtime_view.dart
import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:vos_er/app_providers.dart";

import "../../data/repositories/overtime_repository.dart";
import "../approvals/overtime/overtime_models.dart";
import "edit_overtime_sheet.dart";

/// Page for users to view their own overtime requests
class MyOvertimeView extends ConsumerStatefulWidget {
  const MyOvertimeView({super.key});

  @override
  ConsumerState<MyOvertimeView> createState() => _MyOvertimeViewState();
}

class _MyOvertimeViewState extends ConsumerState<MyOvertimeView> {
  final ScrollController _scrollCtrl = ScrollController();

  bool _loading = true;
  String? _error;
  bool _loadingMore = false;
  bool _hasMore = true;

  late final OvertimeRepository _repo;

  final List<OvertimeApprovalHeader> _items = [];
  final int _limit = 20;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _repo = OvertimeRepository(ref.read(apiClientProvider));
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

      // Fetch all statuses but we'll filter to non-approved requests
      final page = await _repo.fetchOvertimeApprovalsPaged(
        status: null, // Get all statuses
        search: userIdInt.toString(), // Search by user ID
        limit: _limit,
        offset: _offset,
        allowedDepartmentIds: null,
      );

      if (!mounted) return;

      // Filter to only show current user's requests that are NOT approved
      // This includes pending and rejected requests
      final myNonApprovedItems = page.items.where((item) {
        return item.userId == userIdInt && item.status != OvertimeStatus.approved;
      }).toList();

      setState(() {
        _items.addAll(myNonApprovedItems);
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

      final page = await _repo.fetchOvertimeApprovalsPaged(
        status: null,
        search: userIdInt.toString(),
        limit: _limit,
        offset: _offset,
        allowedDepartmentIds: null,
      );

      if (!mounted) return;

      // Filter to only show current user's requests that are NOT approved
      final myNonApprovedItems = page.items.where((item) {
        return item.userId == userIdInt && item.status != OvertimeStatus.approved;
      }).toList();

      setState(() {
        _items.addAll(myNonApprovedItems);
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

  Future<void> _openEditOvertimeSheet(OvertimeApprovalHeader overtime) async {
    HapticFeedback.selectionClick();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditOvertimeSheet(overtime: overtime),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Overtime request updated successfully"),
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
          'My Overtime Requests',
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

                  final overtime = _items[i];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _OvertimeCard(
                      overtime: overtime,
                      onEdit: overtime.isPending ? () => _openEditOvertimeSheet(overtime) : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _OvertimeCard extends StatelessWidget {
  final OvertimeApprovalHeader overtime;
  final VoidCallback? onEdit;

  const _OvertimeCard({required this.overtime, this.onEdit});

  Color _getStatusColor(OvertimeStatus status) {
    switch (status) {
      case OvertimeStatus.approved:
        return Colors.green;
      case OvertimeStatus.rejected:
        return Colors.red;
      case OvertimeStatus.cancelled:
        return Colors.grey;
      case OvertimeStatus.pending:
      case OvertimeStatus.all:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(OvertimeStatus status) {
    switch (status) {
      case OvertimeStatus.approved:
        return Icons.check_circle_rounded;
      case OvertimeStatus.rejected:
        return Icons.cancel_rounded;
      case OvertimeStatus.cancelled:
        return Icons.block_rounded;
      case OvertimeStatus.pending:
      case OvertimeStatus.all:
        return Icons.pending_rounded;
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, "0");
    final mm = time.minute.toString().padLeft(2, "0");
    return "$hh:$mm";
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, "0");
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return "${hours}h ${mins}m";
    } else if (hours > 0) {
      return "${hours}h";
    } else {
      return "${mins}m";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = _getStatusColor(overtime.status);

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
                Expanded(
                  child: Text(
                    _formatDate(overtime.requestDate),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onEdit != null)
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          foregroundColor: Colors.blue,
                          padding: EdgeInsets.all(6),
                        ),
                        tooltip: "Edit Request",
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(overtime.status), size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            overtime.status.label,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Time Range
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  "${_formatTimeOfDay(overtime.otFrom)} - ${_formatTimeOfDay(overtime.otTo)}",
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDuration(overtime.durationMinutes),
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Purpose
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Purpose",
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overtime.purpose,
                    style: TextStyle(color: cs.onSurface, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),

            // Remarks (if any)
            if (overtime.remarks != null && overtime.remarks!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment_rounded, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          "Remarks",
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      overtime.remarks!,
                      style: TextStyle(color: cs.onSurface, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
              child: Icon(Icons.access_time_rounded, size: 48, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              "No Pending Overtime Requests",
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Your pending and rejected overtime requests will appear here",
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
