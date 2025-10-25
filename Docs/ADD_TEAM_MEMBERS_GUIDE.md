# Adding Team Members for Testing

## Quick Fix

The error `Current user not assigned to team` happens because the SQL script tried to use `auth.uid()` which isn't available in the SQL Editor context.

---

## ✅ Solution: Use the Simple Script

### Step 1: Check Your Teams
Run this first to see what teams exist:

```bash
Docs/check_teams.sql
```

This will show:
- All agencies
- All teams
- All users
- User count by team

### Step 2: Add Test Users
Run this to add 3 test users to "MVP Team":

```bash
Docs/add_test_users_simple.sql
```

This will add:
- **John Smith** (BADGE001, officer1@test.com)
- **Jane Doe** (BADGE002, officer2@test.com)
- **Mike Johnson** (BADGE003, officer3@test.com)

### Step 3: Restart the App
After adding test users:
1. Close and reopen the app
2. Go to Operations tab
3. Tap "+" to create new operation
4. Navigate to Step 4 (Team Members)
5. You should now see 3 team members listed!

---

## 🎯 Expected Results

After running the scripts, `check_teams.sql` should show:

```
=== USERS ===
email                 | full_name    | badge_number | team_name
----------------------|--------------|--------------|----------
your@email.com        | Your Name    | YOUR_BADGE   | MVP Team
officer1@test.com     | John Smith   | BADGE001     | MVP Team
officer2@test.com     | Jane Doe     | BADGE002     | MVP Team
officer3@test.com     | Mike Johnson | BADGE003     | MVP Team

=== USER COUNT BY TEAM ===
team_name  | user_count
-----------|------------
MVP Team   | 4
```

---

## 🔧 If Script Fails

### Error: "MVP Team not found"
Your team might have a different name. 

**Fix**:
1. Run `Docs/check_teams.sql` to see team names
2. Edit `Docs/add_test_users_simple.sql` line 14:
   ```sql
   WHERE name = 'Your Team Name Here'  -- Change this
   ```

### Error: "MVP Agency not found"
Similar to above.

**Fix**:
1. Check agency name from `check_teams.sql`
2. Edit `Docs/add_test_users_simple.sql` line 23:
   ```sql
   WHERE name = 'Your Agency Name Here'  -- Change this
   ```

---

## 📝 Manual Alternative

If scripts don't work, you can manually add users:

```sql
-- Replace these UUIDs with your actual team_id and agency_id from check_teams.sql
INSERT INTO users (id, email, full_name, badge_number, team_id, agency_id, created_at)
VALUES
    (
        gen_random_uuid(),
        'test1@example.com',
        'Test User 1',
        'TEST001',
        'YOUR_TEAM_ID_HERE',      -- Paste your team ID
        'YOUR_AGENCY_ID_HERE',    -- Paste your agency ID
        NOW()
    );
```

---

## ✅ Verification

After adding users, verify in the app:
1. Create new operation
2. Go to Step 4 (Team Members)
3. You should see the new users
4. Try selecting/deselecting them
5. Continue to Review - should show "X members selected"

---

## 🚀 Quick Start Commands

```bash
# 1. Check current state
Run: Docs/check_teams.sql

# 2. Add test users
Run: Docs/add_test_users_simple.sql

# 3. Verify
Run: Docs/check_teams.sql again

# 4. Test in app
Create Operation -> Step 4 -> See team members!
```

All set! 🎉

