# 🚀 Survale Database Quickstart

## ⚡ **Fix "Missing user context" in 5 Minutes**

---

## **Step 1: Go to Supabase Dashboard**

1. Open your browser
2. Go to https://supabase.com
3. Click on your **Survale** project
4. Click **SQL Editor** in the left sidebar

---

## **Step 2: Run the Setup Script**

1. In the SQL Editor, click **+ New query**
2. Open the file: `Docs/setup_database.sql`
3. **Copy ALL the content** (the entire file)
4. **Paste** it into the SQL Editor
5. Click **Run** (or press Cmd+Enter)

You should see: ✅ **Success. No rows returned**

---

## **Step 3: Verify Setup**

Run this query to check if everything was created:

```sql
-- Check tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Check default agency and team
SELECT * FROM agencies;
SELECT * FROM teams;
```

You should see:
- ✅ Multiple tables (agencies, teams, users, operations, etc.)
- ✅ "Default Agency" in agencies table
- ✅ "Default Team" in teams table

---

## **Step 4: Add Your Existing User (If Needed)**

If you already signed up before running the setup:

1. **Get your user ID:**
```sql
SELECT id, email FROM auth.users;
```

2. **Copy your ID** (looks like: `abc123-def456-...`)

3. **Insert your user record:**
```sql
INSERT INTO users (id, email, team_id, agency_id, vehicle_type, vehicle_color)
SELECT 
    'YOUR_USER_ID_HERE'::UUID,  -- ← Paste your ID here
    'your@email.com',            -- ← Your email
    teams.id,
    agencies.id,
    'sedan',
    'black'
FROM agencies, teams
WHERE agencies.name = 'Default Agency' AND teams.name = 'Default Team';
```

---

## **Step 5: Test the App**

1. **Restart your app** (stop and rerun from Xcode)
2. **Log in**
3. **Check Xcode console** - you should see:
   ```
   📥 Loading user context for userId: xxx
      Fetching user from database...
      ✅ User found: your@email.com
   ```
4. **Try creating an operation** - it should work! 🎉

---

## **✅ Success Checklist**

After setup, you should have:
- [x] All database tables created
- [x] RLS policies enabled
- [x] Default agency and team created
- [x] User record in users table
- [x] Trigger for auto-creating future users
- [x] Realtime enabled for locations and messages

---

## **🔧 Troubleshooting**

### **Issue: "User not found" after login**

**Solution:** You need to manually add your user record (Step 4 above)

### **Issue: "Row not found" error**

**Solution:** Check if your user record exists:
```sql
SELECT * FROM users WHERE id = (SELECT id FROM auth.users WHERE email = 'your@email.com');
```

If empty, run the INSERT from Step 4.

### **Issue: "Permission denied"**

**Solution:** Make sure RLS policies were created. Re-run the setup script.

---

## **📚 What This Does**

The setup script:
1. **Creates all tables** needed for Survale (agencies, teams, users, operations, etc.)
2. **Enables RLS** (Row Level Security) for data isolation
3. **Creates policies** so users only see their own data
4. **Enables Realtime** for live location and chat updates
5. **Creates trigger** to auto-create user records for new signups
6. **Creates default agency/team** for testing

---

## **🎯 Next Steps**

Once the database is set up:
1. ✅ User context loads properly
2. ✅ Operations can be created
3. ✅ Multi-user features work
4. ✅ Real-time updates work (with polling)
5. ✅ All app features are unlocked

**You're ready to start testing your surveillance operations!** 🚀

---

## **💡 For New Users**

New users who sign up AFTER running the setup will automatically get:
- User record created (via trigger)
- Assigned to "Default Agency"
- Assigned to "Default Team"
- Ready to use immediately

No manual steps needed! ✨

