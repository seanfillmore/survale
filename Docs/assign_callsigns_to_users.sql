-- ============================================================================
-- Add Callsigns to Existing Users Without One
-- ============================================================================
-- This script generates and assigns callsigns to users who don't have one.
-- Callsigns are generated in the format: ALPHA-1, BRAVO-2, etc.
-- ============================================================================

DO $$
DECLARE
    user_record RECORD;
    phonetic_alphabet TEXT[] := ARRAY['ALPHA', 'BRAVO', 'CHARLIE', 'DELTA', 'ECHO', 
                                       'FOXTROT', 'GOLF', 'HOTEL', 'INDIA', 'JULIET',
                                       'KILO', 'LIMA', 'MIKE', 'NOVEMBER', 'OSCAR',
                                       'PAPA', 'QUEBEC', 'ROMEO', 'SIERRA', 'TANGO',
                                       'UNIFORM', 'VICTOR', 'WHISKEY', 'XRAY', 'YANKEE', 'ZULU'];
    counter INT := 1;
    phonetic_index INT := 1;
    new_callsign TEXT;
BEGIN
    -- Loop through all users without a callsign
    FOR user_record IN 
        SELECT id, email, full_name 
        FROM public.users 
        WHERE callsign IS NULL OR callsign = ''
        ORDER BY created_at ASC
    LOOP
        -- Generate callsign
        new_callsign := phonetic_alphabet[phonetic_index] || '-' || counter;
        
        -- Update user with new callsign
        UPDATE public.users
        SET callsign = new_callsign
        WHERE id = user_record.id;
        
        RAISE NOTICE 'Assigned callsign % to user % (email: %)', 
                     new_callsign, 
                     COALESCE(user_record.full_name, 'Unknown'),
                     user_record.email;
        
        -- Increment counter and phonetic index
        counter := counter + 1;
        
        -- Move to next phonetic word every 10 users
        IF counter > 10 THEN
            counter := 1;
            phonetic_index := phonetic_index + 1;
            
            -- Reset to ALPHA if we've exhausted the alphabet
            IF phonetic_index > array_length(phonetic_alphabet, 1) THEN
                phonetic_index := 1;
            END IF;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Callsign assignment complete!';
END $$;

-- ============================================================================
-- Verification Query
-- ============================================================================
-- Run this to see all user callsigns:

SELECT 
    id,
    COALESCE(full_name, email) as name,
    callsign,
    email,
    created_at
FROM public.users
ORDER BY callsign;

-- ============================================================================
-- Alternative: Assign Callsigns Based on User Preferences
-- ============================================================================
-- If you want to manually assign specific callsigns, use this instead:

/*
UPDATE public.users 
SET callsign = 'ALPHA-1' 
WHERE email = 'user1@example.com';

UPDATE public.users 
SET callsign = 'BRAVO-1' 
WHERE email = 'user2@example.com';

-- etc...
*/

