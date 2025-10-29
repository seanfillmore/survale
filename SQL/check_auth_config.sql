-- =====================================================
-- CHECK SUPABASE AUTH CONFIGURATION
-- =====================================================

-- Check auth schema for any config tables
SELECT 
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'auth'
ORDER BY table_name;

-- Check for auth hooks in extensions
SELECT 
    extname as extension_name,
    extversion as version
FROM pg_extension
WHERE extname LIKE '%auth%'
   OR extname LIKE '%supabase%';

-- Check if there are any webhooks configured
DO $$
DECLARE
    webhook_count int;
BEGIN
    -- Try to check for webhooks (this table may or may not exist)
    BEGIN
        SELECT COUNT(*) INTO webhook_count
        FROM pg_tables
        WHERE schemaname = 'supabase_functions'
          AND tablename = 'hooks';
        
        IF webhook_count > 0 THEN
            RAISE NOTICE 'Webhooks/hooks table exists in supabase_functions schema';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'No webhooks/hooks table found (this is normal)';
    END;
END $$;

-- Most importantly: Check the actual error
-- Let's see if we can find any logs or error messages
SELECT 
    'Check Supabase Dashboard → Logs → Database' as action,
    'Look for errors around the timestamp: ' || NOW()::text as timestamp_hint;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'NEXT STEPS';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '1. Go to Supabase Dashboard → Logs → Database';
    RAISE NOTICE '2. Look for recent errors (they will show the actual problem)';
    RAISE NOTICE '3. Share the error message here';
    RAISE NOTICE '';
    RAISE NOTICE 'Also check:';
    RAISE NOTICE '- Dashboard → Authentication → Users (see if users are being created)';
    RAISE NOTICE '- Dashboard → Table Editor → users (see if records exist)';
    RAISE NOTICE '';
END $$;

