# Fix: Operations Not Showing After Creation

## Problem
```
💾 Saving 1 targets and 1 staging points to database...
  ✅ Saved target: L1
  ✅ Saved staging point: EVJ
🔄 Loading all active operations...
🔄 Loaded 0 active operations from database
```

Operation was created successfully, but doesn't appear in the list.

## Root Cause
- `rpc_create_operation()` creates operations with `status = 'draft'`
- `rpc_get_all_active_operations()` only returns operations with `status = 'active'`
- **Mismatch:** Draft operations are invisible!

## Solution

### Update Database Function

Run this in Supabase SQL Editor:

```sql
-- Update rpc_create_operation to create 'active' operations
CREATE OR REPLACE FUNCTION public.rpc_create_operation(
    name TEXT,
    incident_number TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_operation_id UUID;
    user_team_id UUID;
    user_agency_id UUID;
BEGIN
    -- Get current user's team and agency
    SELECT team_id, agency_id INTO user_team_id, user_agency_id
    FROM users
    WHERE id = auth.uid();
    
    IF user_team_id IS NULL OR user_agency_id IS NULL THEN
        RAISE EXCEPTION 'User not assigned to team/agency';
    END IF;
    
    -- Create operation
    INSERT INTO operations (
        id,
        name,
        incident_number,
        agency_id,
        team_id,
        case_agent_id,
        status,
        created_at
    )
    VALUES (
        gen_random_uuid(),
        name,
        incident_number,
        user_agency_id,
        user_team_id,
        auth.uid(),
        'active',  -- Changed from 'draft' to 'active'
        NOW()
    )
    RETURNING id INTO new_operation_id;
    
    -- Add creator as a member with case_agent role
    INSERT INTO operation_members (
        operation_id,
        user_id,
        role,
        joined_at
    )
    VALUES (
        new_operation_id,
        auth.uid(),
        'case_agent',
        NOW()
    );
    
    RETURN json_build_object('operation_id', new_operation_id);
END;
$$;
```

**OR** just run the entire updated file:
```
Docs/create_rpc_functions.sql
```

### Fix Existing Draft Operations (Optional)

If you have operations already created as draft, update them:

```sql
-- Make all draft operations active
UPDATE operations
SET status = 'active'
WHERE status = 'draft';
```

---

## After Fixing

1. **Restart app** (or just go back to Operations tab)
2. **Create new operation**
3. **Expected console output:**
```
💾 Creating operation...
  ✅ Saved target: [name]
  ✅ Saved staging point: [name]
🔄 Loading all active operations...
🔄 Loaded 1 active operations from database  ← Should show 1+ now!
  ✅ My Operation - Member: Yes
✅ Loaded 1 active operations
   👤 You are in: My Operation
   • My Operation - ✅ Member
```

4. **Operations list should show:**
   - Your newly created operation
   - With "Member" badge (blue)
   - With "Active" badge (green) if you tapped it

---

## Why This Happened

In the old workflow:
1. Operations started as "draft"
2. User would click "Start Operation" → changed to "active"
3. Join code system allowed joining draft operations

In the new workflow:
1. Operations are "active" immediately when created
2. No draft state (simplified)
3. Team members added during creation (not implemented yet)

The database function wasn't updated to match the new workflow.

---

## Verification

Check your operations status in Supabase:

```sql
SELECT name, status, created_at
FROM operations
ORDER BY created_at DESC
LIMIT 5;
```

Should show `status = 'active'` for all new operations.

---

**Status:** Fixed in code ✅ | Need to re-run SQL ✅ | Then operations will appear! 🎉

