-- =====================================================
-- CHECK AUTH.IDENTITIES SCHEMA AND CONSTRAINTS
-- =====================================================

-- Check the structure of auth.identities
SELECT 
    'COLUMNS' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'auth'
  AND table_name = 'identities'
ORDER BY ordinal_position;

-- Check indexes on auth.identities
SELECT 
    'INDEXES' as check_type,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'auth'
  AND tablename = 'identities';

-- Check constraints
SELECT 
    'CONSTRAINTS' as check_type,
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint
WHERE conrelid = 'auth.identities'::regclass;

-- Show current data in auth.identities
SELECT 
    'CURRENT DATA' as check_type,
    id,
    user_id,
    provider,
    identity_data->>'email' as email,
    created_at,
    updated_at
FROM auth.identities
ORDER BY created_at DESC;

-- Check for duplicate email issues
SELECT 
    'DUPLICATE CHECK' as check_type,
    identity_data->>'email' as email,
    COUNT(*) as count
FROM auth.identities
GROUP BY identity_data->>'email'
HAVING COUNT(*) > 1;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RECOMMENDATIONS';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'If you see any issues above, we may need to:';
    RAISE NOTICE '1. Rebuild auth.identities indexes';
    RAISE NOTICE '2. Check for corrupted constraint definitions';
    RAISE NOTICE '3. Contact Supabase support';
    RAISE NOTICE '';
END $$;

