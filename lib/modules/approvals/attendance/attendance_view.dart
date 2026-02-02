// lib/modules/approvals/attendance/attendance_view.dart
import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart"; // Added for Haptics
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:vos_er/app_providers.dart";

import "../../../core/auth/user_permissions.dart";
import "../../../data/repositories/attendance_repository.dart" hide formatTimeOfDay;
import "../../../state/host_provider.dart";
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
  String _selectedPeriod = "current"; // "current" or "previous"
  AttendanceFilter _selectedFilter = AttendanceFilter.pending;

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

  int get _totalApprovals {
    final groups = _query.isNotEmpty ? _filteredGroups : _groups;
    return groups.fold(0, (sum, group) => sum + group.pendingCount);
  }

  String get _totalApprovalsLabel {
    final count = _totalApprovals;
    final status = _selectedFilter.label;
    return "$count $status Item${count != 1 ? 's' : ''}";
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

      // Check current department port
      final currentDept = ref.read(hostProvider);
      final port = currentDept?.port;

      // Special rules for full access
      if ((port == 8091 || port == 8092) && user.departmentId == 2 && user.isAdmin) {
        return null; // Full access
      }
      if (port == 8090 && user.departmentId == 6 && user.isAdmin) {
        return null; // Full access
      }

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
        status: _selectedFilter.statusValue,
        search: null,
        limit: _initialLimit,
        offset: _offset,
        allowedDepartmentIds: allowedDepartmentIds,
        period: _selectedPeriod,
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
      final allowedDepartmentIds = await _getAllowedDepartmentIds();
      final page = await _repo.fetchAttendanceApprovalsPaged(
        status: _selectedFilter.statusValue,
        search: null,
        limit: _limit,
        offset: _offset,
        allowedDepartmentIds: allowedDepartmentIds,
        period: _selectedPeriod,
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

  Future<void> _openApprovedModal(AttendanceApprovalGroup group) async {
    HapticFeedback.selectionClick();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
       backgroundColor: Colors.transparent,
      builder: (_) => AttendanceApprovedSheet(group: group),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AttendanceFilter.values.map((filter) {
              return ListTile(
                title: Text(filter.label),
                leading: Icon(
                  filter == _selectedFilter
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () {
                  setState(() => _selectedFilter = filter);
                  _reload();
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSearchHeader(ColorScheme cs, double horizontalPadding, double verticalSpacing) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, verticalSpacing),
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
              child: DropdownButtonFormField<String>(
                initialValue: _selectedPeriod,
                decoration: InputDecoration(
                  hintText: "Select Period",
                  hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.calendar_today_rounded, color: cs.primary, size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "current",
                    child: Text(
                      "Current Cutoff",
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                  DropdownMenuItem(
                    value: "previous",
                    child: Text(
                      "Previous Cutoff",
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null && value != _selectedPeriod) {
                    setState(() => _selectedPeriod = value);
                    _reload();
                  }
                },
                style: const TextStyle(fontWeight: FontWeight.w500),
                dropdownColor: Colors.white,
                icon: Icon(Icons.arrow_drop_down_rounded, color: cs.onSurfaceVariant),
              ),
            ),

            SizedBox(height: verticalSpacing),

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
            SizedBox(height: verticalSpacing),
            if (!_loading)
              Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showFilterMenu,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: cs.outline.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune_rounded, size: 16, color: cs.onSurface),
                            const SizedBox(width: 8),
                            Text(
                              _selectedFilter.label,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _totalApprovalsLabel,
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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isMediumScreen = screenSize.width >= 600 && screenSize.width < 1200;
    final isLargeScreen = screenSize.width >= 1200;

    // Adjust padding and sizes based on screen size
    final horizontalPadding = isSmallScreen
        ? 20.0
        : isMediumScreen
        ? 32.0
        : 48.0;
    final verticalSpacing = isSmallScreen ? 16.0 : 24.0;
    final fontSizeTitle = isSmallScreen ? 28.0 : 32.0;

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
                  fontSize: fontSizeTitle,
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

            _buildSearchHeader(cs, horizontalPadding, verticalSpacing),

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
                child: _EmptyState(
                  query: _query,
                  isApproved: _selectedFilter == AttendanceFilter.approved,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    if (i == displayGroups.length) {
                      return Padding(
                        padding: EdgeInsets.only(top: 8, bottom: isSmallScreen ? 32.0 : 48.0),
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
                      padding: EdgeInsets.only(bottom: verticalSpacing),
                      child: _AttendanceGroupCard(
                        group: group,
                        onTap: _selectedFilter == AttendanceFilter.pending
                            ? () => _openApprovalModal(group)
                            : () => _openApprovedModal(group),
                        isApproved: _selectedFilter == AttendanceFilter.approved,
                      ),
                    );
                  }, childCount: displayGroups.length + (_query.isEmpty ? 1 : 0)),
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
  final bool isApproved;

  const _AttendanceGroupCard({required this.group, required this.onTap, required this.isApproved});

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

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? cs.primaryContainer.withOpacity(0.4)
                              : cs.errorContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isApproved ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                              size: 12,
                              color: isApproved ? cs.primary : cs.error,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "${group.pendingCount} ${isApproved ? 'Approved' : 'Pending'}",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isApproved ? cs.primary : cs.error,
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
                  child: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
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
  final bool isApproved;
  const _EmptyState({required this.query, required this.isApproved});

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
              query.trim().isEmpty
                  ? (isApproved ? "No Approved Attendance" : "No Attendance Issues")
                  : "No results for \"$query\"",
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isApproved
                  ? "No attendance records have been approved yet."
                  : "Everyone is clocked in correctly.\nGood job team!",
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
