import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/dashboard_provider.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isLoading = ref.watch(dashboardLoadingProvider);
    final error = ref.watch(dashboardErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dashboardDataProvider.notifier).refreshDashboardData(),
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const _LoadingView()
            : error != null
            ? _ErrorView(
                error: error,
                onRetry: () => ref.read(dashboardDataProvider.notifier).refreshDashboardData(),
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(dashboardDataProvider.notifier).refreshDashboardData(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Summary Cards
                      _KPISummarySection(),
                      const SizedBox(height: 24),

                      // Attendance Section
                      _SectionHeader(title: 'Attendance Overview', icon: Icons.access_time),
                      const SizedBox(height: 12),
                      _AttendanceSection(),
                      const SizedBox(height: 24),

                      // Leave Section
                      _SectionHeader(title: 'Leave Management', icon: Icons.beach_access),
                      const SizedBox(height: 12),
                      _LeaveSection(),
                      const SizedBox(height: 24),

                      // Overtime Section
                      _SectionHeader(title: 'Overtime Tracking', icon: Icons.work),
                      const SizedBox(height: 12),
                      _OvertimeSection(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}

class _AttendanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final attendanceStatus = ref.watch(attendanceStatusProvider);
    final attendanceTrends = ref.watch(attendanceTrendsProvider);

    return Column(
      children: [
        // Real-Time Status
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Status',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatusIndicator(
                      label: 'On Time',
                      count: attendanceStatus?.onTime ?? 0,
                      color: Colors.green,
                    ),
                    _StatusIndicator(
                      label: 'Late',
                      count: attendanceStatus?.late ?? 0,
                      color: Colors.orange,
                    ),
                    _StatusIndicator(
                      label: 'Absent',
                      count: attendanceStatus?.absent ?? 0,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Attendance Trend Chart
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Trends (Last 7 Days)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              if (value.toInt() >= 0 && value.toInt() < days.length) {
                                return Text(
                                  days[value.toInt()],
                                  style: const TextStyle(fontSize: 12),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: attendanceTrends.asMap().entries.map((entry) {
                            return FlSpot(entry.key.toDouble(), entry.value.present.toDouble());
                          }).toList(),
                          isCurved: true,
                          color: cs.primary,
                          barWidth: 3,
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusIndicator({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$count',
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _LeaveSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final leaveBalances = ref.watch(leaveBalancesProvider);
    final pendingRequests = ref.watch(pendingLeaveRequestsProvider);

    return Column(
      children: [
        // Leave Balance
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Balances',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (leaveBalances.isNotEmpty)
                  ...leaveBalances.map((balance) {
                    Color color;
                    switch (balance.type.toLowerCase()) {
                      case 'annual':
                        color = Colors.blue;
                        break;
                      case 'sick':
                        color = Colors.red;
                        break;
                      case 'personal':
                        color = Colors.green;
                        break;
                      default:
                        color = Colors.grey;
                    }
                    return Column(
                      children: [
                        _LeaveBalanceItem(
                          type: balance.type,
                          used: balance.used,
                          total: balance.total,
                          color: color,
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  })
                else
                  const Text('No leave balance data available'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Pending Approvals
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Leave Requests',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (pendingRequests.isNotEmpty)
                  ...pendingRequests.map((request) {
                    final startDate = '${request.startDate.month}/${request.startDate.day}';
                    final endDate = '${request.endDate.month}/${request.endDate.day}';
                    final dates = startDate == endDate ? startDate : '$startDate-$endDate';

                    return Column(
                      children: [
                        _PendingRequestItem(
                          name: request.employeeName,
                          type: request.type,
                          dates: dates,
                          status: request.status,
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  })
                else
                  const Text('No pending leave requests'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaveBalanceItem extends StatelessWidget {
  final String type;
  final int used;
  final int total;
  final Color color;

  const _LeaveBalanceItem({
    required this.type,
    required this.used,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = used / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(type, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            Text('$used / $total days', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}

class _PendingRequestItem extends StatelessWidget {
  final String name;
  final String type;
  final String dates;
  final String status;

  const _PendingRequestItem({
    required this.name,
    required this.type,
    required this.dates,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(name[0], style: TextStyle(color: cs.onPrimaryContainer)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              Text(
                '$type - $dates',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _OvertimeSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final overtimeSummary = ref.watch(overtimeSummaryProvider);
    final overtimeByDepartment = ref.watch(overtimeByDepartmentProvider);

    return Column(
      children: [
        // Overtime Summary
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overtime Summary',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _OvertimeMetric(
                      label: 'This Week',
                      hours: overtimeSummary?.thisWeek ?? 0.0,
                      color: Colors.blue,
                    ),
                    _OvertimeMetric(
                      label: 'This Month',
                      hours: overtimeSummary?.thisMonth ?? 0.0,
                      color: Colors.green,
                    ),
                    _OvertimeMetric(
                      label: 'Avg. Daily',
                      hours: overtimeSummary?.averageDaily ?? 0.0,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Overtime Chart
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overtime by Department',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: overtimeByDepartment.isNotEmpty
                          ? overtimeByDepartment
                                    .map((d) => d.hours)
                                    .reduce((a, b) => a > b ? a : b) +
                                10
                          : 50,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < overtimeByDepartment.length) {
                                return Text(
                                  overtimeByDepartment[value.toInt()].department,
                                  style: const TextStyle(fontSize: 12),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: overtimeByDepartment.isNotEmpty
                          ? overtimeByDepartment.asMap().entries.map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(toY: entry.value.hours, color: cs.primary),
                                ],
                              );
                            }).toList()
                          : [
                              BarChartGroupData(
                                x: 0,
                                barRods: [BarChartRodData(toY: 15, color: cs.primary)],
                              ),
                              BarChartGroupData(
                                x: 1,
                                barRods: [BarChartRodData(toY: 25, color: cs.primary)],
                              ),
                              BarChartGroupData(
                                x: 2,
                                barRods: [BarChartRodData(toY: 35, color: cs.primary)],
                              ),
                              BarChartGroupData(
                                x: 3,
                                barRods: [BarChartRodData(toY: 20, color: cs.primary)],
                              ),
                            ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OvertimeMetric extends StatelessWidget {
  final String label;
  final double hours;
  final Color color;

  const _OvertimeMetric({required this.label, required this.hours, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          '${hours}h',
          style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: cs.primary),
          const SizedBox(height: 16),
          Text(
            'Loading dashboard...',
            style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: theme.textTheme.headlineSmall?.copyWith(color: cs.error),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KPISummarySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dashboardMetricsProvider);

    if (metrics == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Attendance Rate',
                value: '${metrics.attendanceRate.toStringAsFixed(1)}%',
                icon: Icons.access_time,
                color: Colors.green,
                subtitle: 'This month',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: 'Pending Approvals',
                value: '${metrics.pendingApprovals}',
                icon: Icons.pending_actions,
                color: Colors.orange,
                subtitle: 'Across all modules',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Overtime Hours',
                value: '${metrics.overtimeHours.toStringAsFixed(1)}h',
                icon: Icons.work,
                color: Colors.blue,
                subtitle: 'This week',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: 'Leave Balance',
                value: '${metrics.leaveBalance.toStringAsFixed(1)}d',
                icon: Icons.beach_access,
                color: Colors.purple,
                subtitle: 'Avg. remaining',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
