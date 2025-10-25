# 🔧 Troubleshoot "Not Assigned to Team" Error

## 🎯 **Quick Fix (Try This First)**

### **Step 1: Log Out and Back In**
1. Open the app
2. Go to **Settings**
3. Tap **Sign Out**
4. **Sign In** again
5. Try creating an operation

**Why:** The app cached your old user data before you ran the database fix. Logging out clears the cache.

---

## 🔍 **If That Doesn't Work**

### **Step 2: Verify Database Has Your User**

Run in **Supabase SQL Editor**:

📁 **File:** `Docs/verify_user_loaded.sql`

Or run this:
```sql
SELECT 
    u.email,
    u.team_id,
    u.agency_id,
    t.name as team_name,
    a.name as agency_name
FROM users u
LEFT JOIN teams t ON u.team_id = t.id
LEFT JOIN agencies a ON u.agency_id = a.id
WHERE u.email = 'YOUR_EMAIL_HERE';  -- Replace with your email
```

**Expected result:**
```
email: your@email.com
team_id: <some UUID>
agency_id: <some UUID>
team_name: MVP Team
agency_name: MVP Agency
```

**If team_id or agency_id is NULL, run this:**
```sql
UPDATE users
SET 
    team_id = (SELECT id FROM teams WHERE name = 'MVP Team'),
    agency_id = (SELECT id FROM agencies WHERE name = 'MVP Agency')
WHERE email = 'YOUR_EMAIL_HERE';  -- Replace with your email
```

---

## 🐛 **Check App Logs**

When you log in, check the Xcode console for these messages:

### **✅ Good (Working):**
```
📥 Loading user context for userId: xxx-xxx-xxx
   Fetching user from database...
   ✅ User found: your@email.com
```

### **❌ Bad (Not Working):**
```
📥 Loading user context for userId: xxx-xxx-xxx
   Fetching user from database...
   ❌ Failed to load user context: ...
```

**If you see the ❌ error:**
- Your user record is missing or has NULL team_id/agency_id
- Run the database fix above

---

## 🔧 **Manual Database Fix**

If your user still isn't assigned after logging out/in:

```sql
-- 1. Find your user
SELECT id, email, team_id, agency_id 
FROM users 
WHERE email = 'YOUR_EMAIL';

-- 2. If user doesn't exist at all, add them:
INSERT INTO users (
    id, email, full_name,
    agency_id, team_id,
    vehicle_type, vehicle_color
)
SELECT 
    au.id,
    au.email,
    split_part(au.email, '@', 1) as full_name,
    (SELECT id FROM agencies WHERE name = 'MVP Agency'),
    (SELECT id FROM teams WHERE name = 'MVP Team'),
    'sedan',
    'black'
FROM auth.users au
WHERE au.email = 'YOUR_EMAIL'
AND NOT EXISTS (SELECT 1 FROM users WHERE email = 'YOUR_EMAIL');

-- 3. If user exists but has NULL team/agency:
UPDATE users
SET 
    team_id = (SELECT id FROM teams WHERE name = 'MVP Team'),
    agency_id = (SELECT id FROM agencies WHERE name = 'MVP Agency')
WHERE email = 'YOUR_EMAIL'
AND (team_id IS NULL OR agency_id IS NULL);

-- 4. Verify fix worked:
SELECT 
    u.email,
    t.name as team,
    a.name as agency
FROM users u
JOIN teams t ON u.team_id = t.id
JOIN agencies a ON u.agency_id = a.id
WHERE u.email = 'YOUR_EMAIL';
```

---

## 🧪 **Test Sequence**

After fixing:

1. **Close the app completely** (swipe up in app switcher)
2. **Reopen the app**
3. **Log out**
4. **Log in again**
5. Check console logs for "✅ User found"
6. **Try creating an operation**

---

## 🔍 **Where the Error Comes From**

The error "Not assigned to team" is triggered in `CreateOperationView.swift`:

```swift
guard let teamId = appState.currentUser?.teamId else {
    print("❌ CreateOperation: currentUser.teamId is nil")
    return  // Shows "not assigned to team" error
}
```

This means:
- Either `appState.currentUser` is `nil`
- Or `currentUser.teamId` is `nil`

**Root cause:** The `loadUserContext` function in `SupabaseAuthService` couldn't find your user in the database, or found them with NULL team_id.

---

## ✅ **Final Checklist**

- [ ] Ran `mvp_simple_setup.sql` in Supabase
- [ ] Verified user exists in database with team/agency
- [ ] Logged out of app
- [ ] Logged back in
- [ ] Saw "✅ User found" in console
- [ ] Tried creating operation
- [ ] Success! ✅

---

## 🆘 **Still Not Working?**

Share these with me:

1. **Console logs** when you log in (especially the "Loading user context" section)
2. **Database query result:**
   ```sql
   SELECT email, team_id, agency_id FROM users WHERE email = 'YOUR_EMAIL';
   ```
3. **What you see** in the app when creating an operation

I'll identify the exact issue immediately!

