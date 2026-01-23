import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _KPICard(
                      title: 'Attendance Rate',
                      value: '95%',
                      icon: Icons.access_time,
                      color: Colors.green,
                      subtitle: 'This month',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KPICard(
                      title: 'Pending Approvals',
                      value: '12',
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
                      value: '45h',
                      icon: Icons.work,
                      color: Colors.blue,
                      subtitle: 'This week',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KPICard(
                      title: 'Leave Balance',
                      value: '18d',
                      icon: Icons.beach_access,
                      color: Colors.purple,
                      subtitle: 'Avg. remaining',
                    ),
                  ),
                ],
              ),
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

class _AttendanceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
                    _StatusIndicator(label: 'On Time', count: 45, color: Colors.green),
                    _StatusIndicator(label: 'Late', count: 3, color: Colors.orange),
                    _StatusIndicator(label: 'Absent', count: 2, color: Colors.red),
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
                          spots: [
                            FlSpot(0, 48),
                            FlSpot(1, 47),
                            FlSpot(2, 49),
                            FlSpot(3, 46),
                            FlSpot(4, 48),
                            FlSpot(5, 45),
                            FlSpot(6, 47),
                          ],
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

class _LeaveSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
                _LeaveBalanceItem(type: 'Annual', used: 12, total: 25, color: Colors.blue),
                const SizedBox(height: 8),
                _LeaveBalanceItem(type: 'Sick', used: 2, total: 10, color: Colors.red),
                const SizedBox(height: 8),
                _LeaveBalanceItem(type: 'Personal', used: 3, total: 5, color: Colors.green),
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
                _PendingRequestItem(
                  name: 'John Doe',
                  type: 'Annual',
                  dates: 'Dec 20-22',
                  status: 'Pending',
                ),
                const SizedBox(height: 8),
                _PendingRequestItem(
                  name: 'Jane Smith',
                  type: 'Sick',
                  dates: 'Dec 18',
                  status: 'Pending',
                ),
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

class _OvertimeSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
                    _OvertimeMetric(label: 'This Week', hours: 45, color: Colors.blue),
                    _OvertimeMetric(label: 'This Month', hours: 180, color: Colors.green),
                    _OvertimeMetric(label: 'Avg. Daily', hours: 6.4, color: Colors.purple),
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
                      maxY: 50,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const depts = ['HR', 'IT', 'Sales', 'Ops'];
                              if (value.toInt() >= 0 && value.toInt() < depts.length) {
                                return Text(
                                  depts[value.toInt()],
                                  style: const TextStyle(fontSize: 12),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
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
