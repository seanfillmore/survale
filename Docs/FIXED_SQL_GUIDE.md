# 🚀 Fixed SQL Setup Guide

## ⚠️ **Issue Resolved**

**Error:** `ERROR: 42703: column "user_id" does not exist`

**Root Cause:** The `setup_database.sql` file had column names that didn't match your actual Supabase database schema.

---

## ✅ **Solution: Use the Trigger-Only Script**

Since your tables **already exist** with the correct schema, you don't need to create them again. You just need to add the auto-signup trigger.

### **📄 File to Use:**
```
Docs/setup_trigger_only.sql
```

This simplified script:
- ✅ Only adds the auto-signup trigger
- ✅ Creates default agency/team
- ✅ Enables Realtime for locations and messages
- ✅ Verifies setup worked

---

## 🎯 **Step-by-Step Instructions**

### **1. Open Supabase Dashboard**
1. Go to https://supabase.com
2. Select your **Survale** project
3. Click **SQL Editor** in left sidebar

### **2. Run the Trigger Script**
1. Click **+ New query**
2. Open this file: `Docs/setup_trigger_only.sql`
3. **Copy ALL the content**
4. **Paste** into SQL Editor
5. Click **Run** (or Cmd+Enter)

### **3. Expected Result**
You should see:
```
✅ Setup complete! New signups will automatically get user records.
```

---

## 🔍 **What This Does**

### **1. Auto-Signup Trigger**
```sql
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW 
    EXECUTE FUNCTION public.handle_new_user();
```

When someone signs up:
1. Supabase Auth creates record in `auth.users`
2. Trigger fires automatically
3. Creates/finds "Default Agency"
4. Creates/finds "Default Team"
5. Inserts into `public.users` with:
   - `id` (from auth.users)
   - `email`
   - `team_id` (Default Team)
   - `agency_id` (Default Agency)
   - `vehicle_type` = 'sedan'
   - `vehicle_color` = 'black'

### **2. Realtime Enabled**
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE locations_stream;
ALTER PUBLICATION supabase_realtime ADD TABLE op_messages;
```

Enables real-time updates for:
- 📍 Live location tracking
- 💬 Chat messages

---

## 🧪 **Test After Setup**

### **Test 1: Verify Trigger**
```sql
SELECT trigger_name 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
```

Should return: `on_auth_user_created`

### **Test 2: Check Default Agency/Team**
```sql
SELECT * FROM agencies WHERE name = 'Default Agency';
SELECT * FROM teams WHERE name = 'Default Team';
```

Should see one row in each.

### **Test 3: Sign Up New User**
1. Sign up in the app with a new email
2. Check if user was created:
```sql
SELECT u.email, t.name as team, a.name as agency
FROM users u
JOIN teams t ON u.team_id = t.id
JOIN agencies a ON u.agency_id = a.id
ORDER BY u.created_at DESC
LIMIT 5;
```

---

## 🔧 **For Existing Users**

If you already signed up BEFORE running this trigger:

```sql
-- 1. Get your auth user ID
SELECT id, email FROM auth.users WHERE email = 'your@email.com';

-- 2. Insert your user record manually
INSERT INTO users (id, email, team_id, agency_id, vehicle_type, vehicle_color)
VALUES (
    'YOUR_AUTH_ID_FROM_STEP_1',  -- Replace this
    'your@email.com',             -- Replace this
    (SELECT id FROM teams WHERE name = 'Default Team'),
    (SELECT id FROM agencies WHERE name = 'Default Agency'),
    'sedan',
    'black'
);
```

---

## ❌ **Don't Use These Files**

These files have schema mismatches with your database:

- ❌ `setup_database.sql` - Has wrong column names
- ❌ `Database_Setup_Required.md` - References wrong schema

---

## ✅ **What's Fixed**

All column name issues have been resolved in the app code:

| Feature | Your Database | App Code (Fixed) | Status |
|---------|---------------|------------------|--------|
| Operation creator | `case_agent_id` | ✅ Uses `case_agent_id` | Fixed |
| Operation state | `status` | ✅ Maps to `status` | Fixed |
| Operation times | `started_at`, `ended_at` | ✅ Maps correctly | Fixed |
| Location fields | `ts`, `lat`, `lon`, `accuracy_m`, etc. | ✅ Maps correctly | Fixed |
| Message sender | `sender_user_id` | ✅ Uses `sender_user_id` | Fixed |
| Message content | `body_text` | ✅ Uses `body_text` | Fixed |

---

## 🎉 **After Running the Script**

Your app will:
- ✅ Auto-create user records on signup
- ✅ Assign users to Default Team
- ✅ Allow operation creation immediately
- ✅ Track locations in real-time
- ✅ Send chat messages

---

## 📞 **Need Help?**

If you see any errors when running `setup_trigger_only.sql`, share the exact error message and I'll fix it immediately!

---

## 📝 **Summary**

1. **Don't use** `setup_database.sql` - it has wrong column names
2. **Do use** `setup_trigger_only.sql` - matches your actual database
3. Run it in Supabase SQL Editor
4. Test signup in the app
5. Everything should work! 🚀

