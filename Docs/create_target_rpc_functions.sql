-- ============================================
-- CREATE TARGET RPC FUNCTIONS
-- ============================================
-- These functions handle the polymorphic target structure

-- 1. CREATE PERSON TARGET
CREATE OR REPLACE FUNCTION public.rpc_create_person_target(
    operation_id UUID,
    first_name TEXT,
    last_name TEXT,
    phone_number TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_target_id UUID;
BEGIN
    -- Check user is member of operation
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_create_person_target.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Create main target record
    INSERT INTO targets (operation_id, type, created_by)
    VALUES (rpc_create_person_target.operation_id, 'person', auth.uid())
    RETURNING id INTO new_target_id;
    
    -- Create person details
    INSERT INTO target_person (target_id, first_name, last_name, phone_number, notes)
    VALUES (new_target_id, first_name, last_name, phone_number, notes);
    
    RETURN json_build_object('target_id', new_target_id);
END;
$$;

-- 2. CREATE VEHICLE TARGET
CREATE OR REPLACE FUNCTION public.rpc_create_vehicle_target(
    operation_id UUID,
    make TEXT DEFAULT NULL,
    model TEXT DEFAULT NULL,
    color TEXT DEFAULT NULL,
    plate TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_target_id UUID;
BEGIN
    -- Check user is member of operation
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_create_vehicle_target.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Create main target record
    INSERT INTO targets (operation_id, type, created_by)
    VALUES (rpc_create_vehicle_target.operation_id, 'vehicle', auth.uid())
    RETURNING id INTO new_target_id;
    
    -- Create vehicle details
    INSERT INTO target_vehicle (target_id, make, model, color, plate, notes)
    VALUES (new_target_id, make, model, color, plate, notes);
    
    RETURN json_build_object('target_id', new_target_id);
END;
$$;

-- 3. CREATE LOCATION TARGET
CREATE OR REPLACE FUNCTION public.rpc_create_location_target(
    operation_id UUID,
    address TEXT,
    city TEXT DEFAULT NULL,
    zip_code TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_target_id UUID;
    full_address TEXT;
BEGIN
    -- Check user is member of operation
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_create_location_target.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Build full address
    full_address := address;
    IF city IS NOT NULL THEN
        full_address := full_address || ', ' || city;
    END IF;
    IF zip_code IS NOT NULL THEN
        full_address := full_address || ' ' || zip_code;
    END IF;
    
    -- Create main target record
    INSERT INTO targets (operation_id, type, created_by)
    VALUES (rpc_create_location_target.operation_id, 'location', auth.uid())
    RETURNING id INTO new_target_id;
    
    -- Create location details
    INSERT INTO target_location (target_id, address, notes)
    VALUES (new_target_id, full_address, notes);
    
    RETURN json_build_object('target_id', new_target_id);
END;
$$;

-- 4. CREATE STAGING POINT
CREATE OR REPLACE FUNCTION public.rpc_create_staging_point(
    operation_id UUID,
    label TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_staging_id UUID;
BEGIN
    -- Check user is case agent or member
    IF NOT EXISTS (
        SELECT 1 FROM operations o
        LEFT JOIN operation_members om ON o.id = om.operation_id
        WHERE o.id = rpc_create_staging_point.operation_id
        AND (o.case_agent_id = auth.uid() OR om.user_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'User not authorized for this operation';
    END IF;
    
    -- Create staging point with coordinates
    -- Try common column name variations
    INSERT INTO staging_areas (operation_id, name, lat, lon)
    VALUES (rpc_create_staging_point.operation_id, label, latitude, longitude)
    RETURNING id INTO new_staging_id;
    
    RETURN json_build_object('staging_id', new_staging_id);
END;
$$;

-- 5. FETCH TARGETS FOR OPERATION
CREATE OR REPLACE FUNCTION public.rpc_get_operation_targets(
    operation_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
BEGIN
    -- Check user is member
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_get_operation_targets.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Get all targets with their details
    SELECT json_build_object(
        'targets', COALESCE((
            SELECT json_agg(json_build_object(
                'id', t.id,
                'type', t.type,
                'created_at', t.created_at,
                'person', CASE WHEN t.type = 'person' THEN
                    json_build_object(
                        'first_name', tp.first_name,
                        'last_name', tp.last_name,
                        'phone_number', tp.phone_number,
                        'notes', tp.notes
                    )
                END,
                'vehicle', CASE WHEN t.type = 'vehicle' THEN
                    json_build_object(
                        'make', tv.make,
                        'model', tv.model,
                        'color', tv.color,
                        'plate', tv.plate,
                        'notes', tv.notes
                    )
                END,
                'location', CASE WHEN t.type = 'location' THEN
                    json_build_object(
                        'address', tl.address,
                        'notes', tl.notes
                    )
                END
            ))
            FROM targets t
            LEFT JOIN target_person tp ON t.id = tp.target_id
            LEFT JOIN target_vehicle tv ON t.id = tv.target_id
            LEFT JOIN target_location tl ON t.id = tl.target_id
            WHERE t.operation_id = rpc_get_operation_targets.operation_id
        ), '[]'::json),
        'staging', COALESCE((
            SELECT json_agg(json_build_object(
                'id', sa.id,
                'label', sa.name,
                'latitude', sa.lat,
                'longitude', sa.lon,
                'created_at', sa.created_at
            ))
            FROM staging_areas sa
            WHERE sa.operation_id = rpc_get_operation_targets.operation_id
        ), '[]'::json)
    ) INTO result;
    
    RETURN result;
END;
$$;

-- Verify functions were created
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE 'rpc_%target%'
OR routine_name LIKE 'rpc_%staging%'
ORDER BY routine_name;

SELECT '✅ All target/staging RPC functions created!' as status;

