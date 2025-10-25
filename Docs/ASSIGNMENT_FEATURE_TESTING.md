# Location Assignment Feature - Testing Guide

## Overview
The Location Assignment feature allows case agents to assign specific map locations to team members with turn-by-turn navigation. This guide covers setup, testing scenarios, and troubleshooting.

---

## Setup Instructions

### 1. Database Setup
Run the SQL script in Supabase SQL Editor:
```bash
File: Docs/run_assignment_feature.sql
```

This creates:
- `assigned_locations` table
- RLS policies
- 4 RPC functions
- Performance indexes

### 2. Verify Database Setup
Run these verification queries in Supabase:

```sql
-- Check table exists
SELECT EXISTS (
    SELECT FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'assigned_locations'
);

-- Check RLS is enabled
SELECT relrowsecurity 
FROM pg_class 
WHERE relname = 'assigned_locations';

-- Check all RPC functions exist
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE 'rpc_%assignment%';
```

Expected results:
- Table exists: `true`
- RLS enabled: `true`
- 4 functions: `rpc_assign_location`, `rpc_update_assignment_status`, `rpc_get_operation_assignments`, `rpc_cancel_assignment`

---

## Testing Scenarios

### Scenario 1: Case Agent Assigns Location

**Prerequisites:**
- User A is case agent of an active operation
- User B is a member of the operation
- Both users are logged in on separate devices

**Steps:**
1. **User A (Case Agent):**
   - Open the app and navigate to Map tab
   - Long-press (0.5s) on any location on the map
   - Assignment sheet should appear

2. **Fill Assignment Form:**
   - Select User B from "Assign To" picker
   - Enter label: "North Entry Point"
   - Enter notes: "Cover north entrance"
   - Tap "Assign Location"

3. **Expected Results:**
   - Success message in console
   - Sheet dismisses
   - Blue assignment marker appears on map with User B's callsign
   - Assignment immediately visible to all team members

**Console Logs to Check:**
```
🗺️ Long press at coordinate: 34.052200, -118.243700
👥 Loaded X team members for assignment
📍 Assigning location to user <UUID>
✅ Location assigned: <assignment_id>
```

---

### Scenario 2: Team Member Receives Assignment

**Prerequisites:**
- User B has been assigned a location (from Scenario 1)

**Steps:**
1. **User B (Team Member):**
   - Open Map tab
   - Assignment banner should appear at top of screen

2. **Banner Display:**
   - Shows "New Assignment"
   - Shows location label ("North Entry Point")
   - Shows distance from current location
   - Blue background color

3. **Tap Banner:**
   - Assignment detail view opens
   - Shows map with:
     * Blue marker at assigned location
     * Green marker at User B's location
   - Shows distance and time info

4. **Tap "I'm On My Way":**
   - Status changes to "En Route"
   - Banner color changes to orange
   - Status persists across app restarts

5. **Tap "Start Navigation":**
   - Apple Maps opens
   - Turn-by-turn directions to assigned location
   - Automatically marks as "En Route"

**Expected Console Logs:**
```
⚡️ Realtime: New assigned location inserted: <assignment_id>
✅ Assignment <assignment_id> status updated to en_route
🧭 Starting navigation to North Entry Point
```

---

### Scenario 3: Arrival and Completion

**Prerequisites:**
- User B is "En Route" to assignment

**Steps:**
1. **User B arrives at location:**
   - Open assignment detail view
   - Tap "I've Arrived"

2. **Expected Results:**
   - Status changes to "Arrived"
   - Marker on map turns green
   - Banner shows "Assignment Complete"
   - View dismisses after 1.5 seconds
   - Assignment may remain visible or auto-clear

**Console Logs:**
```
🎯 Marking arrived at assignment <assignment_id>
✅ Assignment <assignment_id> status updated to arrived
```

---

### Scenario 4: Cancel Assignment

**Prerequisites:**
- User A (case agent) has assigned a location

**Steps:**
1. **User A:**
   - View assignments in operation (TODO: implement UI for this)
   - Swipe left on assignment
   - Tap "Cancel"

2. **Expected Results:**
   - Assignment status changes to "Cancelled"
   - Marker turns gray on map
   - User B's banner disappears
   - Assignment remains in history but marked cancelled

**Alternative (via code):**
```swift
try await AssignmentService.shared.cancelAssignment(
    assignmentId: assignmentId
)
```

---

## Map Features

### Long Press Gesture
- **Duration:** 0.5 seconds
- **Only visible to:** Case agents
- **Action:** Opens assignment sheet
- **Coordinate Conversion:** Uses MapReader proxy

### Assignment Markers
- **Blue with status icon:** Assigned/En Route
- **Green:** Arrived
- **Gray:** Cancelled
- **Label:** Shows assignee's callsign below marker

### Assignment Banner
- **Position:** Top of map view
- **Content:**
  * Status text
  * Location label
  * Distance from user
- **Colors:**
  * Blue: Assigned
  * Orange: En Route
  * Green: Arrived

---

## Real-time Updates

### Automatic Synchronization
All changes are instantly visible to:
- Case agent
- Assigned team member
- All other operation members (viewing map)

### Subscription Details
- Channel: `db-changes-assigned-locations`
- Events: INSERT, UPDATE, DELETE
- Filter: By operation_id
- Reconnection: Automatic via Supabase SDK

### Testing Real-time:
1. Open app on two devices with different users
2. User A assigns location to User B
3. Verify User B sees banner within 1-2 seconds
4. User B updates status to "En Route"
5. Verify User A sees marker color change within 1-2 seconds

---

## Error Scenarios

### 1. Non-Case Agent Attempts Assignment
**Expected:**
- Long press does nothing
- Console: `⚠️ Only case agents can assign locations`

### 2. Assign to Non-Member
**Expected:**
- RPC error: "User is not an active member of this operation"
- Sheet remains open with error message

### 3. Network Failure During Assignment
**Expected:**
- Error message in sheet: "Failed to assign location: [error details]"
- Sheet remains open
- User can retry

### 4. Offline Mode
**Expected:**
- Assignment creation fails with network error
- Local cache shows last known assignments
- Real-time updates resume when back online

---

## Performance Expectations

### Response Times
- **Map long-press to sheet:** < 100ms
- **Assignment creation:** < 500ms
- **Real-time notification:** < 2s
- **Status update:** < 300ms

### Database Queries
All RPC functions are optimized with:
- Indexed lookups on `operation_id`, `assigned_to_user_id`
- Efficient JOINs with users table
- Minimal data transfer (only needed fields)

---

## Troubleshooting

### Assignment markers not appearing
**Check:**
1. `AssignmentService.shared.assignedLocations` populated?
2. Console for fetch errors
3. RLS policies allow SELECT for current user
4. Operation ID matches between assignment and active operation

**Fix:**
```swift
// Force refresh
await AssignmentService.shared.fetchAssignments(for: operationId)
```

### Long press not working
**Check:**
1. Is current user the case agent?
2. Is there an active operation?
3. MapReader gesture not conflicting with map controls

**Fix:**
- Ensure `isCaseAgent` computed property returns true
- Check `store.activeOperations` contains operation with matching case_agent_id

### Real-time updates not working
**Check:**
1. Supabase Realtime enabled for `assigned_locations` table
2. RLS policies allow SELECT
3. Operation ID filter correct
4. Channel subscription successful

**Fix:**
```swift
// Manually resubscribe
await AssignmentService.shared.setupRealtimeSubscription(for: operationId)
```

### Distance not calculating
**Check:**
1. LocationService has `lastLocation`
2. Location permissions granted
3. Assignment has valid lat/lon

**Fix:**
- Request location permission
- Verify assignment coordinate is valid

---

## Known Limitations (MVP)

1. **No assignment list view for case agents**
   - Can only see assignments on map
   - TODO: Add dedicated assignments management view

2. **Single assignment per user**
   - UI assumes one active assignment per user
   - Multiple assignments not well supported

3. **No assignment history**
   - Completed/cancelled assignments only in database
   - TODO: Add history view

4. **No assignment notifications**
   - Banner only shows when map is open
   - TODO: Add push notifications

5. **No distance-based alerts**
   - No auto-notification when near assigned location
   - TODO: Add geofencing

---

## Success Criteria

Feature is working correctly if:
- ✅ Case agent can assign locations via long press
- ✅ Team members see assignment banner immediately
- ✅ Status updates (assigned → en route → arrived) work
- ✅ Navigation to Apple Maps works
- ✅ Real-time updates work across devices
- ✅ Assignment markers appear on map
- ✅ Distance calculation is accurate
- ✅ RLS prevents unauthorized access

---

## Next Steps

After successful testing:
1. Merge feature branch to main
2. Deploy to TestFlight
3. Gather user feedback
4. Implement enhancements:
   - Assignment management UI for case agents
   - Push notifications for new assignments
   - Assignment history view
   - Geofencing for auto-arrival
   - Voice navigation integration

---

## Support

For issues or questions:
1. Check console logs for detailed error messages
2. Verify database setup with verification queries
3. Review `Docs/FEATURE_ASSIGN_LOCATIONS.md` for implementation details
4. Check Supabase dashboard for RLS policy issues

