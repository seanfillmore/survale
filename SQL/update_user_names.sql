-- Update user names for existing users
-- Based on the provided information

BEGIN;

-- User 1: sfillmore15@gmail.com
UPDATE users 
SET 
    first_name = 'Sean',
    last_name = 'Fillmore',
    full_name = 'Sean Fillmore',
    callsign = 'DA308'
WHERE email = 'sfillmore15@gmail.com';

-- User 2: sean@sean.com
UPDATE users 
SET 
    first_name = 'Bob',
    last_name = 'Smith',
    full_name = 'Bob Smith',
    callsign = '7OT'
WHERE email = 'sean@sean.com';

-- User 3: kevin.alldredge@venturacounty.gov
UPDATE users 
SET 
    first_name = 'Kevin',
    last_name = 'Alldredge',
    full_name = 'Kevin Alldredge',
    callsign = '5O7'
WHERE email = 'kevin.alldredge@venturacounty.gov';

-- Verify the updates
SELECT 
    email,
    first_name,
    last_name,
    full_name,
    callsign
FROM users
WHERE email IN (
    'sfillmore15@gmail.com',
    'sean@sean.com',
    'kevin.alldredge@venturacounty.gov'
)
ORDER BY email;

-- If everything looks good in the results above, commit:
COMMIT;

-- If you need to undo, uncomment and run instead:
-- ROLLBACK;

