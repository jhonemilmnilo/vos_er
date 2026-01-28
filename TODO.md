# TODO: Implement Attendance Approval Date Limitation

## Tasks

- [x] Modify `fetchAttendanceApprovalsPaged` method in `attendance_repository.dart` to add date range filters for pending approvals based on current day
- [x] Add helper method to calculate date range (11-25 or 26-10) based on current date
- [x] Apply filters only when status is "pending"
- [x] Test the implementation to ensure correct filtering
