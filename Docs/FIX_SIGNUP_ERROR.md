# 🔧 Fix "Database error saving new user"

## 🚨 **The Error**

When signing up, you see: **"Database error saving new user"**

This means the auto-signup trigger is trying to insert a user record but failing due to a constraint violation.

---

## 🔍 **Step 1: Diagnose the Issue**

Run this in **Supabase SQL Editor**:

```sql
-- Copy and paste from: Docs/diagnose_signup_error.sql
```

This will show:
1. ✅ Does the trigger exist?
2. ✅ What columns are NOT NULL?
3. ✅ Does Default Agency/Team exist?
4. ✅ What are the foreign key constraints?

---

## 🔧 **Step 2: Apply the Fix**

### **Option A: Run the Fixed Trigger (Recommended)**

Run this in **Supabase SQL Editor**:

```sql
-- Copy and paste from: Docs/fix_trigger.sql
```

**What this fixes:**
- ✅ Adds `full_name` field (uses email username as default)
- ✅ Adds error handling (won't block signup if it fails)
- ✅ Adds `ON CONFLICT DO NOTHING` (prevents duplicate errors)
- ✅ Matches exact field order of your schema

### **Option B: Manual Test Insert**

Try manually inserting a test user to see the exact error:

```sql
-- Test insert to see what fails
DO $$
DECLARE
    test_id UUID := gen_random_uuid();
    test_agency UUID;
    test_team UUID;
BEGIN
    -- Get default agency
    SELECT id INTO test_agency FROM agencies WHERE name = 'Default Agency';
    IF test_agency IS NULL THEN
        RAISE EXCEPTION 'Default Agency not found!';
    END IF;
    
    -- Get default team
    SELECT id INTO test_team FROM teams WHERE name = 'Default Team';
    IF test_team IS NULL THEN
        RAISE EXCEPTION 'Default Team not found!';
    END IF;
    
    -- Try to insert
    INSERT INTO users (
        id, 
        email,
        agency_id,
        team_id,
        vehicle_type,
        vehicle_color
    )
    VALUES (
        test_id,
        'testuser@example.com',
        test_agency,
        test_team,
        'sedan',
        'black'
    );
    
    RAISE NOTICE 'Success! Test user created.';
    
    -- Clean up
    DELETE FROM users WHERE id = test_id;
    RAISE NOTICE 'Test user deleted.';
END $$;
```

If this fails, **copy the exact error message** and share it with me.

---

## 🎯 **Common Issues & Solutions**

### **Issue 1: Default Agency/Team Don't Exist**

**Symptom:** Foreign key constraint violation

**Fix:**
```sql
-- Create default agency
INSERT INTO agencies (name) 
VALUES ('Default Agency')
ON CONFLICT DO NOTHING;

-- Create default team
INSERT INTO teams (agency_id, name)
VALUES (
    (SELECT id FROM agencies WHERE name = 'Default Agency'),
    'Default Team'
)
ON CONFLICT DO NOTHING;
```

### **Issue 2: Missing Required Fields**

**Symptom:** "NOT NULL constraint violation"

**Check which fields are required:**
```sql
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'users'
AND is_nullable = 'NO';
```

Required fields should be:
- `id` ✅
- `email` ✅
- `agency_id` ✅
- `team_id` ✅

### **Issue 3: RLS (Row Level Security) Blocking Insert**

**Symptom:** "new row violates row-level security policy"

**Fix:** The trigger function needs `SECURITY DEFINER`:
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
-- ... function body ...
$$ LANGUAGE plpgsql SECURITY DEFINER;  -- This is important!
```

The `fix_trigger.sql` already has this.

### **Issue 4: Email Already Exists**

**Symptom:** "duplicate key value violates unique constraint"

**Fix:** Added in `fix_trigger.sql`:
```sql
INSERT INTO public.users (...)
VALUES (...)
ON CONFLICT (id) DO NOTHING;  -- Prevents duplicate error
```

---

## ✅ **Verification**

After applying the fix:

### **1. Check Trigger Function**
```sql
SELECT routine_name
FROM information_schema.routines
WHERE routine_name = 'handle_new_user';
```
Should return: `handle_new_user`

### **2. Try Signing Up**
1. Sign up with a NEW email address
2. Should succeed without error
3. Check if user was created:
```sql
SELECT email, full_name, team_id, agency_id
FROM users
ORDER BY created_at DESC
LIMIT 1;
```

---

## 🔍 **Debug Logs**

If the error persists, check Supabase logs:

1. Go to **Supabase Dashboard**
2. Click **Logs** → **Postgres Logs**
3. Look for errors around the time you tried to sign up
4. Share the exact error message with me

---

## 🆘 **Still Not Working?**

Run the diagnostic query and share the results:

```bash
# File: Docs/diagnose_signup_error.sql
# Copy/paste into Supabase SQL Editor
# Share the output with me
```

I'll immediately identify the issue and provide a targeted fix!

---

## 📝 **Summary**

**Quick Fix:**
1. Run `Docs/fix_trigger.sql` in Supabase SQL Editor
2. Try signing up again
3. Should work! ✅

**If it doesn't work:**
1. Run `Docs/diagnose_signup_error.sql`
2. Share the output
3. I'll fix it immediately!

