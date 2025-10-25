# Final SQL Fix - Parameter Order

## Problem
PostgreSQL error: "input parameters after one with a default value must also have defaults"

## Cause
Function parameters must have required parameters first, then optional parameters.

**Before (WRONG):**
```sql
rpc_create_location_target(
    operation_id UUID,
    label TEXT DEFAULT NULL,      -- ❌ Optional parameter
    address TEXT,                  -- ❌ Required after optional
    city TEXT DEFAULT NULL,
    ...
)
```

**After (CORRECT):**
```sql
rpc_create_location_target(
    operation_id UUID,
    address TEXT,                  -- ✅ Required first
    label TEXT DEFAULT NULL,       -- ✅ Optional after required
    city TEXT DEFAULT NULL,
    ...
)
```

## Fix Applied

Updated 3 files to match new parameter order:
1. ✅ `simple_target_rpc.sql` - Fixed SQL function signature
2. ✅ `SupabaseRPCService.swift` - Updated iOS function signature
3. ✅ `OperationStore.swift` - Updated function call

## Action Required

**Re-run SQL script** in Supabase SQL Editor:
- `Docs/simple_target_rpc.sql`

This will recreate the function with the correct parameter order.

## Then Test

1. Rebuild app (Cmd+B, Cmd+R)
2. Create operation with location target
3. Add custom label: "Test Location"
4. Select address
5. Add target
6. Go to Map
7. Should see "Test Location" label (no duplicates!)

## Expected Console Output

```
💾 Saving 1 targets and 1 staging points to database...
  ✅ Saved target: Test Location
  ✅ Saved staging point: Base Camp
Operation created successfully

🔄 Loading targets for operation: [uuid]
🔍 RPC Response: 1 targets, 1 staging
   🎯 Target from DB: location - [id]
      Location: Test Location - has coordinates: true - lat:34.x, lng:-118.x
✅ Converted 1 targets
📍 Loaded 1 targets and 1 staging points
```

## Parameter Order Rule

In PostgreSQL (and most languages):
- ✅ Required parameters FIRST
- ✅ Optional parameters (with DEFAULT) LAST
- ❌ Never mix them!

This is now fixed and should work perfectly! 🎉

