-- =====================================================
-- PRODUCTION-READY SIGNUP TRIGGER
-- =====================================================
-- Based on Supabase recommendation
-- This will automatically create public.users records when
-- someone signs up, with proper error handling
-- =====================================================

-- 1) Create audit table for tracking signup issues
CREATE TABLE IF NOT EXISTS public.signup_audit (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  auth_user_id uuid,
  email text,
  error text,
  created_at timestamptz DEFAULT now()
);

-- 2) Create the trigger function (in public schema, not auth)
CREATE OR REPLACE FUNCTION public.create_public_user_after_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_agency uuid;
  v_team uuid;
BEGIN
  -- If a public.users row already exists, skip
  IF EXISTS (SELECT 1 FROM public.users WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;

  -- Get default Test Agency and Test Team
  SELECT a.id, t.id INTO v_agency, v_team
  FROM public.agencies a
  JOIN public.teams t ON t.agency_id = a.id
  WHERE a.name = 'Test Agency' AND t.name = 'Test Team'
  LIMIT 1;

  -- Try to insert the user profile
  BEGIN
    INSERT INTO public.users (
      id,
      email,
      agency_id,
      team_id,
      created_at
    ) VALUES (
      NEW.id,
      NEW.email,
      v_agency,
      v_team,
      NOW()
    );
    
  EXCEPTION 
    WHEN unique_violation THEN
      -- Profile already exists, that's fine
      NULL;
      
    WHEN foreign_key_violation THEN
      -- Agency or team doesn't exist
      INSERT INTO public.signup_audit (auth_user_id, email, error)
      VALUES (NEW.id, NEW.email, 'Missing Test Agency or Test Team');
      
    WHEN OTHERS THEN
      -- Log any other error
      INSERT INTO public.signup_audit (auth_user_id, email, error)
      VALUES (NEW.id, NEW.email, SQLERRM);
  END;

  RETURN NEW;
END;
$$;

-- 3) Create the trigger (on auth.users but calling public function)
DROP TRIGGER IF EXISTS create_public_user_after_signup ON auth.users;

CREATE TRIGGER create_public_user_after_signup
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_public_user_after_signup();

-- 4) Security: Revoke public access to the function
REVOKE EXECUTE ON FUNCTION public.create_public_user_after_signup() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_public_user_after_signup() FROM anon;
REVOKE EXECUTE ON FUNCTION public.create_public_user_after_signup() FROM authenticated;

-- Grant to service role
GRANT EXECUTE ON FUNCTION public.create_public_user_after_signup() TO service_role;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ SIGNUP TRIGGER INSTALLED';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'How it works:';
    RAISE NOTICE '1. User signs up → auth.users record created';
    RAISE NOTICE '2. Trigger fires → public.users record created automatically';
    RAISE NOTICE '3. User assigned to Test Agency and Test Team';
    RAISE NOTICE '4. Any errors logged to signup_audit table';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Test by creating a new user account in the app';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Monitor: SELECT * FROM public.signup_audit;';
    RAISE NOTICE '';
END $$;

