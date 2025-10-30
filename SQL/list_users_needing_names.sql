-- List all users who need their full_name populated
-- Shows users with NULL or empty full_name but have email

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

-- Also show a summary count
SELECT 
    COUNT(*) as total_users,
    COUNT(CASE WHEN full_name IS NULL OR TRIM(full_name) = '' THEN 1 END) as users_needing_names,
    COUNT(CASE WHEN full_name IS NOT NULL AND TRIM(full_name) != '' THEN 1 END) as users_with_names
FROM users;

