# Quick Fix - created_by Column

## Issue
The `targets` table is missing the `created_by` column, causing insert errors.

## Solution

### Option 1: If targets table already exists (RECOMMENDED)
Run `Docs/fix_targets_table.sql` in Supabase SQL Editor.

This will:
- Check if `created_by` column exists
- Add it if missing
- Do nothing if already exists

### Option 2: Recreate everything (if no data yet)
1. Drop existing tables:
```sql
DROP TABLE IF EXISTS target_location CASCADE;
DROP TABLE IF EXISTS target_vehicle CASCADE;
DROP TABLE IF EXISTS target_person CASCADE;
DROP TABLE IF EXISTS targets CASCADE;
```

2. Run `Docs/create_target_tables.sql` (updated version)
3. Run `Docs/create_target_rpc_functions.sql` (updated version)

## After Running

Re-run the updated RPC functions:
- Run `Docs/create_target_rpc_functions.sql`

This updates the INSERT statements to include `created_by = auth.uid()`.

## Test

Create a new operation with targets. Expected output:
```
💾 Saving 3 targets and 1 staging points to database...
  ✅ Saved target: John Doe
  ✅ Saved target: Blue Honda Civic
  ✅ Saved target: 2680 Tapo Canyon Rd, Simi Valley, 93063
  ✅ Saved staging point: HOJ
```

## Verify in Database

```sql
SELECT 
    t.id,
    t.type,
    t.created_by,
    u.email as created_by_email
FROM targets t
LEFT JOIN auth.users u ON t.created_by = u.id
ORDER BY t.created_at DESC
LIMIT 5;
```

You should see your user ID in `created_by` column.

