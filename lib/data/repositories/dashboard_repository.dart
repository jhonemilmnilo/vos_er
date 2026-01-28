import '../../core/network/api_client.dart';
import '../models/dashboard_models.dart';
import 'attendance_repository.dart';
import 'leave_repository.dart';
import 'overtime_repository.dart';

class DashboardRepository {
  DashboardRepository(this._api, this._attendanceRepo, this._leaveRepo, this._overtimeRepo);

  final ApiClient _api;
  final AttendanceRepository _attendanceRepo;
  final LeaveRepository _leaveRepo;
  final OvertimeRepository _overtimeRepo;

  Future<DashboardData> fetchDashboardData({int? userId, List<int>? allowedDepartmentIds}) async {
    // Fetch all dashboard data in parallel for better performance, but handle errors gracefully
    final results = await Future.wait([
      _fetchMetrics(userId, allowedDepartmentIds).catchError((_) => DashboardMetrics.empty()),
      _fetchAttendanceTrends().catchError((_) => <AttendanceTrendPoint>[]),
      _fetchJustClockedIn().catchError((_) => <JustClockedInEntry>[]),
      _fetchPendingApprovals(allowedDepartmentIds).catchError((_) => <PendingApproval>[]),
      _fetchAnomalyAlerts().catchError((_) => <AnomalyAlert>[]),
      _fetchDepartmentEfficiency().catchError((_) => <DepartmentEfficiency>[]),
    ]);

    return DashboardData(
      metrics: results[0] as DashboardMetrics,
      attendanceTrends: results[1] as List<AttendanceTrendPoint>,
      justClockedIn: results[2] as List<JustClockedInEntry>,
      pendingApprovals: results[3] as List<PendingApproval>,
      anomalyAlerts: results[4] as List<AnomalyAlert>,
      departmentEfficiency: results[5] as List<DepartmentEfficiency>,
    );
  }

  Future<DashboardMetrics> _fetchMetrics(int? userId, List<int>? allowedDepartmentIds) async {
    try {
      // Try to get aggregated metrics from a dedicated endpoint
      final json = await _api.getJson(
        "/dashboard/metrics",
        query: {
          if (userId != null) "user_id": userId.toString(),
          if (allowedDepartmentIds != null && allowedDepartmentIds.isNotEmpty)
            "department_ids": allowedDepartmentIds.join(","),
        },
      );
      return DashboardMetrics.fromJson(json);
    } catch (e) {
      // Fallback: calculate metrics from individual repositories
      return _calculateMetricsFallback(userId, allowedDepartmentIds);
    }
  }

  Future<DashboardMetrics> _calculateMetricsFallback(
    int? userId,
    List<int>? allowedDepartmentIds,
  ) async {
    // Calculate pending counts with department filtering
    final attendancePending = await _calculateAttendancePendingCount(allowedDepartmentIds);
    final leavePending = await _calculateLeavePendingCount(allowedDepartmentIds);
    final overtimePending = await _calculateOvertimePendingCount(allowedDepartmentIds);

    // Calculate real metrics from actual data
    final realTimeAttendanceRate = await _calculateRealTimeAttendanceRate(
      userId,
      allowedDepartmentIds,
    );
    final punctualityScore = await _calculatePunctualityScore(userId, allowedDepartmentIds);
    final pendingActions = attendancePending + leavePending + overtimePending;
    final totalOvertimeHours = await _calculateTotalOvertimeHours(userId, allowedDepartmentIds);

    return DashboardMetrics(
      realTimeAttendanceRate: realTimeAttendanceRate,
      punctualityScore: punctualityScore,
      pendingActions: pendingActions,
      totalOvertimeHours: totalOvertimeHours,
    );
  }

  Future<double> _calculateAttendanceRate(int? userId) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final query = <String, String>{
        "filter[log_date][_gte]": monthStart.toIso8601String().substring(0, 10),
        "fields": "user_id,approve_status",
        "limit": "-1",
      };

      if (userId != null) {
        query["filter[user_id][_eq]"] = userId.toString();
      }

      final json = await _api.getJson("/items/attendance_log", query: query);
      final data = json['data'] as List<dynamic>;

      if (data.isEmpty) return 0.0;

      int presentCount = 0;
      final totalDays = now.difference(monthStart).inDays + 1;

      for (final log in data) {
        final status = log['approve_status']?.toString().toLowerCase();
        if (status == 'approved') {
          presentCount++;
        }
      }

      return (presentCount / totalDays) * 100.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _calculateOvertimeHours(int? userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final query = <String, String>{
        "filter[status][_eq]": "approved",
        "filter[request_date][_gte]": weekStart.toIso8601String().substring(0, 10),
        "fields": "user_id,duration_minutes",
        "limit": "-1",
      };

      if (userId != null) {
        query["filter[user_id][_eq]"] = userId.toString();
      }

      final json = await _api.getJson("/items/overtime_request", query: query);
      final data = json['data'] as List<dynamic>;

      final totalMinutes = data.fold<double>(0.0, (sum, item) {
        return sum + ((item['duration_minutes'] as num?)?.toDouble() ?? 0.0);
      });

      return totalMinutes / 60.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _calculateLeaveBalance(int? userId) async {
    try {
      final balances = <String, Map<String, dynamic>>{};
      final query = <String, String>{
        "fields": "user_id,leave_type,total_days,status",
        "limit": "-1",
      };

      if (userId != null) {
        query["filter[user_id][_eq]"] = userId.toString();
      }

      final json = await _api.getJson("/items/leave_request", query: query);
      final data = json['data'] as List<dynamic>;

      for (final request in data) {
        final type = request['leave_type']?.toString() ?? 'Unknown';
        final days = (request['total_days'] as num?)?.toDouble() ?? 0.0;
        final status = request['status']?.toString().toLowerCase();

        if (!balances.containsKey(type)) {
          balances[type] = {'used': 0.0, 'total': _getDefaultLeaveDays(type)};
        }

        if (status == 'approved') {
          balances[type]!['used'] = (balances[type]!['used'] as double) + days;
        }
      }

      double totalRemaining = 0.0;
      for (final balance in balances.values) {
        final used = balance['used'] as double;
        final total = balance['total'] as int;
        totalRemaining += (total - used);
      }

      return totalRemaining;
    } catch (e) {
      return 0.0;
    }
  }

  Future<AttendanceStatusSummary> _fetchAttendanceStatus() async {
    // Calculate attendance status from attendance logs
    try {
      // Get today's attendance logs
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final json = await _api.getJson(
        "/items/attendance_log",
        query: {
          "filter[log_date][_eq]": today,
          "fields": "log_id,user_id,time_in,time_out,approve_status",
          "limit": "-1",
        },
      );

      final data = json['data'] as List<dynamic>;
      int onTime = 0;
      int late = 0;
      int absent = 0;
      final total = data.length;

      for (final log in data) {
        final status = log['approve_status']?.toString().toLowerCase();
        if (status == 'approved') {
          // Check if late based on time_in (simplified logic)
          final timeIn = log['time_in'];
          if (timeIn != null) {
            final timeInDateTime = DateTime.parse(timeIn.toString());
            final hour = timeInDateTime.hour;
            if (hour >= 9) {
              // Assuming 9 AM start time
              late++;
            } else {
              onTime++;
            }
          } else {
            absent++;
          }
        } else if (status == 'pending' || status == null) {
          absent++; // Not yet approved, count as absent for now
        } else {
          absent++;
        }
      }

      return AttendanceStatusSummary(onTime: onTime, late: late, absent: absent, total: total);
    } catch (e) {
      // Return empty data if API fails
      return const AttendanceStatusSummary(onTime: 0, late: 0, absent: 0, total: 0);
    }
  }

  Future<List<AttendanceTrendPoint>> _fetchAttendanceTrends() async {
    try {
      final json = await _api.getJson("/dashboard/attendance/trends");
      final data = json['data'] as List<dynamic>;
      return data.map((e) => AttendanceTrendPoint.fromJson(e)).toList();
    } catch (e) {
      // Calculate attendance trends from attendance logs for last 7 days
      final now = DateTime.now();
      final trends = <AttendanceTrendPoint>[];

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = date.toIso8601String().substring(0, 10);

        try {
          final json = await _api.getJson(
            "/items/attendance_log",
            query: {
              "filter[log_date][_eq]": dateStr,
              "fields": "user_id,approve_status",
              "limit": "-1",
            },
          );

          final data = json['data'] as List<dynamic>;
          int present = 0;
          int total = data.length;

          for (final log in data) {
            final status = log['approve_status']?.toString().toLowerCase();
            if (status == 'approved') {
              present++;
            }
          }

          trends.add(AttendanceTrendPoint(date: date, present: present, total: total));
        } catch (e) {
          trends.add(AttendanceTrendPoint(date: date, present: 0, total: 0));
        }
      }

      return trends;
    }
  }

  Future<List<LeaveBalance>> _fetchLeaveBalances(int? userId) async {
    // Calculate leave balances from leave requests
    try {
      final balances = <String, Map<String, dynamic>>{};

      // Get all leave requests for the user or all users if no user specified
      final query = <String, String>{
        "fields": "user_id,leave_type,total_days,status",
        "limit": "-1",
      };

      if (userId != null) {
        query["filter[user_id][_eq]"] = userId.toString();
      }

      final json = await _api.getJson("/items/leave_request", query: query);
      final data = json['data'] as List<dynamic>;

      // Aggregate by leave type
      for (final request in data) {
        final type = request['leave_type']?.toString() ?? 'Unknown';
        final days = (request['total_days'] as num?)?.toDouble() ?? 0.0;
        final status = request['status']?.toString().toLowerCase();

        if (!balances.containsKey(type)) {
          balances[type] = {'used': 0.0, 'total': _getDefaultLeaveDays(type)};
        }

        if (status == 'approved') {
          balances[type]!['used'] = (balances[type]!['used'] as double) + days;
        }
      }

      return balances.entries.map((entry) {
        return LeaveBalance(
          type: entry.key,
          used: (entry.value['used'] as double).toInt(),
          total: entry.value['total'] as int,
        );
      }).toList();
    } catch (e) {
      // Return empty data if API fails
      return [];
    }
  }

  int _getDefaultLeaveDays(String type) {
    switch (type.toLowerCase()) {
      case 'annual':
        return 25;
      case 'sick':
        return 10;
      case 'personal':
        return 5;
      case 'maternity':
        return 90;
      default:
        return 10;
    }
  }

  Future<List<PendingLeaveRequest>> _fetchPendingLeaveRequests(
    List<int>? allowedDepartmentIds,
  ) async {
    try {
      final json = await _api.getJson(
        "/dashboard/leave/pending",
        query: {
          "limit": "5",
          if (allowedDepartmentIds != null && allowedDepartmentIds.isNotEmpty)
            "department_ids": allowedDepartmentIds.join(","),
        },
      );
      final data = json['data'] as List<dynamic>;
      return data.map((e) => PendingLeaveRequest.fromJson(e)).toList();
    } catch (e) {
      // Return empty data if API fails
      return [];
    }
  }

  Future<OvertimeSummary> _fetchOvertimeSummary() async {
    // Calculate overtime summary from overtime requests
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Get this week's overtime
      final weekQuery = <String, String>{
        "filter[status][_eq]": "approved",
        "filter[request_date][_gte]": weekStart.toIso8601String().substring(0, 10),
        "fields": "duration_minutes",
        "limit": "-1",
      };

      final weekJson = await _api.getJson("/items/overtime_request", query: weekQuery);
      final weekData = weekJson['data'] as List<dynamic>;
      final thisWeek = weekData.fold<double>(
        0.0,
        (sum, item) => sum + ((item['duration_minutes'] as num?)?.toDouble() ?? 0.0) / 60.0,
      );

      // Get this month's overtime
      final monthQuery = <String, String>{
        "filter[status][_eq]": "approved",
        "filter[request_date][_gte]": monthStart.toIso8601String().substring(0, 10),
        "fields": "duration_minutes",
        "limit": "-1",
      };

      final monthJson = await _api.getJson("/items/overtime_request", query: monthQuery);
      final monthData = monthJson['data'] as List<dynamic>;
      final thisMonth = monthData.fold<double>(
        0.0,
        (sum, item) => sum + ((item['duration_minutes'] as num?)?.toDouble() ?? 0.0) / 60.0,
      );

      // Calculate average daily (simplified)
      final averageDaily = thisWeek / 7;

      return OvertimeSummary(thisWeek: thisWeek, thisMonth: thisMonth, averageDaily: averageDaily);
    } catch (e) {
      // Return empty data if API fails
      return const OvertimeSummary(thisWeek: 0.0, thisMonth: 0.0, averageDaily: 0.0);
    }
  }

  Future<List<OvertimeByDepartment>> _fetchOvertimeByDepartment() async {
    try {
      final json = await _api.getJson("/dashboard/overtime/by-department");
      final data = json['data'] as List<dynamic>;
      return data.map((e) => OvertimeByDepartment.fromJson(e)).toList();
    } catch (e) {
      // Return empty data if API fails
      return [];
    }
  }

  Future<int> _calculateAttendancePendingCount(List<int>? allowedDepartmentIds) async {
    try {
      final query = <String, String>{
        "limit": "1",
        "offset": "0",
        "fields": "log_id",
        "filter[approve_status][_eq]": "pending",
        "meta": "filter_count",
      };

      if (allowedDepartmentIds != null && allowedDepartmentIds.isNotEmpty) {
        query["filter[department_id][_in]"] = allowedDepartmentIds.join(",");
      }

      final json = await _api.getJson("/items/attendance_log", query: query);
      final meta = json["meta"];
      if (meta is Map) {
        final fc = _asInt(meta["filter_count"]);
        if (fc != null) return fc;
      }

      final data = _readDataList(json);
      return data.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _calculateLeavePendingCount(List<int>? allowedDepartmentIds) async {
    try {
      final query = <String, String>{
        "limit": "1",
        "offset": "0",
        "fields": "leave_id",
        "filter[status][_eq]": "pending",
        "meta": "filter_count",
      };

      if (allowedDepartmentIds != null && allowedDepartmentIds.isNotEmpty) {
        query["filter[department_id][_in]"] = allowedDepartmentIds.join(",");
      }

      final json = await _api.getJson("/items/leave_request", query: query);
      final meta = json["meta"];
      if (meta is Map) {
        final fc = _asInt(meta["filter_count"]);
        if (fc != null) return fc;
      }

      final data = _readDataList(json);
      return data.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _calculateOvertimePendingCount(List<int>? allowedDepartmentIds) async {
    try {
      final query = <String, String>{
        "limit": "1",
        "offset": "0",
        "fields": "overtime_id",
        "filter[status][_eq]": "pending",
        "meta": "filter_count",
      };

      if (allowedDepartmentIds != null && allowedDepartmentIds.isNotEmpty) {
        query["filter[department_id][_in]"] = allowedDepartmentIds.join(",");
      }

      final json = await _api.getJson("/items/overtime_request", query: query);
      final meta = json["meta"];
      if (meta is Map) {
        final fc = _asInt(meta["filter_count"]);
        if (fc != null) return fc;
      }

      final data = _readDataList(json);
      return data.length;
    } catch (e) {
      return 0;
    }
  }

  Future<double> _calculateRealTimeAttendanceRate(
    int? userId,
    List<int>? allowedDepartmentIds,
  ) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final query = <String, String>{
        "filter[log_date][_eq]": today,
        "fields": "user_id,approve_status",
        "limit": "-1",
      };

      if (userId != null) {
        query["filter[user_id][_eq]"] = userId.toString();
      }

      if (allowedDepartmentIds != null && allowedDepartmentIds.isNotEmpty) {
        query["filter[department_id][_in]"] = allowedDepartmentIds.join(",");
      }

      final json = await _api.getJson("/items/attendance_log", query: query);
      final data = json['data'] as List<dynamic>;

      if (data.isEmpty) return 0.0;

      int presentCount = 0;
      for (final log in data) {
        final status = log['approve_status']?.toString().toLowerCase();
        if (status == 'approved') {
          presentCount++;
        }
      }

      return (presentCount / data.length) * 100.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _calculatePunctualityScore(int? userId, List<int>? allowedDepartmentIds) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final query = <String, String>{
        "filter[date_schedule][_eq]": today,
        "fields": "user_id,late_minutes",
        "limit": "-1",
      };

      if (userId != null) {
        query["filter[user_id][_eq]"] = userId.toString();
      }

      if (allowedDepartmentIds != null && allowedDepartmentIds.isNotEmpty) {
        query["filter[department_id][_in]"] = allowedDepartmentIds.join(",");
      }

      final json = await _api.getJson("/items/attendance_approval", query: query);
      final data = json['data'] as List<dynamic>;

      if (data.isEmpty) return 100.0; // Default to 100% if no data

      int onTimeCount = 0;
      for (final approval in data) {
        final lateMinutes = (approval['late_minutes'] as num?)?.toInt() ?? 0;
        if (lateMinutes == 0) {
          onTimeCount++;
        }
      }

      return (onTimeCount / data.length) * 100.0;
    } catch (e) {
      return 100.0;
    }
  }

  Future<double> _calculateTotalOvertimeHours(int? userId, List<int>? allowedDepartmentIds) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final query = <String, String>{
        "filter[status][_eq]": "approved",
        "filter[request_date][_gte]": monthStart.toIso8601String().substring(0, 10),
        "fields": "user_id,duration_minutes",
        "limit": "-1",
      };

      if (userId != null) {
        query["filter[user_id][_eq]"] = userId.toString();
      }

      if (allowedDepartmentIds != null && allowedDepartmentIds.isNotEmpty) {
        query["filter[department_id][_in]"] = allowedDepartmentIds.join(",");
      }

      final json = await _api.getJson("/items/overtime_request", query: query);
      final data = json['data'] as List<dynamic>;

      final totalMinutes = data.fold<double>(0.0, (sum, item) {
        return sum + ((item['duration_minutes'] as num?)?.toDouble() ?? 0.0);
      });

      return totalMinutes / 60.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<List<JustClockedInEntry>> _fetchJustClockedIn() async {
    try {
      final json = await _api.getJson("/dashboard/just-clocked-in", query: {"limit": "5"});
      final data = json['data'] as List<dynamic>;
      return data.map((e) => JustClockedInEntry.fromJson(e)).toList();
    } catch (e) {
      // Fallback: get recent attendance logs with user names
      try {
        final json = await _api.getJson(
          "/items/attendance_log",
          query: {
            "sort": "-time_in",
            "limit": "5",
            "fields": "user_id,time_in,image_time_in",
            "meta": "filter_count",
          },
        );
        final data = json['data'] as List<dynamic>;

        // Fetch user names for each attendance log
        final entries = <JustClockedInEntry>[];
        for (final log in data) {
          final userId = (log['user_id'] as num?)?.toInt() ?? 0;
          String employeeName = 'Employee $userId'; // Default fallback

          try {
            // Try to get user name from user table
            final userJson = await _api.getJson(
              "/items/user/$userId",
              query: {"fields": "user_fname,user_lname"},
            );
            final userData = userJson['data'] as Map<String, dynamic>?;
            if (userData != null) {
              final firstName = userData['user_fname'] as String?;
              final lastName = userData['user_lname'] as String?;
              if (firstName != null && lastName != null) {
                employeeName = '$firstName $lastName';
              } else if (firstName != null) {
                employeeName = firstName;
              } else if (lastName != null) {
                employeeName = lastName;
              }
            }
          } catch (e) {
            // Keep default name if user fetch fails
          }

          entries.add(
            JustClockedInEntry(
              userId: userId,
              employeeName: employeeName,
              imageUrl: log['image_time_in']?.toString() ?? '',
              timeIn: DateTime.parse(
                log['time_in']?.toString() ?? DateTime.now().toIso8601String(),
              ),
              isLate: false, // Simplified - could be calculated from approval data
            ),
          );
        }

        return entries;
      } catch (e) {
        return [];
      }
    }
  }

  Future<List<PendingApproval>> _fetchPendingApprovals(List<int>? allowedDepartmentIds) async {
    try {
      final json = await _api.getJson(
        "/dashboard/pending-approvals",
        query: {
          "limit": "5",
          if (allowedDepartmentIds != null && allowedDepartmentIds.isNotEmpty)
            "department_ids": allowedDepartmentIds.join(","),
        },
      );
      final data = json['data'] as List<dynamic>;
      return data.map((e) => PendingApproval.fromJson(e)).toList();
    } catch (e) {
      // Fallback: combine pending from different repositories
      final results = await Future.wait([
        _attendanceRepo.fetchAttendancePendingCount(),
        _leaveRepo.fetchLeavePendingCount(),
        _overtimeRepo.fetchOvertimePendingCount(),
      ]);

      // Simplified fallback - return empty list for now
      return [];
    }
  }

  Future<List<AnomalyAlert>> _fetchAnomalyAlerts() async {
    try {
      final json = await _api.getJson("/dashboard/anomaly-alerts", query: {"limit": "5"});
      final data = json['data'] as List<dynamic>;
      return data.map((e) => AnomalyAlert.fromJson(e)).toList();
    } catch (e) {
      // Fallback: calculate basic anomalies
      final alerts = <AnomalyAlert>[];

      try {
        // Check for early leavers today
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final json = await _api.getJson(
          "/items/attendance_log",
          query: {
            "filter[log_date][_eq]": today,
            "filter[time_out][_nnull]": "true",
            "fields": "user_id,time_out",
            "limit": "-1",
          },
        );
        final data = json['data'] as List<dynamic>;

        for (final log in data) {
          final timeOut = DateTime.parse(log['time_out']?.toString() ?? '');
          if (timeOut.hour < 17) {
            // Assuming 5 PM end time
            alerts.add(
              AnomalyAlert(
                type: 'early_leaver',
                employeeName: 'Employee ${(log['user_id'] as num?)?.toInt() ?? 0}',
                message:
                    'Left early at ${timeOut.hour}:${timeOut.minute.toString().padLeft(2, '0')}',
                timestamp: DateTime.now(),
              ),
            );
          }
        }
      } catch (e) {
        // Ignore errors in fallback
      }

      return alerts.take(5).toList();
    }
  }

  Future<List<DepartmentEfficiency>> _fetchDepartmentEfficiency() async {
    try {
      final json = await _api.getJson("/dashboard/department-efficiency");
      final data = json['data'] as List<dynamic>;
      return data.map((e) => DepartmentEfficiency.fromJson(e)).toList();
    } catch (e) {
      // Fallback: calculate from attendance approvals
      try {
        final json = await _api.getJson(
          "/items/attendance_approval",
          query: {"fields": "department_id,work_minutes", "limit": "-1"},
        );
        final data = json['data'] as List<dynamic>;

        final deptMap = <int, List<double>>{};
        for (final approval in data) {
          final deptId = (approval['department_id'] as num?)?.toInt() ?? 0;
          final workMinutes = (approval['work_minutes'] as num?)?.toDouble() ?? 0.0;
          deptMap.putIfAbsent(deptId, () => []).add(workMinutes);
        }

        return deptMap.entries.map((entry) {
          final avgMinutes = entry.value.isNotEmpty
              ? entry.value.reduce((a, b) => a + b) / entry.value.length
              : 0.0;
          return DepartmentEfficiency(
            departmentId: entry.key,
            departmentName: 'Department ${entry.key}',
            departmentDescription: 'Department ${entry.key} operations',
            departmentHead: null,
            parentDivision: null,
            averageWorkHours: avgMinutes / 60.0,
            employeeCount: 0, // TODO: Calculate from user count
            attendanceRate: 85.0, // TODO: Calculate from attendance data
            punctualityRate: 80.0, // TODO: Calculate from approval data
          );
        }).toList();
      } catch (e) {
        return [];
      }
    }
  }

  // ============================================================
  // INTERNAL HELPERS
  // ============================================================

  List<Map<String, dynamic>> _readDataList(Map<String, dynamic> json) {
    final raw = json["data"];
    if (raw is List) {
      return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return const [];
  }

  int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
