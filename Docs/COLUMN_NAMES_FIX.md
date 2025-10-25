# Column Names Fix - staging_areas

## Issue
Your `staging_areas` table uses `lat` and `lon` (not `latitude` and `longitude`).

## Fix Applied
Updated SQL functions to use the correct column names:
- INSERT: `staging_areas (operation_id, name, lat, lon)`
- SELECT: `sa.lat` and `sa.lon`

## What You Need to Do

### Re-run the SQL Script (Final Time!)

1. Open **Supabase SQL Editor**
2. Copy entire contents of `Docs/create_target_rpc_functions.sql`
3. Paste and click **Run**

The functions will be updated to use `lat` and `lon`.

### Then Test

Rebuild and run the app, create an operation with staging points.

Expected log:
```
💾 Saving 0 targets and 1 staging points to database...
  ✅ Saved staging point: HOJ
```

## Why the Confusion?

Different parts of your schema use different naming conventions:
- `staging_areas` → `lat`, `lon` (short form)
- Other tables might use `latitude`, `longitude` (long form)

The RPC functions now match YOUR actual database schema!

