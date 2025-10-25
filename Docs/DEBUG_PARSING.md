# Debug Operation Parsing Issues

## Problem
```
⚠️ Skipping operation with invalid data: Pied Piper (repeated 9 times)
```

Operations are being fetched from the database but failing to parse into Swift objects.

## Likely Causes

1. **NULL values** in required fields (team_id, agency_id, created_at)
2. **Invalid UUID format** in ID fields
3. **Invalid timestamp format** in date fields

## Step 1: Run Diagnostic Query

In Supabase SQL Editor, run:
```
Docs/debug_operations.sql
```

This will show:
- Raw operation data
- Data types of columns
- Count of NULL values

## Step 2: Rebuild and Check Console

The app now has enhanced logging. When you rebuild (Cmd+Shift+K, Cmd+B, Cmd+R) and try to load operations, you'll see:

```
🔄 Loaded 9 operations from database
   📦 Raw operation: Pied Piper
      id: [uuid-string]
      case_agent_id: [uuid-string]
      team_id: [uuid-string or NULL]
      agency_id: [uuid-string or NULL]
      created_at: [timestamp-string]
      ❌ Invalid team_id: NULL  <-- This shows the problem!
```

## Common Issues & Fixes

### Issue 1: NULL team_id or agency_id

**Problem:** Operations created before MVP setup don't have team/agency assigned.

**Fix in Supabase:**
```sql
-- Get the MVP team/agency IDs
SELECT id FROM teams WHERE name = 'MVP Team' LIMIT 1;
SELECT id FROM agencies WHERE name = 'MVP Agency' LIMIT 1;

-- Update operations with NULL values
UPDATE operations
SET 
    team_id = '[MVP-TEAM-ID]',
    agency_id = '[MVP-AGENCY-ID]'
WHERE team_id IS NULL OR agency_id IS NULL;
```

### Issue 2: NULL created_at

**Problem:** Operations missing creation timestamp.

**Fix in Supabase:**
```sql
UPDATE operations
SET created_at = NOW()
WHERE created_at IS NULL;
```

### Issue 3: Invalid UUID Format

**Problem:** IDs are not valid UUIDs.

**Check in Supabase:**
```sql
SELECT id, name
FROM operations
WHERE 
    id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    OR case_agent_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    OR team_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    OR agency_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
```

If this returns rows, those operations have corrupted IDs.

### Issue 4: Invalid Timestamp Format

**Problem:** created_at not in ISO8601 format.

**Check data type:**
```sql
SELECT data_type 
FROM information_schema.columns
WHERE table_name = 'operations' 
AND column_name = 'created_at';
```

Should be: `timestamp with time zone` or `timestamptz`

## Most Likely Fix

Based on "Pied Piper" being repeated 9 times, you probably have 9 operations with NULL team_id or agency_id.

**Quick Fix:**
```sql
-- 1. Get MVP team/agency IDs
SELECT id, name FROM teams WHERE name LIKE '%MVP%';
SELECT id, name FROM agencies WHERE name LIKE '%MVP%';

-- 2. Update all operations (replace with actual IDs from step 1)
UPDATE operations
SET 
    team_id = COALESCE(team_id, (SELECT id FROM teams WHERE name = 'MVP Team')),
    agency_id = COALESCE(agency_id, (SELECT id FROM agencies WHERE name = 'MVP Agency'))
WHERE team_id IS NULL OR agency_id IS NULL;

-- 3. Verify
SELECT COUNT(*) as fixed_operations
FROM operations
WHERE team_id IS NOT NULL AND agency_id IS NOT NULL;
```

## After Fixing

1. **Don't rebuild** - no code changes needed
2. **Just restart the app** in Xcode (Cmd+R)
3. Console should show:
```
🔄 Loaded 9 operations from database
   📦 Raw operation: Pied Piper
      ...all fields valid...
  ✅ Loaded: Pied Piper (draft)
✅ Loaded 9 operations
```

## Prevention

To prevent this in the future, ensure `rpc_create_operation` always sets team_id and agency_id from the authenticated user's context.

Check:
```sql
SELECT routine_definition
FROM information_schema.routines
WHERE routine_name = 'rpc_create_operation';
```

Should include:
```sql
INSERT INTO operations (
    ...,
    team_id,
    agency_id
) VALUES (
    ...,
    (SELECT team_id FROM users WHERE id = auth.uid()),
    (SELECT agency_id FROM users WHERE id = auth.uid())
);
```

---

Run the diagnostic query and check the console output - the enhanced logging will pinpoint exactly which field is causing the issue!

