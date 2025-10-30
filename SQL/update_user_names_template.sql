-- Update user names with first_name, last_name, and full_name
-- Fill in the VALUES section with actual user data

-- Template for updating a single user:
-- UPDATE users 
-- SET 
--     first_name = 'FirstName',
--     last_name = 'LastName',
--     full_name = 'FirstName LastName'
-- WHERE email = 'user@example.com';

-- Instructions:
-- 1. Run list_users_needing_names.sql to get the current users
-- 2. Fill in the updates below with the correct names
-- 3. Run this script to update all users at once

-- Begin transaction (can rollback if something goes wrong)
BEGIN;

-- Example updates (replace with actual user data):

-- UPDATE users 
-- SET 
--     first_name = 'John',
--     last_name = 'Doe',
--     full_name = 'John Doe'
-- WHERE email = 'john@example.com';

-- UPDATE users 
-- SET 
--     first_name = 'Jane',
--     last_name = 'Smith',
--     full_name = 'Jane Smith'
-- WHERE email = 'jane@example.com';

-- Add more UPDATE statements here as needed...


-- Verify the updates before committing
SELECT 
    email,
    first_name,
    last_name,
    full_name
FROM users
ORDER BY email;

-- If everything looks good, commit:
COMMIT;

-- If you need to undo, run instead:
-- ROLLBACK;

