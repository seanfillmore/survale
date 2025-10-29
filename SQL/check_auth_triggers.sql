-- =====================================================
-- CHECK FOR AUTH TRIGGERS AND FUNCTIONS
-- =====================================================
-- This script checks for any triggers or functions that
-- automatically create user records when signup occurs
-- =====================================================

-- Check for triggers on auth.users table
SELECT 
    trigger_name,
    event_manipulation as event,
    event_object_table as table_name,
    action_statement as action
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
  AND event_object_table = 'users';

-- Check for functions in public schema that might be called by triggers
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%user%'
  AND routine_type = 'FUNCTION'
ORDER BY routine_name;

