import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/dashboard_models.dart';
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
        title: const Text('Professional Dashboard'),
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
                      // High-Level KPI Cards
                      _KPICardsSection(),
                      const SizedBox(height: 24),

                      // Visual Analytics
                      _SectionHeader(title: 'Visual Analytics', icon: Icons.analytics),
                      const SizedBox(height: 12),
                      _VisualAnalyticsSection(),
                      const SizedBox(height: 24),

                      // Live Monitoring
                      _SectionHeader(title: 'Live Monitoring', icon: Icons.visibility),
                      const SizedBox(height: 12),
                      _LiveMonitoringSection(),
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

class _KPICardsSection extends ConsumerWidget {
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
                title: 'Real-Time Attendance Rate',
                value: '${metrics.realTimeAttendanceRate.toStringAsFixed(1)}%',
                icon: Icons.access_time,
                color: Colors.green,
                subtitle: 'Currently in building',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: 'Punctuality Score',
                value: '${metrics.punctualityScore.toStringAsFixed(1)}%',
                icon: Icons.schedule,
                color: Colors.blue,
                subtitle: 'On-time arrivals today',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Pending Actions',
                value: '${metrics.pendingActions}',
                icon: Icons.pending_actions,
                color: Colors.orange,
                subtitle: 'Require approval',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: 'Total Overtime Hours',
                value: '${metrics.totalOvertimeHours.toStringAsFixed(1)}h',
                icon: Icons.work,
                color: Colors.purple,
                subtitle: 'This month',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VisualAnalyticsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final attendanceTrends = ref.watch(attendanceTrendsProvider);
    final departmentEfficiency = ref.watch(departmentEfficiencyProvider);

    return Column(
      children: [
        // Attendance Trends (Line Chart)
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
        const SizedBox(height: 16),
        // Late vs. On-Time Breakdown (Donut Chart)
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Late vs. On-Time Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: 75,
                          title: 'On Time\n75%',
                          color: Colors.green,
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: 25,
                          title: 'Late\n25%',
                          color: Colors.orange,
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
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

class _LiveMonitoringSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final justClockedIn = ref.watch(justClockedInProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Just Clocked In',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (justClockedIn.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: justClockedIn.length,
                  itemBuilder: (context, index) {
                    final entry = justClockedIn[index];
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: entry.imageUrl.isNotEmpty
                                ? CachedNetworkImageProvider(entry.imageUrl)
                                : null,
                            child: entry.imageUrl.isEmpty
                                ? Text(entry.employeeName[0], style: const TextStyle(fontSize: 20))
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.employeeName,
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: entry.isLate
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${entry.timeIn.hour}:${entry.timeIn.minute.toString().padLeft(2, '0')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: entry.isLate ? Colors.orange : Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              const Center(
                child: Padding(padding: EdgeInsets.all(24.0), child: Text('No recent clock-ins')),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionableListsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingApprovals = ref.watch(pendingApprovalsProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Requires Approval',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (pendingApprovals.isNotEmpty)
              ...pendingApprovals.take(5).map((approval) {
                return Column(
                  children: [
                    _PendingApprovalItem(approval: approval),
                    const SizedBox(height: 8),
                  ],
                );
              })
            else
              const Center(
                child: Padding(padding: EdgeInsets.all(24.0), child: Text('No pending approvals')),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingApprovalItem extends StatelessWidget {
  final PendingApproval approval;

  const _PendingApprovalItem({required this.approval});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    IconData typeIcon;
    Color typeColor;
    String typeLabel;

    switch (approval.type) {
      case 'attendance':
        typeIcon = Icons.access_time;
        typeColor = Colors.orange;
        typeLabel = 'Late Request';
        break;
      case 'overtime':
        typeIcon = Icons.work;
        typeColor = Colors.blue;
        typeLabel = 'Overtime Request';
        break;
      default:
        typeIcon = Icons.pending;
        typeColor = Colors.grey;
        typeLabel = 'Pending Request';
    }

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: typeColor.withOpacity(0.1),
          child: Icon(typeIcon, color: typeColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                approval.employeeName,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      typeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: typeColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${approval.date.month}/${approval.date.day}/${approval.date.year}',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              Text(
                approval.details,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {
            // TODO: Implement approval action
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

class _AnomalyDetectionSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final anomalyAlerts = ref.watch(anomalyAlertsProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anomaly Alerts',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (anomalyAlerts.isNotEmpty)
              ...anomalyAlerts.take(3).map((alert) {
                return Column(
                  children: [
                    _AnomalyAlertItem(alert: alert),
                    const SizedBox(height: 8),
                  ],
                );
              })
            else
              const Center(
                child: Padding(padding: EdgeInsets.all(24.0), child: Text('No anomalies detected')),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnomalyAlertItem extends StatelessWidget {
  final AnomalyAlert alert;

  const _AnomalyAlertItem({required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    IconData icon;
    Color color;
    switch (alert.type) {
      case 'early_leaver':
        icon = Icons.exit_to_app;
        color = Colors.orange;
        break;
      case 'missed_break':
        icon = Icons.restaurant;
        color = Colors.red;
        break;
      default:
        icon = Icons.warning;
        color = Colors.grey;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.employeeName,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                alert.message,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '${alert.timestamp.hour}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DepartmentOverviewSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final departmentEfficiency = ref.watch(departmentEfficiencyProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Departments Overview',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (departmentEfficiency.isNotEmpty)
              ...departmentEfficiency.map((dept) => _DepartmentItem(department: dept))
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No department data available'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentItem extends StatelessWidget {
  final DepartmentEfficiency department;

  const _DepartmentItem({required this.department});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  department.departmentName,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            department.departmentDescription,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          if (department.departmentHead != null) ...[
            const SizedBox(height: 4),
            Text(
              'Head: ${department.departmentHead}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DepartmentMetric(
                  label: 'Employees',
                  value: '${department.employeeCount}',
                  icon: Icons.people,
                ),
              ),
              Expanded(
                child: _DepartmentMetric(
                  label: 'Attendance',
                  value: '${department.attendanceRate.toStringAsFixed(1)}%',
                  icon: Icons.check_circle,
                  color: department.attendanceRate >= 90
                      ? Colors.green
                      : department.attendanceRate >= 80
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
              Expanded(
                child: _DepartmentMetric(
                  label: 'Punctuality',
                  value: '${department.punctualityRate.toStringAsFixed(1)}%',
                  icon: Icons.schedule,
                  color: department.punctualityRate >= 90
                      ? Colors.green
                      : department.punctualityRate >= 80
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Avg. Work Hours: ${department.averageWorkHours.toStringAsFixed(1)}h',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DepartmentMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _DepartmentMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? cs.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color ?? cs.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 10),
        ),
      ],
    );
  }
}
