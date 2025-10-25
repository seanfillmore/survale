# Setup Targets & Staging Points for MVP

## Overview
This guide will help you add RPC functions to your Supabase database for creating and fetching targets and staging points.

## What Changed
✅ **Database Persistence**: All targets and staging points now save to Supabase
✅ **Multi-Device Support**: Changes sync across all devices in real-time
✅ **Map Display**: Targets show as RED pins, staging points as GREEN pins
✅ **Crash Recovery**: Data persists even if app crashes

## Step 1: Run SQL Script

1. Open your Supabase project dashboard
2. Go to **SQL Editor**
3. Open the file `create_target_rpc_functions.sql`
4. Copy and paste the entire contents into the SQL Editor
5. Click **Run**

You should see:
```
✅ All target/staging RPC functions created!
```

## Step 2: Verify Functions Were Created

Run this query to check:
```sql
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema = 'public'
AND (routine_name LIKE 'rpc_%target%' OR routine_name LIKE 'rpc_%staging%')
ORDER BY routine_name;
```

You should see:
- `rpc_create_location_target`
- `rpc_create_person_target`
- `rpc_create_staging_point`
- `rpc_create_vehicle_target`
- `rpc_get_operation_targets`

## Step 3: Test the App

1. **Rebuild** the app in Xcode (Cmd+B)
2. **Run** the app (Cmd+R)
3. **Create a new operation** with:
   - 1 person target
   - 1 vehicle target
   - 1 location target
   - 1 staging point

### Expected Behavior

**During Creation:**
```
💾 Saving 3 targets and 1 staging points to database...
  ✅ Saved target: John Doe
  ✅ Saved target: Blue Honda Civic
  ✅ Saved target: 123 Main St
  ✅ Saved staging point: Base Camp
Operation created successfully
```

**On Map View:**
- You should see RED pins for all targets
- You should see a GREEN pin for the staging point
- Each pin should show the label when tapped
```
📍 Loaded 3 targets and 1 staging points
```

## Troubleshooting

### If you see "Could not find the function rpc_create_person_target"
- Make sure you ran the SQL script in Step 1
- Check that the functions exist using the verification query in Step 2

### If targets don't appear on map
- Check the console for "📍 Loaded X targets and Y staging points"
- If it says "Loaded 0 targets", check that:
  - The operation was created successfully
  - You're a member of the operation
  - The RLS policies allow you to read targets

### If you see "User not a member of this operation"
- The RPC functions check that you're a member before saving
- This should auto-happen when you create an operation
- Check `operation_members` table to verify

## Database Schema

### Tables Used
- `targets` - Main targets table (polymorphic)
- `target_person` - Person-specific fields
- `target_vehicle` - Vehicle-specific fields
- `target_location` - Location-specific fields
- `staging_areas` - Staging points

### Security
All RPC functions include:
- Authentication checks (must be logged in)
- Authorization checks (must be operation member)
- Row-level security (RLS) enforcement

## Next Steps

Once this is working:
1. Test creating operations on multiple devices
2. Verify that targets sync between devices
3. Test that targets persist after force-quitting the app
4. Ready to add more testers to your MVP!

