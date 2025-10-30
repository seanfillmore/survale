-- ===================================================================
-- QUERY 1: List all users who need their full_name populated
-- ===================================================================
-- This shows the actual user details - USE THIS ONE!

SELECT 
    id,
    email,
    first_name,
    last_name,
    full_name,
    callsign,
    created_at
FROM users
WHERE full_name IS NULL OR TRIM(full_name) = ''
ORDER BY created_at;

-- ===================================================================
-- QUERY 2: Summary statistics (optional)
-- ===================================================================
-- This just shows counts - run separately if you want totals

-- SELECT 
--     COUNT(*) as total_users,
--     COUNT(CASE WHEN full_name IS NULL OR TRIM(full_name) = '' THEN 1 END) as users_needing_names,
--     COUNT(CASE WHEN full_name IS NOT NULL AND TRIM(full_name) != '' THEN 1 END) as users_with_names
-- FROM users;

