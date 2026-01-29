t# TODO: Add Dropdown for Previous Cutoff in Attendance Approvals

## 1. Update Attendance Repository

- [x] Add `period` parameter to `fetchAttendanceApprovalsPaged` method (optional, default "current")
- [x] Modify `_getAttendanceApprovalDateRange` to accept `period` ("current" or "previous") and compute ranges accordingly
- [x] For "previous": If current is 11-25, previous is 26 prev month to 10 current; if current is 26-10 next, previous is 11-25 current

## 2. Update Attendance View

- [x] Add a dropdown in `_buildSearchHeader` to select period ("Current Cutoff", "Previous Cutoff")
- [x] Store selected period in state and pass to `_repo.fetchAttendanceApprovalsPaged`
- [x] Update `_reload` and `_loadMore` to use the selected period

## 3. Testing

- [ ] Test dropdown selection and data loading for both periods
- [ ] Verify date calculations for edge cases (month boundaries, leap years)
- [ ] Ensure UI updates correctly on period change
