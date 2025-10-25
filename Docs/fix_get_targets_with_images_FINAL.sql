-- FINAL FIX: The problem is that || concatenation was stringifying the images
-- Solution: Build the entire object in one go, including images as a direct JSONB value

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
    
    -- Build result - the key is to include 'images' in the SAME jsonb_build_object call
    -- Do NOT concatenate it with ||, as that causes stringification
    SELECT (jsonb_build_object(
        'targets', COALESCE((
            SELECT jsonb_agg(
                CASE WHEN t.type = 'person' THEN
                    jsonb_build_object(
                        'id', t.id,
                        'type', t.type,
                        'created_at', t.created_at,
                        'person', jsonb_build_object(
                            'first_name', COALESCE(t.data->>'first_name', ''),
                            'last_name', COALESCE(t.data->>'last_name', ''),
                            'phone_number', t.data->>'phone_number',
                            'notes', t.data->>'notes',
                            'images', COALESCE(t.data->'images', '[]'::jsonb)
                        )
                    )
                WHEN t.type = 'vehicle' THEN
                    jsonb_build_object(
                        'id', t.id,
                        'type', t.type,
                        'created_at', t.created_at,
                        'vehicle', jsonb_build_object(
                            'make', t.data->>'make',
                            'model', t.data->>'model',
                            'color', t.data->>'color',
                            'plate', t.data->>'plate',
                            'notes', t.data->>'notes',
                            'images', COALESCE(t.data->'images', '[]'::jsonb)
                        )
                    )
                WHEN t.type = 'location' THEN
                    jsonb_build_object(
                        'id', t.id,
                        'type', t.type,
                        'created_at', t.created_at,
                        'location', jsonb_build_object(
                            'label', t.data->>'label',
                            'address', COALESCE(t.data->>'address', ''),
                            'latitude', (t.data->>'latitude')::double precision,
                            'longitude', (t.data->>'longitude')::double precision,
                            'notes', t.data->>'notes',
                            'images', COALESCE(t.data->'images', '[]'::jsonb)
                        )
                    )
                ELSE '{}'::jsonb
                END
            )
            FROM targets t
            WHERE t.operation_id = rpc_get_operation_targets.operation_id
        ), '[]'::jsonb),
        'staging', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', sa.id,
                'label', sa.name,
                'latitude', sa.lat,
                'longitude', sa.lon
            ))
            FROM staging_areas sa
            WHERE sa.operation_id = rpc_get_operation_targets.operation_id
        ), '[]'::jsonb)
    ))::json INTO result;
    
    RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_get_operation_targets TO authenticated;

-- Test it
-- SELECT rpc_get_operation_targets('your-operation-id-here');

