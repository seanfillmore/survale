-- =====================================================
-- CHECK FOR AUTH HOOKS AND FUNCTIONS
-- =====================================================

-- Check for any functions that might be called on auth events
SELECT 
    'FUNCTIONS THAT MIGHT BE AUTH HOOKS' as check_type,
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('public', 'auth')
  AND (
    p.proname LIKE '%user%'
    OR p.proname LIKE '%auth%'
    OR p.proname LIKE '%signup%'
    OR p.proname LIKE '%identity%'
  )
ORDER BY n.nspname, p.proname;

-- Check for event triggers
SELECT 
    'EVENT TRIGGERS' as check_type,
    evtname as trigger_name,
    evtevent as event,
    evtenabled as enabled
FROM pg_event_trigger;

-- Check all triggers on auth schema tables
SELECT 
    'TRIGGERS ON AUTH TABLES' as check_type,
    event_object_table as table_name,
    trigger_name,
    action_statement,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
ORDER BY event_object_table, trigger_name;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ANALYSIS';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Look for:';
    RAISE NOTICE '  - Any triggers on auth.users or auth.identities';
    RAISE NOTICE '  - Any functions that might be failing';
    RAISE NOTICE '  - Event triggers that run on user creation';
    RAISE NOTICE '';
    RAISE NOTICE 'These could be causing the "Database error finding user"';
    RAISE NOTICE '';
END $$;

