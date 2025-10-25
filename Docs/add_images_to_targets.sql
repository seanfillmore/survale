-- Add Image Support to Targets
-- This updates the RPC functions to handle image URLs in the target data

-- The images will be stored as a JSON array in the data field:
-- {
--   "images": [
--     {
--       "id": "uuid",
--       "url": "https://...",
--       "filename": "image.jpg",
--       "created_at": "2025-10-19T12:00:00Z",
--       "caption": "Optional caption"
--     }
--   ]
-- }

-- 1. UPDATE PERSON TARGET - Add images parameter
CREATE OR REPLACE FUNCTION public.rpc_create_person_target(
    operation_id UUID,
    first_name TEXT,
    last_name TEXT,
    phone TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    images JSONB DEFAULT '[]'::jsonb
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_target_id UUID;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_create_person_target.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    INSERT INTO targets (operation_id, type, created_by, data)
    VALUES (
        rpc_create_person_target.operation_id, 
        'person', 
        auth.uid(),
        jsonb_build_object(
            'first_name', first_name, 
            'last_name', last_name, 
            'phone', phone,
            'notes', notes,
            'images', images
        )
    )
    RETURNING id INTO new_target_id;
    
    RETURN json_build_object('target_id', new_target_id);
END;
$$;

-- 2. UPDATE VEHICLE TARGET - Add images parameter
CREATE OR REPLACE FUNCTION public.rpc_create_vehicle_target(
    operation_id UUID,
    make TEXT DEFAULT NULL,
    model TEXT DEFAULT NULL,
    color TEXT DEFAULT NULL,
    plate TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    images JSONB DEFAULT '[]'::jsonb
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_target_id UUID;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_create_vehicle_target.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    INSERT INTO targets (operation_id, type, created_by, data)
    VALUES (
        rpc_create_vehicle_target.operation_id, 
        'vehicle', 
        auth.uid(),
        jsonb_build_object(
            'make', make, 
            'model', model, 
            'color', color, 
            'plate', plate,
            'notes', notes,
            'images', images
        )
    )
    RETURNING id INTO new_target_id;
    
    RETURN json_build_object('target_id', new_target_id);
END;
$$;

-- 3. UPDATE LOCATION TARGET - Add images parameter
CREATE OR REPLACE FUNCTION public.rpc_create_location_target(
    operation_id UUID,
    address TEXT,
    label TEXT DEFAULT NULL,
    city TEXT DEFAULT NULL,
    zip_code TEXT DEFAULT NULL,
    latitude DOUBLE PRECISION DEFAULT NULL,
    longitude DOUBLE PRECISION DEFAULT NULL,
    notes TEXT DEFAULT NULL,
    images JSONB DEFAULT '[]'::jsonb
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_target_id UUID;
    full_address TEXT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = rpc_create_location_target.operation_id
        AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    full_address := address;
    IF city IS NOT NULL THEN
        full_address := full_address || ', ' || city;
    END IF;
    IF zip_code IS NOT NULL THEN
        full_address := full_address || ' ' || zip_code;
    END IF;
    
    INSERT INTO targets (operation_id, type, created_by, data)
    VALUES (
        rpc_create_location_target.operation_id, 
        'location', 
        auth.uid(),
        jsonb_build_object(
            'label', COALESCE(label, full_address),
            'address', full_address,
            'latitude', latitude,
            'longitude', longitude,
            'notes', notes,
            'images', images
        )
    )
    RETURNING id INTO new_target_id;
    
    RETURN json_build_object('target_id', new_target_id);
END;
$$;

-- 4. ADD FUNCTION TO UPDATE TARGET IMAGES
-- This allows adding/removing images after target creation
CREATE OR REPLACE FUNCTION public.rpc_update_target_images(
    target_id UUID,
    images JSONB
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check user is member of the operation
    IF NOT EXISTS (
        SELECT 1 FROM targets t
        JOIN operation_members om ON t.operation_id = om.operation_id
        WHERE t.id = rpc_update_target_images.target_id
        AND om.user_id = auth.uid()
        AND om.left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    -- Update images in the data JSONB field
    UPDATE targets
    SET data = jsonb_set(data, '{images}', images, true)
    WHERE id = rpc_update_target_images.target_id;
    
    RETURN json_build_object('success', true);
END;
$$;

-- Done!
SELECT 'Image support added to target RPC functions!' as status;

