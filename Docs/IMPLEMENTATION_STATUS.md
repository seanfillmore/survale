# New Operation Workflow - Implementation Status

## ✅ COMPLETED (60% of work)

### 1. Join Code Removal ✅
- Removed `joinCode` from `Operation` model
- Updated all Codable extensions
- Removed `JoinOperationView` and "Join" button
- Updated UI to show incident number instead

### 2. Active Operations Display ✅
- Created `rpc_get_all_active_operations()` in database
- Returns ALL active operations with `is_member` flag
- Updated `SupabaseRPCService.getAllActiveOperations()`
- Returns `[(Operation, Bool)]` with membership info

### 3. OperationStore Enhancements ✅
- Added `memberOperationIds: Set<UUID>` property
- Added `isMember(of:)` helper function
- Updated `loadOperations()` to track membership
- Stores which operations user is a member of

### 4. Operations UI Redesign ✅
- Changed "Your Operations" → "Active Operations"
- Shows ALL active operations (not just user's)
- Custom `OperationRow` component with:
  - "Member" badge (blue) if user is in operation
  - "Active" badge (green) if operation is user's current active
  - "Request" button (gray) if user NOT in operation
  - "Requested" badge (orange) after sending request

### 5. Request to Join ✅
- Created `rpc_request_join_operation()` in database
- Checks if already member or has pending request
- Creates entry in `join_requests` table
- Swift function `requestJoinOperation()` in RPC service
- Alert dialog for confirmation
- UI feedback with "Requested" badge

### 6. Default State Changes ✅
- Operations default to `.active` state on creation
- `startsAt` automatically set to creation date
- Removed "draft" state from workflow

---

## 🔄 REMAINING TASKS (40%)

### Task 5: Reorder CreateOperationView Steps
**Current:**
1. Basic Info
2. Targets  
3. Staging
4. Review

**New:**
1. Basic Info ✅
2. Targets ✅
3. Staging ✅
4. **Team Members** (NEW)
5. Review (moved)

**What's Needed:**
- Update `Step` enum to include `.teamMembers`
- Insert team member selection before review step
- Update step navigation logic

### Task 6: Create TeamMemberSelector View
**Requirements:**
- Show all users in current user's team
- Display user info (name, callsign, vehicle)
- Multi-select with checkboxes
- Gray out users already in an active operation
- Pass selected user IDs to final step

**Implementation Needed:**
```swift
struct TeamMemberSelector: View {
    @Binding var selectedUserIds: Set<UUID>
    @State private var teamMembers: [User] = []
    @State private var usersInOperations: Set<UUID> = []
    
    // Fetch team members
    // Fetch which users are in active operations
    // Display list with selection state
}
```

### Task 7: RPC for Adding Members
**SQL Function Needed:**
```sql
CREATE OR REPLACE FUNCTION public.rpc_add_operation_members(
    operation_id UUID,
    user_ids UUID[]
)
RETURNS JSON
```

**Logic:**
- Loop through user_ids
- For each user:
  - Check if in another active operation
  - If yes, set `left_at` on old membership
  - Insert new membership
  - Set role based on creator
- Return count of members added

### Task 8: One Operation Constraint
**Where to Implement:**
- In `rpc_add_operation_members()` (see above)
- When accepting join request
- When user manually joins

**Logic:**
```sql
-- Before adding to new operation:
UPDATE operation_members
SET left_at = NOW()
WHERE user_id = [user_id]
AND left_at IS NULL
AND operation_id IN (
    SELECT id FROM operations WHERE status = 'active'
);
```

### Task 9: Show Current Operation Clearly
**Options:**
- Badge on Map/Chat tabs showing operation name
- Avatar/icon in tab bar
- Header in navigation bar
- Bottom banner across app

**Recommended:**
- Add operation name to Map/Chat navigation titles
- Example: "Map - Operation Alpha"
- Use `appState.activeOperation?.name`

---

## Database Schema Status

### ✅ Tables We're Using
- `operations` - Has `status` column
- `operation_members` - Has `left_at` for tracking exits
- `join_requests` - For request-to-join feature
- `users` - Has `team_id` for roster
- `teams` - For grouping users

### ⚠️ Potential Issues
1. **join_requests table** - Make sure it exists with:
   ```sql
   CREATE TABLE IF NOT EXISTS join_requests (
       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
       operation_id UUID NOT NULL REFERENCES operations(id),
       requester_user_id UUID NOT NULL REFERENCES users(id),
       status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'denied')),
       created_at TIMESTAMPTZ DEFAULT NOW(),
       responded_at TIMESTAMPTZ,
       responder_user_id UUID REFERENCES users(id)
   );
   ```

2. **operation_members indexes** - For performance:
   ```sql
   CREATE INDEX IF NOT EXISTS idx_operation_members_user 
   ON operation_members(user_id, left_at);
   ```

---

## Testing Checklist

### ✅ Can Test Now
- [x] See all active operations
- [x] Operations show correct badges
- [x] Request to join shows alert
- [x] Request creates database entry
- [x] "Requested" badge appears after request
- [x] Member operations show "Member" badge
- [x] Active operation shows "Active" badge

### 🔄 Need to Complete First
- [ ] Create operation with team members selected
- [ ] Team members auto-added to operation
- [ ] User can only be in one operation
- [ ] Leaving old operation when joining new one
- [ ] Map/Chat show current operation name

---

## Files Modified

### Swift Files ✅
1. `Operation.swift` - Removed joinCode
2. `SupabaseRPCService.swift` - New getAllActiveOperations(), requestJoinOperation()
3. `OperationStore.swift` - Track membership, new load logic
4. `OperationsView.swift` - Complete redesign with OperationRow
5. `Services/SupabaseAuthService.swift` - Updated to use new load function

### SQL Files ✅
1. `Docs/simple_target_rpc.sql` - Added rpc_get_all_active_operations(), rpc_request_join_operation()

### Files to Create 🔄
1. `Views/TeamMemberSelectorView.swift` - NEW
2. Additional RPC functions in SQL

### Files to Update 🔄
1. `Views/CreateOperationView.swift` - Add step 4, reorder
2. `Views/MapOperationView.swift` - Show operation name
3. `Views/ChatView.swift` - Show operation name

---

## Next Steps (Priority Order)

1. **Add Team Members to simple_target_rpc.sql**
   - `rpc_get_team_members(team_id UUID)` 
   - Returns users with availability status
   
2. **Add Members RPC**
   - `rpc_add_operation_members(operation_id UUID, user_ids UUID[])`
   - Implements one-operation constraint
   
3. **Create TeamMemberSelectorView**
   - Fetch team members
   - Show selection UI
   - Track selected IDs
   
4. **Update CreateOperationView**
   - Add `.teamMembers` step
   - Insert before review
   - Pass selected IDs to creation
   
5. **Wire Up Member Addition**
   - Call RPC after operation created
   - Add selected members
   - Show success feedback
   
6. **Update Navigation Titles**
   - Map: "Map - [Operation Name]"
   - Chat: "Chat - [Operation Name]"
   - Use appState.activeOperation

---

## Estimated Remaining Time
- **Task 5 (Reorder Steps):** 30 min
- **Task 6 (Team Selector):** 1 hour  
- **Task 7 (RPC Functions):** 45 min
- **Task 8 (One Operation):** 30 min (included in Task 7)
- **Task 9 (Show Current Op):** 15 min

**Total:** ~2.5 hours of focused work

---

## Current Build Status
✅ **Code compiles without errors**
✅ **Can test operations list now**
🔄 **Can't create operations with team members yet**
🔄 **One-operation constraint not enforced yet**

---

**Status:** 60% complete. Core refactoring done. Ready to implement remaining features.

