# 🚀 MVP Testing Guide

## 🎯 **Goal: Get 8-10 Users Testing**

For MVP, we're keeping it simple:
- ✅ **ONE team** - "MVP Team" 
- ✅ **ONE agency** - "MVP Agency"
- ✅ **All users** join automatically on signup
- ✅ **No complex permissions** - everyone can do everything
- ✅ **Focus on testing** core features

---

## ⚡ **One-Time Setup (5 minutes)**

### **Run This Once:**

📁 **File:** `Docs/mvp_simple_setup.sql`

**In Supabase Dashboard → SQL Editor:**
1. Copy ALL contents of `mvp_simple_setup.sql`
2. Paste and Run
3. Done! ✅

**What it does:**
1. ✅ Creates "MVP Agency" and "MVP Team"
2. ✅ Sets up auto-signup trigger
3. ✅ Adds ALL existing users to MVP Team
4. ✅ Fixes any orphaned users
5. ✅ Verifies everything worked

---

## 👥 **Adding Test Users**

### **Method 1: Self-Signup (Recommended)**
Just share the app with your testers:
1. Open app
2. Tap "Sign Up"
3. Enter email/password
4. Done! Automatically added to MVP Team ✅

### **Method 2: Manual Creation**
If you want to pre-create accounts:

```sql
-- Create a test user manually
-- (They'll still need to sign up in the app to set their password)
SELECT 'Create user in Supabase Dashboard → Authentication → Add User';
-- Then the trigger will auto-add them to MVP Team
```

---

## ✅ **Verification**

### **Check All Users Are in MVP Team:**
```sql
SELECT 
    u.email,
    u.full_name,
    t.name as team,
    a.name as agency
FROM users u
JOIN teams t ON u.team_id = t.id
JOIN agencies a ON u.agency_id = a.id
ORDER BY u.created_at DESC;
```

Should show:
- All users in "MVP Team"
- All users in "MVP Agency"

---

## 🧪 **Testing Checklist**

### **Phase 1: Basic Functionality**
- [ ] User can sign up
- [ ] User can log in
- [ ] User can create operation
- [ ] User can add targets (person/vehicle/location)
- [ ] User can add staging area

### **Phase 2: Location Tracking**
- [ ] Grant location permissions
- [ ] Start operation (goes to "Active")
- [ ] See own location on map
- [ ] See other team members' locations
- [ ] Location updates every 3-5 seconds
- [ ] Location tracking works in background

### **Phase 3: Chat**
- [ ] Send text message in operation
- [ ] Receive messages from other users
- [ ] Messages appear in real-time

### **Phase 4: Operation Lifecycle**
- [ ] Join operation (via invite or join code)
- [ ] End operation
- [ ] View ended operations

---

## 👥 **MVP Test Scenarios**

### **Scenario 1: Multi-User Operation**
1. **User A** creates operation "Test Op 1"
2. **User B** joins via join code
3. **User C** joins via join code
4. All users see each other's locations
5. All users can chat
6. User A ends operation

### **Scenario 2: Real-World Movement**
1. Create operation
2. 3+ users join
3. Users physically move (drive/walk)
4. Verify locations update on map
5. Verify speed and heading are shown
6. Test background location tracking

### **Scenario 3: Target Tracking**
1. Create operation
2. Add target person with photo
3. Add target vehicle with details
4. Add target location
5. All users can see targets
6. Test adding notes to targets

---

## 🐛 **Common Issues & Fixes**

### **Issue: "Not assigned to team"**
**Fix:**
```sql
-- Run mvp_simple_setup.sql again
-- Or manually fix:
UPDATE users
SET 
    agency_id = (SELECT id FROM agencies WHERE name = 'MVP Agency'),
    team_id = (SELECT id FROM teams WHERE name = 'MVP Team')
WHERE email = 'user@email.com';
```

### **Issue: User signs up but not in database**
**Fix:**
```sql
-- Check if trigger is working:
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- If missing, run mvp_simple_setup.sql
```

### **Issue: Location not updating**
**Check:**
1. ✅ Location permissions granted (Always)
2. ✅ Operation is in "Active" state
3. ✅ Device location services enabled
4. ✅ Check console logs for errors

### **Issue: Chat messages not appearing**
**Check:**
1. ✅ Realtime enabled on `op_messages` table
2. ✅ User is member of operation
3. ✅ Check Supabase dashboard for message records

---

## 📊 **Monitoring During Testing**

### **Check Active Operations:**
```sql
SELECT 
    o.name,
    o.status,
    COUNT(DISTINCT om.user_id) as member_count,
    o.created_at
FROM operations o
LEFT JOIN operation_members om ON o.id = om.operation_id
GROUP BY o.id
ORDER BY o.created_at DESC;
```

### **Check Recent Locations:**
```sql
SELECT 
    u.email,
    ls.ts,
    ls.lat,
    ls.lon,
    ls.speed_mps,
    ls.heading_deg
FROM locations_stream ls
JOIN users u ON ls.user_id = u.id
ORDER BY ls.ts DESC
LIMIT 20;
```

### **Check Recent Messages:**
```sql
SELECT 
    u.email,
    om.body_text,
    om.created_at
FROM op_messages om
JOIN users u ON om.sender_user_id = u.id
ORDER BY om.created_at DESC
LIMIT 20;
```

---

## 🎉 **Success Criteria**

**MVP is successful if:**
- ✅ 8-10 users can sign up
- ✅ Users can create and join operations
- ✅ Real-time location tracking works
- ✅ Chat works across users
- ✅ App doesn't crash during normal use
- ✅ Background location tracking works
- ✅ Data persists after app restart

---

## 📝 **Feedback Collection**

Ask testers:
1. Was signup/login easy?
2. Could you create an operation?
3. Did location tracking work?
4. Was the map view clear?
5. Did chat work in real-time?
6. Any crashes or errors?
7. What features are missing?
8. Overall experience (1-10)?

---

## 🚀 **Ready to Test!**

1. **Run** `mvp_simple_setup.sql` (one time)
2. **Invite** 8-10 test users
3. **Create** an operation
4. **Test** all features together
5. **Collect** feedback
6. **Iterate** based on results

**All users will automatically be in the same team, so they can all see and join each other's operations!** 🎉

