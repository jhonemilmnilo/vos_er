// lib/modules/approvals/overtime/overtime_view.dart
import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart"; // Added for HapticFeedback
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:vos_er/app_providers.dart";

import "../../../core/auth/user_permissions.dart";
import "../../../data/repositories/overtime_repository.dart";
import "overtime_models.dart";
import "overtime_sheet.dart";

class OvertimeApprovalView extends ConsumerStatefulWidget {
  const OvertimeApprovalView({super.key});

  @override
  ConsumerState<OvertimeApprovalView> createState() => _OvertimeApprovalViewState();
}

class _OvertimeApprovalViewState extends ConsumerState<OvertimeApprovalView> {
  static const int _pageSize = 30;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  // Default: Pending queue, but keep "All" available.
  OvertimeFilter _selectedFilter = OvertimeFilter.pending;
  String _query = "";

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  int _offset = 0;
  late final OvertimeRepository _repo;

  final List<OvertimeApprovalHeader> _items = [];

  Future<List<int>?> _getAllowedDepartmentIds() async {
    final service = ref.read(userPermissionsServiceProvider);
    return service.getAllowedDepartmentIds(ref);
  }

  @override
  void initState() {
    super.initState();
    _repo = OvertimeRepository(ref.read(apiClientProvider));
    _scrollCtrl.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    if (!_scrollCtrl.hasClients) return;

    final threshold = _scrollCtrl.position.maxScrollExtent - 260;
    if (_scrollCtrl.position.pixels >= threshold) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;

      final next = value.trim();
      if (next == _query) return;

      setState(() => _query = next);

      // Server-side search requires reload
      await _reload();
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;

      _offset = 0;
      _hasMore = true;

      _items.clear();
    });

    // Force refresh user data to get updated department
    final service = ref.read(userPermissionsServiceProvider);
    await service.getCurrentUser(forceRefresh: true);

    await _loadMore(initial: true);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadMore({bool initial = false}) async {
    if (_loadingMore || !_hasMore) return;

    setState(() {
      _loadingMore = true;
      _error = null;
    });

    try {
      final status = _selectedFilter.statusValue; // null => All
      final q = _query.trim().isEmpty ? null : _query.trim();

      // Get allowed department IDs based on user permissions
      final allowedDepartmentIds = await _getAllowedDepartmentIds();

      final page = await _repo.fetchOvertimeApprovalsPaged(
        status: status,
        search: q,
        limit: _pageSize,
        offset: _offset,
        allowedDepartmentIds: allowedDepartmentIds,
      );

      final fetched = page.items;

      if (!mounted) return;

      if (fetched.isEmpty) {
        setState(() {
          _hasMore = false;
          _loadingMore = false;
        });
        return;
      }

      // Append page results
      _items.addAll(fetched);

      setState(() {
        _offset += fetched.length;
        _hasMore = page.hasMore; // reliable: uses total_count from API
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMore = false;
        if (initial) _hasMore = false;
      });
    }
  }

  Future<void> _showFilterMenu() async {
    HapticFeedback.lightImpact();
    final selected = await showModalBottomSheet<OvertimeFilter>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final visible = OvertimeFilter.values.toList(); // includes All + Cancelled if in enum
        return Material(
          color: Colors.transparent,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  "Filter by Status",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
              ...visible.map((f) {
                final isSelected = f == _selectedFilter;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary.withOpacity(0.1) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check_rounded : Icons.circle_outlined,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    f.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, f),
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );

    if (selected == null) return;

    // No-op if same filter
    if (selected == _selectedFilter) return;

    setState(() => _selectedFilter = selected);
    await _reload();
  }

  Future<void> _openApprovalModal(OvertimeApprovalHeader row) async {
    // Only pending is actionable
    if (!row.isPending) return;
    HapticFeedback.selectionClick();

    final outcome = await showModalBottomSheet<OvertimeApproveOutcome?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OvertimeApprovalSheet(header: row),
    );

    if (outcome == null) return;

    await _reload();
    if (!mounted) return;

    final msg = outcome.newStatus == OvertimeStatus.approved
        ? "Approved OT #${outcome.overtimeId}."
        : "Rejected OT #${outcome.overtimeId}.";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildSearchAndFilterHeader(
    ColorScheme cs,
    bool searching,
    double horizontalPadding,
    double verticalSpacing,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, verticalSpacing),
        child: Column(
          children: [
            // Search Bar
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
                  hintText: "Search employee, department...",
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

            // Filter & Count Row
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
                            searching ? "Search Results" : _selectedFilter.label,
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
                if (!_loading)
                  Text(
                    "${_items.length} Request${_items.length == 1 ? '' : 's'}",
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
    final fontSizeTitle = isSmallScreen ? 32.0 : 36.0;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final searching = _query.trim().isNotEmpty;

    // Use off-white for depth
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
                'Overtime',
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

            _buildSearchAndFilterHeader(cs, searching, horizontalPadding, verticalSpacing),

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
            else if (_items.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _EmptyState(query: _query))
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    if (i == _items.length) {
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

                    final row = _items[i];
                    final enabled = row.isPending;

                    return Padding(
                      padding: EdgeInsets.only(bottom: verticalSpacing),
                      child: _OvertimeCard(
                        header: row,
                        enabled: enabled,
                        onTap: () => _openApprovalModal(row),
                      ),
                    );
                  }, childCount: _items.length + 1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------
// UI: AESTHETIC OVERTIME CARD
// ------------------------------
class _OvertimeCard extends StatelessWidget {
  final OvertimeApprovalHeader header;
  final bool enabled;
  final VoidCallback onTap;

  const _OvertimeCard({required this.header, required this.enabled, required this.onTap});

  String _formatTotalDays(String days) {
    String trimmed = days.trim();
    // Remove trailing zeros after decimal
    if (trimmed.contains('.')) {
      trimmed = trimmed.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    double? num = double.tryParse(trimmed);
    if (num != null) {
      if (num % 1 == 0) {
        return '${num.toInt()} ';
      } else {
        return '$trimmed ';
      }
    }
    return "$trimmed ";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = _statusColor(header.status, cs);

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
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(24),
          splashColor: cs.primary.withOpacity(0.05),
          highlightColor: cs.primary.withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Status and Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            _formatSimpleDate(header.requestDateLabel),
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(text: header.status.label, color: statusColor),
                  ],
                ),

                const SizedBox(height: 16),

                // Employee Info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        header.employeeName.isNotEmpty ? header.employeeName[0].toUpperCase() : '?',
                        style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            header.employeeName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            header.departmentName,
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),

                // Details Grid
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "OVERTIME DETAILS",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: cs.outline,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  header.timeRangeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTotalDays(header.durationLabel),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (enabled)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_forward_rounded, color: cs.primary, size: 16),
                      ),
                  ],
                ),

                // Reason / Period
                if (header.purpose.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          header.timeRangeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          header.purpose,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(0.8),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSimpleDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      // Example: 23 Jan, 2026
      return "${date.day} ${months[date.month - 1]}, ${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  static Color _statusColor(OvertimeStatus s, ColorScheme cs) {
    switch (s) {
      case OvertimeStatus.pending:
        return const Color(0xFFF59E0B); // Amber
      case OvertimeStatus.approved:
        return const Color(0xFF10B981); // Emerald
      case OvertimeStatus.rejected:
        return const Color(0xFFEF4444); // Red
      case OvertimeStatus.cancelled:
        return cs.outline;
      case OvertimeStatus.all:
        return cs.primary;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20), // Pill shape
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
              child: Icon(Icons.search_off_rounded, size: 48, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              query.trim().isEmpty ? "No Requests Found" : "No results for \"$query\"",
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Try adjusting your filters or search terms\nto find what you're looking for.",
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
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              "Connection Issue",
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
