-- =====================================================
-- CHECK NEW SIGNUP (sean@sean.com)
-- =====================================================

-- 1. Check if user exists in auth.users
SELECT 
    'AUTH.USERS' as location,
    id,
    email,
    created_at
FROM auth.users
WHERE email = 'sean@sean.com';

-- 2. Check if profile exists in public.users
SELECT 
    'PUBLIC.USERS' as location,
    id,
    email,
    first_name,
    last_name,
    callsign,
    phone_number,
    vehicle_type,
    vehicle_color,
    agency_id,
    team_id,
    created_at
FROM public.users
WHERE email = 'sean@sean.com';

-- 3. Check signup audit for any errors
SELECT 
    'SIGNUP AUDIT' as check_type,
    *
FROM public.signup_audit
WHERE email = 'sean@sean.com'
ORDER BY created_at DESC;

-- 4. Check all recent signups
SELECT 
    au.email,
    au.created_at as auth_created,
    CASE 
        WHEN pu.id IS NOT NULL THEN '✅ Has profile'
        ELSE '❌ Missing profile'
    END as profile_status,
    pu.first_name,
    pu.last_name,
    pu.callsign
FROM auth.users au
LEFT JOIN public.users pu ON pu.id = au.id
ORDER BY au.created_at DESC
LIMIT 5;

