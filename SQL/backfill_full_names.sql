-- Backfill full_name for existing users who have first_name and last_name
-- but are missing full_name (created before auth trigger was fixed)

DO $$
DECLARE
    v_updated_count int := 0;
BEGIN
    -- Update users where full_name is NULL or empty but first_name and last_name exist
    UPDATE users
    SET 
        full_name = TRIM(CONCAT(first_name, ' ', last_name)),
        updated_at = NOW()
    WHERE 
        (full_name IS NULL OR TRIM(full_name) = '')
        AND first_name IS NOT NULL 
        AND last_name IS NOT NULL
        AND TRIM(first_name) != ''
        AND TRIM(last_name) != '';
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    
    RAISE NOTICE '✅ Updated % user(s) with constructed full_name from first_name + last_name', v_updated_count;
    
    -- Show the updated users
    RAISE NOTICE '';
    RAISE NOTICE 'Updated users:';
    
    -- This will output to console
    PERFORM 
        RAISE NOTICE '  • % (%) - full_name now: %', 
            email, 
            id, 
            full_name
    FROM users
    WHERE updated_at >= NOW() - INTERVAL '10 seconds'
    ORDER BY email;
    
END $$;

-- Verify the results
SELECT 
    id,
    email,
    first_name,
    last_name,
    full_name,
    callsign
FROM users
ORDER BY email;

