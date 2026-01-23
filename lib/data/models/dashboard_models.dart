// =============================
// DASHBOARD DATA MODELS
// =============================

class DashboardMetrics {
  final double attendanceRate;
  final int pendingApprovals;
  final double overtimeHours;
  final double leaveBalance;

  const DashboardMetrics({
    required this.attendanceRate,
    required this.pendingApprovals,
    required this.overtimeHours,
    required this.leaveBalance,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0.0,
      pendingApprovals: (json['pending_approvals'] as num?)?.toInt() ?? 0,
      overtimeHours: (json['overtime_hours'] as num?)?.toDouble() ?? 0.0,
      leaveBalance: (json['leave_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AttendanceStatusSummary {
  final int onTime;
  final int late;
  final int absent;
  final int total;

  const AttendanceStatusSummary({
    required this.onTime,
    required this.late,
    required this.absent,
    required this.total,
  });

  double get onTimePercentage => total > 0 ? (onTime / total) * 100 : 0;
  double get latePercentage => total > 0 ? (late / total) * 100 : 0;
  double get absentPercentage => total > 0 ? (absent / total) * 100 : 0;

  factory AttendanceStatusSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceStatusSummary(
      onTime: (json['on_time'] as num?)?.toInt() ?? 0,
      late: (json['late'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class AttendanceTrendPoint {
  final DateTime date;
  final int present;
  final int total;

  const AttendanceTrendPoint({required this.date, required this.present, required this.total});

  double get attendanceRate => total > 0 ? (present / total) * 100 : 0;

  factory AttendanceTrendPoint.fromJson(Map<String, dynamic> json) {
    return AttendanceTrendPoint(
      date: DateTime.parse(json['date'] as String),
      present: (json['present'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaveBalance {
  final String type;
  final int used;
  final int total;

  const LeaveBalance({required this.type, required this.used, required this.total});

  int get remaining => total - used;
  double get usagePercentage => total > 0 ? (used / total) * 100 : 0;

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      type: json['type'] as String? ?? '',
      used: (json['used'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class PendingLeaveRequest {
  final int id;
  final String employeeName;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final String status;

  const PendingLeaveRequest({
    required this.id,
    required this.employeeName,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
  });

  factory PendingLeaveRequest.fromJson(Map<String, dynamic> json) {
    return PendingLeaveRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeName: json['employee_name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      days: (json['days'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
    );
  }
}

class OvertimeSummary {
  final double thisWeek;
  final double thisMonth;
  final double averageDaily;

  const OvertimeSummary({
    required this.thisWeek,
    required this.thisMonth,
    required this.averageDaily,
  });

  factory OvertimeSummary.fromJson(Map<String, dynamic> json) {
    return OvertimeSummary(
      thisWeek: (json['this_week'] as num?)?.toDouble() ?? 0.0,
      thisMonth: (json['this_month'] as num?)?.toDouble() ?? 0.0,
      averageDaily: (json['average_daily'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OvertimeByDepartment {
  final String department;
  final double hours;

  const OvertimeByDepartment({required this.department, required this.hours});

  factory OvertimeByDepartment.fromJson(Map<String, dynamic> json) {
    return OvertimeByDepartment(
      department: json['department'] as String? ?? '',
      hours: (json['hours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardData {
  final DashboardMetrics metrics;
  final AttendanceStatusSummary attendanceStatus;
  final List<AttendanceTrendPoint> attendanceTrends;
  final List<LeaveBalance> leaveBalances;
  final List<PendingLeaveRequest> pendingLeaveRequests;
  final OvertimeSummary overtimeSummary;
  final List<OvertimeByDepartment> overtimeByDepartment;

  const DashboardData({
    required this.metrics,
    required this.attendanceStatus,
    required this.attendanceTrends,
    required this.leaveBalances,
    required this.pendingLeaveRequests,
    required this.overtimeSummary,
    required this.overtimeByDepartment,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      metrics: DashboardMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      attendanceStatus: AttendanceStatusSummary.fromJson(
        json['attendance_status'] as Map<String, dynamic>,
      ),
      attendanceTrends:
          (json['attendance_trends'] as List<dynamic>?)
              ?.map((e) => AttendanceTrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      leaveBalances:
          (json['leave_balances'] as List<dynamic>?)
              ?.map((e) => LeaveBalance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pendingLeaveRequests:
          (json['pending_leave_requests'] as List<dynamic>?)
              ?.map((e) => PendingLeaveRequest.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      overtimeSummary: OvertimeSummary.fromJson(json['overtime_summary'] as Map<String, dynamic>),
      overtimeByDepartment:
          (json['overtime_by_department'] as List<dynamic>?)
              ?.map((e) => OvertimeByDepartment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
