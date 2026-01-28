// =============================
// DASHBOARD DATA MODELS
// =============================

class DashboardMetrics {
  final double realTimeAttendanceRate;
  final double punctualityScore;
  final int pendingActions;
  final double totalOvertimeHours;

  const DashboardMetrics({
    required this.realTimeAttendanceRate,
    required this.punctualityScore,
    required this.pendingActions,
    required this.totalOvertimeHours,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      realTimeAttendanceRate: (json['real_time_attendance_rate'] as num?)?.toDouble() ?? 0.0,
      punctualityScore: (json['punctuality_score'] as num?)?.toDouble() ?? 0.0,
      pendingActions: (json['pending_actions'] as num?)?.toInt() ?? 0,
      totalOvertimeHours: (json['total_overtime_hours'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory DashboardMetrics.empty() {
    return const DashboardMetrics(
      realTimeAttendanceRate: 0.0,
      punctualityScore: 0.0,
      pendingActions: 0,
      totalOvertimeHours: 0.0,
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

class JustClockedInEntry {
  final int userId;
  final String employeeName;
  final String imageUrl;
  final DateTime timeIn;
  final bool isLate;

  const JustClockedInEntry({
    required this.userId,
    required this.employeeName,
    required this.imageUrl,
    required this.timeIn,
    required this.isLate,
  });

  factory JustClockedInEntry.fromJson(Map<String, dynamic> json) {
    return JustClockedInEntry(
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      employeeName: json['employee_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      timeIn: DateTime.parse(json['time_in'] as String),
      isLate: json['is_late'] as bool? ?? false,
    );
  }
}

class PendingApproval {
  final int id;
  final String employeeName;
  final String type; // 'attendance', 'leave', 'overtime'
  final DateTime date;
  final String details;

  const PendingApproval({
    required this.id,
    required this.employeeName,
    required this.type,
    required this.date,
    required this.details,
  });

  factory PendingApproval.fromJson(Map<String, dynamic> json) {
    return PendingApproval(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeName: json['employee_name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      details: json['details'] as String? ?? '',
    );
  }
}

class AnomalyAlert {
  final String type; // 'early_leaver', 'missed_break'
  final String employeeName;
  final String message;
  final DateTime timestamp;

  const AnomalyAlert({
    required this.type,
    required this.employeeName,
    required this.message,
    required this.timestamp,
  });

  factory AnomalyAlert.fromJson(Map<String, dynamic> json) {
    return AnomalyAlert(
      type: json['type'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class DepartmentEfficiency {
  final int departmentId;
  final String departmentName;
  final String departmentDescription;
  final String? departmentHead;
  final int? parentDivision;
  final double averageWorkHours;
  final int employeeCount;
  final double attendanceRate;
  final double punctualityRate;

  const DepartmentEfficiency({
    required this.departmentId,
    required this.departmentName,
    required this.departmentDescription,
    this.departmentHead,
    this.parentDivision,
    required this.averageWorkHours,
    required this.employeeCount,
    required this.attendanceRate,
    required this.punctualityRate,
  });

  factory DepartmentEfficiency.fromJson(Map<String, dynamic> json) {
    return DepartmentEfficiency(
      departmentId: (json['department_id'] as num?)?.toInt() ?? 0,
      departmentName: json['department_name'] as String? ?? '',
      departmentDescription: json['department_description'] as String? ?? '',
      departmentHead: json['department_head'] as String?,
      parentDivision: (json['parent_division'] as num?)?.toInt(),
      averageWorkHours: (json['average_work_hours'] as num?)?.toDouble() ?? 0.0,
      employeeCount: (json['employee_count'] as num?)?.toInt() ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0.0,
      punctualityRate: (json['punctuality_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardData {
  final DashboardMetrics metrics;
  final List<AttendanceTrendPoint> attendanceTrends;
  final List<JustClockedInEntry> justClockedIn;
  final List<PendingApproval> pendingApprovals;
  final List<AnomalyAlert> anomalyAlerts;
  final List<DepartmentEfficiency> departmentEfficiency;

  const DashboardData({
    required this.metrics,
    required this.attendanceTrends,
    required this.justClockedIn,
    required this.pendingApprovals,
    required this.anomalyAlerts,
    required this.departmentEfficiency,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      metrics: DashboardMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      attendanceTrends:
          (json['attendance_trends'] as List<dynamic>?)
              ?.map((e) => AttendanceTrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      justClockedIn:
          (json['just_clocked_in'] as List<dynamic>?)
              ?.map((e) => JustClockedInEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pendingApprovals:
          (json['pending_approvals'] as List<dynamic>?)
              ?.map((e) => PendingApproval.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      anomalyAlerts:
          (json['anomaly_alerts'] as List<dynamic>?)
              ?.map((e) => AnomalyAlert.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      departmentEfficiency:
          (json['department_efficiency'] as List<dynamic>?)
              ?.map((e) => DepartmentEfficiency.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
