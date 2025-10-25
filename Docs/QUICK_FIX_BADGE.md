# Fixed: Badge Number Column Error ✅

## The Problem
The SQL scripts referenced a `badge_number` column that doesn't exist in your `users` table.

## The Solution
Changed all references from `badge_number` to `callsign` (which exists in your User model).

---

## ✅ What Was Updated

### 1. SQL Scripts
- ✅ `add_test_users_simple.sql` - Removed badge_number column
- ✅ `check_teams.sql` - Removed badge_number from queries
- ✅ `simple_target_rpc.sql` - Changed `rpc_get_team_roster()` to return `callsign`

### 2. Swift Code
- ✅ `SupabaseRPCService.swift` - TeamMember model now uses `callsign` instead of `badgeNumber`
- ✅ `CreateOperationView.swift` - UI now shows callsign (or email if no callsign)

---

## 🚀 Ready to Run

Now you can run the scripts:

### 1. Add Test Users (No Badge Numbers)
```
Docs/add_test_users_simple.sql
```

This will create:
- John Smith (officer1@test.com)
- Jane Doe (officer2@test.com)
- Mike Johnson (officer3@test.com)

### 2. Update RPC Function
```
Docs/simple_target_rpc.sql
```

This updates `rpc_get_team_roster()` to return `callsign` instead of `badge_number`.

---

## 📝 What You'll See

In the app, Step 4 (Team Members) will now show:
```
[Avatar] John Smith
         officer1@test.com      ⭕️

[Avatar] Jane Doe
         officer2@test.com      ⭕️

[Avatar] Mike Johnson
         officer3@test.com      ⭕️
```

If a user has a callsign set, it will show instead of the email:
```
[Avatar] John Smith
         UNIT-42                ⭕️
```

---

## 🔧 To Set Callsigns (Optional)

If you want to add callsigns to test users:

```sql
UPDATE users
SET callsign = CASE email
    WHEN 'officer1@test.com' THEN 'UNIT-101'
    WHEN 'officer2@test.com' THEN 'UNIT-102'
    WHEN 'officer3@test.com' THEN 'UNIT-103'
    ELSE callsign
END
WHERE email IN ('officer1@test.com', 'officer2@test.com', 'officer3@test.com');
```

---

All fixed! Run the scripts now. 🎉

