# Database Setup Required - User Context Issue

## 🔴 **Issue: "Missing user context" when creating operations**

When you try to create an operation, you see: **"Missing user context"**

This happens because the app expects user data to exist in the database, but it's not there yet.

---

## 📋 **What's Happening**

### **Current Flow:**
```
1. User signs up → Supabase Auth creates auth user ✅
2. User logs in → Auth succeeds ✅
3. App tries to load user context from database ❌
4. Database query fails → No user record found ❌
5. AppState.currentUser remains nil ❌
6. Create operation button → "Missing user context" ❌
```

### **Expected Flow:**
```
1. User signs up → Auth user created ✅
2. Database trigger creates user record ✅
3. User logs in → Auth succeeds ✅
4. App loads user context → Success ✅
5. AppState has full user data ✅
6. Create operation works ✅
```

---

## 🔧 **Solution: Set Up Database**

You need to create the required database tables and triggers in your Supabase project.

### **Required Tables:**

#### **1. agencies**
```sql
CREATE TABLE agencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE agencies ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own agency
CREATE POLICY "Users can view their own agency"
ON agencies FOR SELECT
USING (id IN (
    SELECT agency_id FROM users WHERE id = auth.uid()
));
```

#### **2. teams**
```sql
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id UUID NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own team
CREATE POLICY "Users can view their own team"
ON teams FOR SELECT
USING (id IN (
    SELECT team_id FROM users WHERE id = auth.uid()
));
```

#### **3. users**
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    team_id UUID NOT NULL REFERENCES teams(id),
    agency_id UUID NOT NULL REFERENCES agencies(id),
    callsign TEXT,
    vehicle_type TEXT NOT NULL DEFAULT 'sedan',
    vehicle_color TEXT NOT NULL DEFAULT 'black',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view themselves and team members
CREATE POLICY "Users can view team members"
ON users FOR SELECT
USING (
    team_id IN (
        SELECT team_id FROM users WHERE id = auth.uid()
    )
);

-- Policy: Users can update their own record
CREATE POLICY "Users can update own record"
ON users FOR UPDATE
USING (id = auth.uid());
```

### **Database Trigger (Auto-create user record on signup):**

```sql
-- Function to create user record when auth user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    default_agency_id UUID;
    default_team_id UUID;
BEGIN
    -- Get or create a default agency
    SELECT id INTO default_agency_id FROM agencies WHERE name = 'Default Agency' LIMIT 1;
    
    IF default_agency_id IS NULL THEN
        INSERT INTO agencies (name) VALUES ('Default Agency') RETURNING id INTO default_agency_id;
    END IF;
    
    -- Get or create a default team
    SELECT id INTO default_team_id FROM teams WHERE agency_id = default_agency_id AND name = 'Default Team' LIMIT 1;
    
    IF default_team_id IS NULL THEN
        INSERT INTO teams (agency_id, name) VALUES (default_agency_id, 'Default Team') RETURNING id INTO default_team_id;
    END IF;
    
    -- Insert user record
    INSERT INTO public.users (id, email, team_id, agency_id, vehicle_type, vehicle_color)
    VALUES (NEW.id, NEW.email, default_team_id, default_agency_id, 'sedan', 'black');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to run function on new auth user
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

---

## 🚀 **Quick Setup Steps**

### **Option 1: Manual Setup (For Testing)**

Run these SQL commands in your Supabase SQL editor:

1. **Create a test agency:**
```sql
INSERT INTO agencies (id, name) 
VALUES ('00000000-0000-0000-0000-000000000001', 'Test Agency');
```

2. **Create a test team:**
```sql
INSERT INTO teams (id, agency_id, name)
VALUES (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    'Test Team'
);
```

3. **Create your user record:**
```sql
-- Replace 'YOUR_AUTH_USER_ID' with your actual auth.users.id
INSERT INTO users (id, email, team_id, agency_id, vehicle_type, vehicle_color)
VALUES (
    'YOUR_AUTH_USER_ID',  -- Get this from Supabase Auth dashboard
    'your@email.com',
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    'sedan',
    'black'
);
```

### **Option 2: Full Setup (Recommended)**

1. Go to your Supabase Dashboard
2. Navigate to SQL Editor
3. Run all the CREATE TABLE statements above
4. Run the trigger function
5. Sign up a new user - they'll automatically get a user record

---

## 🔍 **Debugging**

The app now has better error messages. Check your Xcode console:

```
📥 Loading user context for userId: xxx-xxx-xxx
   Fetching user from database...
❌ Failed to load user context: <error details>
   This usually means:
   1. User record doesn't exist in 'users' table
   2. User is not assigned to a team/agency
   3. Database connection issue
   → You need to create the user record in the database
```

Also when creating an operation:

```
❌ CreateOperation: currentUserID is nil
❌ CreateOperation: currentUser.teamId is nil
   Current user: nil
❌ CreateOperation: currentUser.agencyId is nil
```

These messages will tell you exactly what's missing.

---

## ✅ **Verification**

After setting up the database:

1. **Restart the app**
2. **Log in** - you should see:
   ```
   📥 Loading user context for userId: xxx
      Fetching user from database...
      ✅ User found: your@email.com
   ```
3. **Try creating an operation** - it should work!

---

## 📚 **Reference**

The backend specification (`Survale_API_and_Backend_Spec_v1.0.pdf`) contains the full database schema with all tables, RLS policies, and triggers needed for production.

---

## 🎯 **Next Steps**

Once you have the database set up:
1. User context will load properly ✅
2. Operations can be created ✅
3. Multi-tenancy will work (agencies/teams) ✅
4. All features will function as designed ✅

**The app is ready - it just needs the database to exist!**

