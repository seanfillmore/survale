-- =====================================================
-- TEMPORARILY DISABLE TRIGGER TO TEST
-- =====================================================
-- This disables the trigger so we can test if the
-- signup works without it
-- =====================================================

-- Disable the trigger
ALTER TABLE auth.users DISABLE TRIGGER on_auth_user_created;

DO $$
BEGIN
    RAISE NOTICE '✅ Trigger disabled';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Now try to sign up in the app';
    RAISE NOTICE '   If it works, the trigger is the problem';
    RAISE NOTICE '   If it still fails, there''s another issue';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Remember to re-enable the trigger after testing:';
    RAISE NOTICE '   ALTER TABLE auth.users ENABLE TRIGGER on_auth_user_created;';
END $$;

