# User Signup & Authentication Flow

## 🎯 **Current State: YES, It's Wired Up! ✅**

The app **IS** properly configured to automatically create user records in the database when someone signs up. Here's how it works:

---

## 📋 **How It Works**

### **1. User Signs Up (SignUpView.swift)**
```swift
// User enters email/password in SignUpView
try await SupabaseAuthService.shared.supabase.auth.signUp(
    email: email,
    password: password
)
```

### **2. Supabase Auth Creates Record**
- Supabase creates a record in `auth.users` table
- This is handled by Supabase Auth automatically

### **3. Database Trigger Fires (setup_database.sql)**
```sql
-- This trigger runs automatically when auth.users gets a new record
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW 
    EXECUTE FUNCTION public.handle_new_user();
```

### **4. Trigger Function Creates User Record**
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 1. Get or create "Default Agency"
    -- 2. Get or create "Default Team" 
    -- 3. Insert into public.users table with:
    --    - id (from auth.users.id)
    --    - email (from auth.users.email)
    --    - team_id (Default Team)
    --    - agency_id (Default Agency)
    --    - vehicle_type = 'sedan'
    --    - vehicle_color = 'black'
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### **5. App Loads User Context (SupabaseAuthService.swift)**
```swift
// Auth listener detects login/signup
func startAuthListener(onChange: @escaping (Bool) -> Void) {
    for await _ in self.client.auth.authStateChanges {
        if let session = try? await self.client.auth.session {
            // Load full user context from database
            await self.loadUserContext(userId: session.user.id)
            
            // This populates:
            // - appState.currentUser (with team_id, agency_id, etc.)
            // - appState.currentTeam
            // - appState.currentAgency
        }
    }
}
```

---

## ✅ **What You Get Automatically**

When a user signs up, they automatically get:

1. **Auth User** (`auth.users`)
   - `id` (UUID)
   - `email`
   - `encrypted_password`
   - Created by Supabase Auth

2. **Public User Record** (`public.users`)
   - `id` (same as auth.users.id)
   - `email`
   - `team_id` → "Default Team"
   - `agency_id` → "Default Agency"
   - `vehicle_type` = 'sedan'
   - `vehicle_color` = 'black'
   - `callsign` = NULL (user can set later)
   - Created by database trigger

3. **App State Populated**
   - `appState.currentUserID` ✅
   - `appState.currentUser` ✅
   - `appState.currentTeam` ✅
   - `appState.currentAgency` ✅

---

## 🚨 **Current Issue: Missing Trigger**

**Problem:** You're getting "Missing user context" because the database trigger **hasn't been installed yet**.

**Solution:** Run the SQL script to install the trigger:

### **Option A: Run Full Setup (Recommended)**
```sql
-- Run this entire file in Supabase SQL Editor
/Users/seanfillmore/Code/Survale/Survale/Docs/setup_database.sql
```

### **Option B: Just Install the Trigger**
If your tables already exist, just run this part:

```sql
-- Function to create user record when auth user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    default_agency_id UUID;
    default_team_id UUID;
BEGIN
    -- Get or create default agency
    SELECT id INTO default_agency_id 
    FROM agencies 
    WHERE name = 'Default Agency' 
    LIMIT 1;
    
    IF default_agency_id IS NULL THEN
        INSERT INTO agencies (name) 
        VALUES ('Default Agency') 
        RETURNING id INTO default_agency_id;
    END IF;
    
    -- Get or create default team
    SELECT id INTO default_team_id 
    FROM teams 
    WHERE agency_id = default_agency_id 
    AND name = 'Default Team' 
    LIMIT 1;
    
    IF default_team_id IS NULL THEN
        INSERT INTO teams (agency_id, name) 
        VALUES (default_agency_id, 'Default Team') 
        RETURNING id INTO default_team_id;
    END IF;
    
    -- Insert user record
    INSERT INTO public.users (id, email, team_id, agency_id, vehicle_type, vehicle_color)
    VALUES (
        NEW.id, 
        NEW.email, 
        default_team_id, 
        default_agency_id, 
        'sedan', 
        'black'
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW 
    EXECUTE FUNCTION public.handle_new_user();
```

---

## 🔧 **For Existing Auth Users**

If you already signed up BEFORE installing the trigger, manually add yourself:

```sql
-- 1. Find your auth user ID
SELECT id, email FROM auth.users;

-- 2. Get or create default agency/team
INSERT INTO agencies (name) VALUES ('Default Agency') 
ON CONFLICT DO NOTHING 
RETURNING id;

INSERT INTO teams (agency_id, name) 
VALUES (
    (SELECT id FROM agencies WHERE name = 'Default Agency'),
    'Default Team'
)
ON CONFLICT DO NOTHING
RETURNING id;

-- 3. Create your user record
INSERT INTO public.users (
    id, 
    email, 
    team_id, 
    agency_id, 
    vehicle_type, 
    vehicle_color
)
VALUES (
    'YOUR_AUTH_USER_ID_HERE',  -- Replace with ID from step 1
    'your@email.com',           -- Replace with your email
    (SELECT id FROM teams WHERE name = 'Default Team'),
    (SELECT id FROM agencies WHERE name = 'Default Agency'),
    'sedan',
    'black'
);
```

---

## ✅ **Verification Steps**

After running the trigger setup:

### **1. Check Trigger Exists**
```sql
SELECT trigger_name, event_manipulation, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
```

Should return:
```
trigger_name         | event_manipulation | event_object_table
---------------------|-------------------|-------------------
on_auth_user_created | INSERT            | users
```

### **2. Test Signup Flow**
1. Sign up with a new email in the app
2. Check if user was created:
```sql
SELECT u.id, u.email, u.team_id, u.agency_id, t.name as team_name, a.name as agency_name
FROM users u
JOIN teams t ON u.team_id = t.id
JOIN agencies a ON u.agency_id = a.id
WHERE u.email = 'test@example.com';
```

### **3. Check App Logs**
When you log in, you should see:
```
📥 Loading user context for userId: xxx-xxx-xxx
   Fetching user from database...
   ✅ User found: your@email.com
```

Instead of:
```
❌ Failed to load user context: ...
```

---

## 🎯 **Summary**

**Question:** Is the app wired up to create new users in the database with team information?

**Answer:** **YES! ✅** The app code is fully wired up. You just need to run the SQL script to install the database trigger, then all new signups will automatically get:
- A `users` table record
- Assigned to "Default Team" 
- Assigned to "Default Agency"
- Ready to create operations immediately

**Next Step:** Copy the SQL from `setup_database.sql` (or just the trigger section above) and run it in your Supabase SQL Editor.

