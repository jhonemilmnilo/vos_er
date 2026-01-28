# TODO: Implement Attendance Approval Date Limitation

## Tasks

- [x] Modify `fetchAttendanceApprovalsPaged` method in `attendance_repository.dart` to add date range filters for pending approvals based on current day
- [x] Add helper method to calculate date range (11-25 or 26-10) based on current date
- [x] Apply filters only when status is "pending"
- [x] Test the implementation to ensure correct filtering

# TODO: Consolidate Three Apps into One with Department Selection

## Tasks

- [x] Create Department Configuration (lib/core/config/department_config.dart)
  - Define department enum/model with name, port, and baseUrl
  - Create list of available departments: Hanvin (8092), Human Resources (8091), Vertix (8090)

- [x] Create Host Selection Provider (lib/state/host_provider.dart)
  - Provider to manage selected department
  - Load/save selection using shared_preferences
  - Clear session data when department changes

- [x] Create Host Selection Screen (lib/ui/auth/host_selection_page.dart)
  - UI with cards/buttons for each department
  - Persist selection and navigate to login

- [x] Update API Client Provider (lib/app.dart)
  - Make apiClientProvider dynamic based on selected host
  - Update authRepositoryProvider accordingly

- [x] Modify AuthGate (lib/app.dart)
  - Check if department is selected; if not, show host selection screen
  - Update flow: Host Selection → AuthGate → Login/Shell

## Followup Steps

- [ ] Test department selection persistence across app restarts
- [ ] Verify API calls use correct host after selection
- [ ] Test session clearing when switching departments
- [ ] Run app on device/emulator to ensure smooth flow

# TODO: Fix Department Selection Provider Consolidation

## Tasks

- [x] Remove old branchProvider from app_providers.dart
- [x] Update apiClientProvider in app_providers.dart to use hostProvider
- [x] Update profile_view.dart to use hostProvider instead of branchProvider
- [x] Update login_page.dart to use hostProvider instead of branchProvider
- [x] Add logout functionality to clear selected department
- [x] Test that department selection works correctly and API calls use the right port

# TODO: Fix Authentication Tokens for Different Departments

## Tasks

- [x] Add token field to Department class
- [x] Update apiClientProvider to use department-specific tokens
- [x] Configure tokens: HR (8091) uses token, Hanvin (8092) and Vertix (8090) don't require tokens
- [x] Update ApiClient to handle empty tokens properly
- [ ] Test login functionality for all departments
