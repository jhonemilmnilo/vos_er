# TODO: Fix Department Update Issue

## Problem

When updating the department of a specific employee in the database, the app does not update the department information immediately. This affects both the profile view and approval permissions.

## Root Cause

The UserPermissionsService caches user data (including department) for 30 minutes. When the department is updated in the database, the cache holds the old department data, causing the app to display outdated information.

## Solution Implemented

- Modified `ProfileNotifier` to accept `UserPermissionsService` as a dependency
- Updated `refreshProfileData()` to clear the user permissions cache before fetching fresh profile data
- This ensures that department updates are reflected immediately when the profile is refreshed

## Files Modified

- `lib/state/dashboard_provider.dart`: Updated ProfileNotifier to clear permissions cache on refresh

## Testing

- Refresh the profile after updating department in database
- Verify that the new department appears in the profile view
- Check that approval permissions are updated accordingly

## Status

✅ Completed: Cache clearing implemented in profile refresh
✅ Fixed: Constructor updated to accept UserPermissionsService parameter
