import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/department_config.dart';

class HostNotifier extends StateNotifier<Department?> {
  HostNotifier() : super(null) {
    _loadSelectedDepartment();
  }

  static const String _selectedDepartmentKey = 'selected_department';

  Future<void> _loadSelectedDepartment() async {
    final prefs = await SharedPreferences.getInstance();
    final departmentName = prefs.getString(_selectedDepartmentKey);
    if (departmentName != null) {
      final department = availableDepartments.firstWhere(
        (dept) => dept.name == departmentName,
        orElse: () => availableDepartments.first,
      );
      state = department;
    }
  }

  Future<void> selectDepartment(Department department) async {
    // If switching to a different department, clear the current session
    if (state != null && state!.name != department.name) {
      // Clear session data when switching departments
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id'); // Clear stored user ID
      await prefs.remove('cached_users'); // Clear cached user data
    }

    state = department;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedDepartmentKey, department.name);
  }

  Future<void> clearSelection() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedDepartmentKey);
  }
}

final hostProvider = StateNotifierProvider<HostNotifier, Department?>((ref) {
  return HostNotifier();
});
