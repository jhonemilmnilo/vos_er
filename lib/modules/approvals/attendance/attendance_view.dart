// lib/modules/approvals/attendance/attendance_view.dart
import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart"; // Added for Haptics
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../app.dart"; // apiClientProvider
import "../../../core/auth/user_permissions.dart";
import "../../../data/repositories/attendance_repository.dart" hide formatTimeOfDay;
import "attendance_model.dart";
import 'attendance_sheet.dart';

class AttendanceApprovalView extends ConsumerStatefulWidget {
  const AttendanceApprovalView({super.key});

  @override
  ConsumerState<AttendanceApprovalView> createState() => _AttendanceApprovalViewState();
}

class _AttendanceApprovalViewState extends ConsumerState<AttendanceApprovalView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  String _query = "";
  bool _loading = true;
  String? _error;
  bool _loadingMore = false;
  bool _hasMore = true;

  late final AttendanceRepository _repo;

  AttendancePermission? _userPermission;

  final List<AttendanceApprovalGroup> _groups = [];
  final int _limit = 20;
  int _offset = 0;
  final int _initialLimit = -1; // Load all employees initially

  List<AttendanceApprovalGroup> get _filteredGroups {
    if (_query.trim().isEmpty) return _groups;

    final query = _query.trim().toLowerCase();
    return _groups.where((group) {
      return group.employeeName.toLowerCase().contains(query) ||
          group.departmentName.toLowerCase().contains(query);
    }).toList();
  }

  int get _totalPendingApprovals {
    final groups = _query.isNotEmpty ? _filteredGroups : _groups;
    return groups.fold(0, (sum, group) => sum + group.pendingCount);
  }

  @override
  void initState() {
    super.initState();
    _repo = AttendanceRepository(ref.read(apiClientProvider));
    _scrollCtrl.addListener(_onScroll);
    _loadUserPermissionAndData();
  }

  Future<void> _loadUserPermissionAndData() async {
    final permission = await _getCurrentUserPermission();
    setState(() => _userPermission = permission);

    if (permission != AttendancePermission.none) {
      _reload();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore &&
        _query.isEmpty) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;

      final next = value.trim();
      if (next == _query) return;

      setState(() => _query = next);
    });
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
  }

  Future<AttendancePermission> _getCurrentUserPermission() async {
    try {
      final service = ref.read(userPermissionsServiceProvider);
      final user = await service.getCurrentUser();
      return user?.getAttendancePermission() ?? AttendancePermission.none;
    } catch (e) {
      debugPrint('Error getting user permission: $e');
      return AttendancePermission.none;
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _groups.clear();
      _offset = 0;
      _hasMore = true;
    });

    try {
      final allowedDepartmentIds = await _getAllowedDepartmentIds();
      final page = await _repo.fetchAttendanceApprovalsPaged(
        status: "pending",
        search: null,
        limit: _initialLimit,
        offset: _offset,
        allowedDepartmentIds: allowedDepartmentIds,
      );

      if (!mounted) return;

      // Group by employee
      final Map<int, List<AttendanceApprovalHeader>> grouped = {};
      for (final item in page.items) {
        grouped.putIfAbsent(item.employeeId, () => []).add(item);
      }

      final groups = grouped.entries.map((entry) {
        final employeeId = entry.key;
        final approvals = entry.value;
        final first = approvals.first;
        return AttendanceApprovalGroup(
          employeeId: employeeId,
          employeeName: first.employeeName,
          departmentName: first.departmentName,
          pendingApprovals: approvals,
        );
      }).toList();

      // Sort groups alphabetically by employee name
      groups.sort((a, b) => a.employeeName.compareTo(b.employeeName));

      setState(() {
        _groups.addAll(groups);
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
      final page = await _repo.fetchAttendanceApprovalsPaged(
        status: "pending",
        search: null,
        limit: _limit,
        offset: _offset,
      );

      if (!mounted) return;

      // Group by employee
      final Map<int, List<AttendanceApprovalHeader>> grouped = {};
      for (final item in page.items) {
        grouped.putIfAbsent(item.employeeId, () => []).add(item);
      }

      final groups = grouped.entries.map((entry) {
        final employeeId = entry.key;
        final approvals = entry.value;
        final first = approvals.first;
        return AttendanceApprovalGroup(
          employeeId: employeeId,
          employeeName: first.employeeName,
          departmentName: first.departmentName,
          pendingApprovals: approvals,
        );
      }).toList();

      setState(() {
        _groups.addAll(groups);
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

  Future<void> _openApprovalModal(AttendanceApprovalGroup group) async {
    HapticFeedback.selectionClick();
    final outcome = await showModalBottomSheet<AttendanceApproveOutcome?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendanceApprovalSheet(group: group),
    );

    if (outcome == null) return;

    await _reload();
    if (!mounted) return;

    final msg = outcome.newStatus == AttendanceStatus.approved
        ? "Approved selected attendance for ${group.employeeName}."
        : "Rejected selected attendance for ${group.employeeName}.";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildSearchHeader(ColorScheme cs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Search employee or department...",
                  hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.search_rounded, color: cs.primary, size: 22),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 20),
                          color: cs.onSurfaceVariant,
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged("");
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_loading)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: cs.onSecondaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          "Grouped by Employee",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "$_totalPendingApprovals Pending Item${_totalPendingApprovals != 1 ? 's' : ''}",
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayGroups = _query.isNotEmpty ? _filteredGroups : _groups;
    
    // Consistent background color
    const backgroundColor = Color(0xFFF8F9FC);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: RefreshIndicator(
        onRefresh: _reload,
        color: cs.primary,
        backgroundColor: Colors.white,
        edgeOffset: 120,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverAppBar.large(
              backgroundColor: backgroundColor,
              surfaceTintColor: Colors.transparent,
              expandedHeight: 110,
              pinned: true,
              title: Text(
                'Attendance',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton.filledTonal(
                    onPressed: _reload,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: cs.onSurfaceVariant,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),

            _buildSearchHeader(cs),

            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(message: _error!, onRetry: _reload),
              )
            else if (displayGroups.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(query: _query),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == displayGroups.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 40),
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

                      final group = displayGroups[i];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AttendanceGroupCard(
                          group: group,
                          onTap: () => _openApprovalModal(group),
                        ),
                      );
                    },
                    childCount: displayGroups.length + (_query.isEmpty ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------
// UI: AESTHETIC GROUP CARD
// ------------------------------
class _AttendanceGroupCard extends StatelessWidget {
  final AttendanceApprovalGroup group;
  final VoidCallback onTap;

  const _AttendanceGroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2937).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: cs.primary.withOpacity(0.05),
          highlightColor: cs.primary.withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar Area
                Hero(
                  tag: 'avatar_${group.employeeId}',
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      group.employeeName.isNotEmpty ? group.employeeName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.employeeName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          fontSize: 16,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.departmentName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Pending Count Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.errorContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 12, color: cs.error),
                            const SizedBox(width: 6),
                            Text(
                              "${group.pendingCount} Pending",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cs.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action Arrow
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded, 
                    color: cs.onSurfaceVariant,
                    size: 20
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

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

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
              child: Icon(Icons.people_outline_rounded, size: 48, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              query.trim().isEmpty ? "No Attendance Issues" : "No results for \"$query\"",
              style: TextStyle(
                fontWeight: FontWeight.w800, 
                color: cs.onSurface,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Everyone is clocked in correctly.\nGood job team!",
              style: TextStyle(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
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
              style: TextStyle(
                fontWeight: FontWeight.w800, 
                color: cs.onSurface,
                fontSize: 18,
              ),
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