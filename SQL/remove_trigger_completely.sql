-- =====================================================
-- REMOVE AUTH TRIGGER COMPLETELY
-- =====================================================
-- This removes the trigger so the app can handle
-- user creation directly (simpler and more reliable)
-- =====================================================

-- Drop the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop the function
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Ensure the app has permissions to create users
GRANT INSERT, SELECT, UPDATE, DELETE ON public.users TO authenticated, anon;
GRANT SELECT ON public.agencies TO authenticated, anon;
GRANT SELECT ON public.teams TO authenticated, anon;

-- Disable RLS if it's enabled (for testing)
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    RAISE NOTICE '✅ Trigger and function removed';
    RAISE NOTICE '✅ App permissions granted';
    RAISE NOTICE '✅ RLS disabled for testing';
    RAISE NOTICE '';
    RAISE NOTICE '📱 The app will now handle user creation directly';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Note: You may want to re-enable RLS later for production:';
    RAISE NOTICE '   ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;';
    RAISE NOTICE '   CREATE POLICY ... (add appropriate policies)';
END $$;

