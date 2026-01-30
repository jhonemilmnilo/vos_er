# TODO: Add Status Filter to Attendance Approval View

## Tasks

- [ ] Add status filter state variable to AttendanceApprovalView
- [ ] Add status dropdown in \_buildSearchHeader method
- [ ] Update \_reload and \_loadMore methods to use selected status
- [ ] Modify AttendanceApprovalGroup to handle approved entries
- [ ] Update \_AttendanceGroupCard to show approved status appropriately
- [ ] Adjust total count calculation for selected status
- [ ] Update empty state messages based on status filter
- [ ] Test the filter functionality

## Notes

- Use AttendanceStatus enum for filter options
- Default to pending status to maintain current behavior
- Approved entries should not show action buttons
- Update repository calls to pass the selected status
