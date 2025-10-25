# Quick Fix - Staging Areas Column Name

## Issue
The `staging_areas` table uses `name` instead of `label` as the column name.

## Fix
Re-run the updated SQL script:

1. Open Supabase SQL Editor
2. Copy and paste the **entire** contents of `create_target_rpc_functions.sql`
3. Click **Run**

## What Changed
Updated these functions to use `name` column:
- `rpc_create_staging_point` - INSERT uses `name`
- `rpc_get_operation_targets` - SELECT uses `name` and returns it as `label`

## After Running
Rebuild and run the app. Creating operations with staging points should now work!

Expected log:
```
💾 Saving 3 targets and 1 staging points to database...
  ✅ Saved target: John Doe
  ✅ Saved target: Blue Honda
  ✅ Saved target: 123 Main St
  ✅ Saved staging point: HOJ
Operation created successfully
```

