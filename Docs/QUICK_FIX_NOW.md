# QUICK FIX - Operations Not Showing

## The Problem
Operations are being created but not appearing in the list.

## Likely Causes
1. Operations created with `status = 'draft'` (query filters for 'active')
2. You're not added as a member to your own operations
3. RPC function `rpc_create_operation` needs updating

---

## 🚀 IMMEDIATE FIX (Run in Supabase)

### Step 1: Diagnose
Run this to see what's wrong:
```sql
-- See all operations
SELECT name, status, created_at FROM operations ORDER BY created_at DESC LIMIT 5;

-- Check if you're a member
SELECT o.name, om.role 
FROM operation_members om
JOIN operations o ON om.operation_id = o.id
WHERE om.user_id = auth.uid();
```

### Step 2: Quick Fix - Make Operations Active
```sql
-- Fix all draft operations
UPDATE operations 
SET status = 'active' 
WHERE status = 'draft';
```

### Step 3: Quick Fix - Add Yourself as Member
```sql
-- Add yourself to your own operations if missing
INSERT INTO operation_members (operation_id, user_id, role, joined_at)
SELECT o.id, o.case_agent_id, 'case_agent', o.created_at
FROM operations o
WHERE o.case_agent_id = auth.uid()
AND NOT EXISTS (
    SELECT 1 FROM operation_members om
    WHERE om.operation_id = o.id
    AND om.user_id = auth.uid()
);
```

### Step 4: Update RPC Function
Run the entire file:
```
Docs/create_rpc_functions.sql
```

This updates `rpc_create_operation()` to:
- Create operations as `'active'` (not 'draft')
- Automatically add creator as member

---

## ✅ Test After Fixing

1. **Restart app or go back to Operations tab**
2. **Check console:**
```
🔄 Loaded 1+ active operations from database  ← Should show your operations!
   👤 You are in: [Operation Name]
```

3. **Operations list should show:**
   - Your operations
   - Blue "Member" badge
   - Green "Active" badge when selected

---

## 🔍 Still Not Working?

Run the diagnostic script:
```
Docs/diagnose_missing_operations.sql
```

This will show:
- All operations in database
- Your memberships
- What the RPC function returns

---

## 📝 Root Cause

The old workflow had operations start as "draft" and become "active" when started. The new workflow has them "active" immediately, but the database function wasn't updated.

Also, sometimes the `operation_members` insert fails silently, so you're not added as a member.

---

## 💡 Alternative: Recreate RPC Function

If quick fixes don't work, recreate the function from scratch:

```sql
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
    -- Get user context
    SELECT team_id, agency_id INTO user_team_id, user_agency_id
    FROM users WHERE id = auth.uid();
    
    IF user_team_id IS NULL OR user_agency_id IS NULL THEN
        RAISE EXCEPTION 'User not assigned to team/agency';
    END IF;
    
    -- Create operation as ACTIVE
    INSERT INTO operations (
        id, name, incident_number, agency_id, team_id, 
        case_agent_id, status, created_at, started_at
    )
    VALUES (
        gen_random_uuid(), name, incident_number, 
        user_agency_id, user_team_id, auth.uid(),
        'active', NOW(), NOW()  -- Active immediately!
    )
    RETURNING id INTO new_operation_id;
    
    -- Add creator as member
    INSERT INTO operation_members (
        operation_id, user_id, role, joined_at
    )
    VALUES (
        new_operation_id, auth.uid(), 'case_agent', NOW()
    );
    
    RETURN json_build_object('operation_id', new_operation_id);
END;
$$;
```

---

**Status:** Run Steps 2 & 3 in Supabase → Restart app → Operations should appear! 🎉

