-- =====================================================
-- FIX TRIGGER PERMISSIONS AND SCHEMA ACCESS
-- =====================================================
-- This ensures the trigger function can properly access
-- the public schema tables from the auth schema context
-- =====================================================

-- Recreate the function with explicit schema references and better permissions
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER  -- Run with the permissions of the function owner (postgres)
SET search_path = public, auth  -- Explicitly set search path
AS $$
DECLARE
    default_agency_id uuid;
    default_team_id uuid;
    user_exists boolean;
BEGIN
    -- Check if user already exists
    SELECT EXISTS(
        SELECT 1 FROM public.users WHERE id = NEW.id
    ) INTO user_exists;
    
    IF user_exists THEN
        RETURN NEW;
    END IF;
    
    -- Get the default agency and team IDs with explicit schema
    SELECT a.id, t.id 
    INTO default_agency_id, default_team_id
    FROM public.agencies a
    INNER JOIN public.teams t ON t.agency_id = a.id
    WHERE a.name = 'Test Agency'
      AND t.name = 'Test Team'
    LIMIT 1;
    
    -- If no default found, raise an error
    IF default_agency_id IS NULL OR default_team_id IS NULL THEN
        RAISE EXCEPTION 'Default test agency and team not found';
    END IF;
    
    -- Insert the user record
    INSERT INTO public.users (
        id,
        email,
        agency_id,
        team_id,
        created_at
    ) VALUES (
        NEW.id,
        NEW.email,
        default_agency_id,
        default_team_id,
        COALESCE(NEW.created_at, NOW())
    );
    
    RETURN NEW;
    
EXCEPTION WHEN OTHERS THEN
    -- Log error and re-raise
    RAISE WARNING 'Error in handle_new_user: % %', SQLERRM, SQLSTATE;
    RAISE;
END;
$$;

-- Set function owner to postgres (superuser)
ALTER FUNCTION public.handle_new_user() OWNER TO postgres;

-- Grant execute permissions to all relevant roles
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon;

-- Ensure the supabase_auth_admin role can execute it
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
        GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;
    END IF;
END $$;

-- Grant table permissions
GRANT SELECT ON public.agencies TO postgres, service_role, authenticated, anon;
GRANT SELECT ON public.teams TO postgres, service_role, authenticated, anon;
GRANT INSERT, SELECT, UPDATE ON public.users TO postgres, service_role, authenticated, anon;

-- Ensure supabase_auth_admin can access tables
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
        GRANT SELECT ON public.agencies TO supabase_auth_admin;
        GRANT SELECT ON public.teams TO supabase_auth_admin;
        GRANT INSERT, SELECT, UPDATE ON public.users TO supabase_auth_admin;
    END IF;
END $$;

-- Recreate the trigger (just to be sure)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

DO $$
BEGIN
    RAISE NOTICE '✅ Trigger function updated with proper permissions';
    RAISE NOTICE '✅ All necessary grants applied';
    RAISE NOTICE '✅ Trigger recreated';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test by creating a new user account in the app';
END $$;

