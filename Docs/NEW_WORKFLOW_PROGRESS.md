# New Operation Workflow - Implementation Progress

## User's Requirements

### Operation Visibility
- ✅ Show ALL active operations (not just user's)
- ✅ Users can see operations they're NOT involved in
- 🔄 Users can request to join operations they're not in
- ✅ Hide draft and ended operations

### One Active Operation Rule
- 🔄 User can only be in ONE active operation at a time
- 🔄 Auto-leave previous operation when joining new one

### Operation Creation (5 Steps)
1. Basic Info (name, incident number)
2. Targets
3. Staging Points
4. **NEW:** Select Team Members (roster)
   - Show all users in team
   - Gray out users already in an operation
   - Multi-select available users
   - On create: Add selected users + send notifications
5. Review

### States
- ✅ Remove "draft" state
- ✅ **Active:** Operation is ongoing (default for new operations)
- ✅ **Ended:** Operation is completed

### Join Code
- ✅ Remove completely (UI + database)

---

## Progress Summary

### ✅ COMPLETED

#### 1. Remove Join Code
- ✅ Removed `joinCode` from `Operation` model
- ✅ Removed from `Codable` extension (encode/decode)
- ✅ Updated `OperationStore.create()` to not generate join codes
- ✅ Updated `OperationsView` to show incident number instead of join code
- ✅ Removed `find(byJoinCode:)` function, added `find(byId:)`
- ✅ Removed `joinCode` from `SupabaseRPCService.getUserOperations()`

#### 2. Database RPC for Active Operations
- ✅ Created `rpc_get_all_active_operations()` in SQL
- ✅ Returns ALL active operations (not filtered by user)
- ✅ Includes `is_member` flag to show if current user is in operation
- ✅ Filters for `status = 'active'` only
- ✅ Updated Swift service to `getAllActiveOperations()` returning `[(Operation, Bool)]`

#### 3. Default State Changes
- ✅ Operations now default to `.active` state when created
- ✅ `startsAt` set to creation date automatically

---

## 🔄 IN PROGRESS

### Current Task: Update OperationStore
Need to update `OperationStore.loadOperations()` to use new signature:
```swift
// OLD:
func loadOperations(for userID: UUID) async
let operations: [Operation] = try await rpcService.getUserOperations()

// NEW:
func loadOperations(for userID: UUID) async
let results: [(operation: Operation, isMember: Bool)] = try await rpcService.getAllActiveOperations()
```

Then update auth service to pass membership info.

---

## 📋 REMAINING TASKS

### 3. Update OperationsView (Next)
- Show ALL active operations
- Add "Request to Join" button for non-member operations
- Show "You're in this operation" badge for member operations
- Update section title from "Your Operations" to "Active Operations"

### 4. Add Request to Join Functionality
- Create `RequestToJoinView` or inline button
- RPC function: `rpc_request_join_operation(operation_id UUID)`
- Notify operation creator

### 5. Reorder CreateOperationView Steps
- Step 1: Basic Info ✅
- Step 2: Targets ✅
- Step 3: Staging ✅
- Step 4: Team Members (NEW)
- Step 5: Review (moved from step 4)

### 6. Create TeamMemberSelector View
- Fetch all users in user's team
- Show list with checkboxes
- Gray out users already in an active operation
- Multi-select functionality
- Pass selected user IDs to next step

### 7. Create RPC Function for Adding Members
```sql
CREATE OR REPLACE FUNCTION public.rpc_add_operation_members(
    operation_id UUID,
    user_ids UUID[]
)
```
- Add multiple members at once
- Check "one operation" constraint
- Auto-leave previous operations if needed

### 8. Implement One Operation Constraint
- When user joins operation, check if they're in another active one
- If yes, automatically set `left_at` on previous membership
- Update `AppState.activeOperationID` to new operation

### 9. Update UI for Current Operation
- Clearly show which operation user is currently in
- Maybe add avatar/icon in tab bar?
- Badge on Map/Chat tabs showing operation name?

### 10. Remove JoinOperationView
- Delete `Views/JoinOperationView.swift`
- Remove "Join" button from `OperationsView` toolbar
- Remove sheet binding

---

## Files Modified So Far

### Swift Files ✅
- `/Users/seanfillmore/Code/Survale/Survale/Operation.swift`
  - Removed `joinCode` property
  - Updated init to default `state = .active`
  - Removed `joinCode` from `Codable` extension
  - Updated `mock()` function

- `/Users/seanfillmore/Code/Survale/Survale/Services/SupabaseRPCService.swift`
  - Renamed `getUserOperations()` to `getAllActiveOperations()`
  - Changed return type to include `isMember` flag
  - Updated RPC call to `rpc_get_all_active_operations`

- `/Users/seanfillmore/Code/Survale/Survale/OperationStore.swift`
  - Removed join code generation in `create()`
  - Set `state = .active` by default
  - Set `startsAt = Date()` on creation
  - Changed `find(byJoinCode:)` to `find(byId:)`

- `/Users/seanfillmore/Code/Survale/Survale/Views/OperationsView.swift`
  - Changed "Join code" display to "Incident" number

### SQL Files ✅
- `/Users/seanfillmore/Code/Survale/Survale/Docs/simple_target_rpc.sql`
  - Created `rpc_get_all_active_operations()`
  - Returns ALL active operations
  - Includes `is_member` subquery
  - Filters `WHERE status = 'active'`

---

## Next Steps (Priority Order)

1. **Finish OperationStore update** (in progress)
2. **Update OperationsView** to show all active operations with request buttons
3. **Create TeamMemberSelector view** for step 4
4. **Create RPC for adding members** bulk operation
5. **Implement one-operation constraint** in RPC
6. **Reorder CreateOperationView steps**
7. **Add request-to-join functionality**
8. **Remove JoinOperationView** and related UI
9. **Update UI to show current operation clearly**

---

## Testing Plan (After Implementation)

### Test 1: See All Active Operations
1. User A creates Operation "Alpha"
2. User B logs in
3. ✅ User B should see Operation "Alpha" in list
4. ✅ Should show "Request to Join" button

### Test 2: One Operation Constraint
1. User A creates and joins Operation "Alpha"
2. User A creates Operation "Bravo"
3. User A joins Operation "Bravo"
4. ✅ User A should auto-leave "Alpha"
5. ✅ Only "Bravo" should show as active for User A

### Test 3: Team Member Selection
1. User A creates new operation
2. Goes to step 4 (Team Members)
3. ✅ Sees all team members
4. ✅ Members in other operations are grayed out
5. ✅ Can select multiple available members
6. ✅ Selected members added on operation creation

### Test 4: No Join Code
1. Create operation
2. ✅ No join code generated
3. ✅ No join code displayed
4. ✅ No "Join" button in UI
5. ✅ Can only join via invitation or request

---

## Database Schema Changes Needed

### operations table
- ❌ Don't need `join_code` column anymore (can ignore if exists)
- ✅ `status` column exists (`active`, `ended`)

### operation_members table
- ✅ `left_at` column for tracking when user left

### New RPC Functions Needed
1. `rpc_get_all_active_operations()` ✅ Created
2. `rpc_request_join_operation(operation_id UUID)` - Creates join request
3. `rpc_add_operation_members(operation_id UUID, user_ids UUID[])` - Bulk add
4. `rpc_leave_operation(operation_id UUID)` - Leave current operation
5. `rpc_get_team_members(team_id UUID)` - Get roster with availability

---

**Status:** ~40% complete. Core refactoring done, now implementing new features.

**Est. Remaining:** ~2-3 hours of focused implementation + testing

