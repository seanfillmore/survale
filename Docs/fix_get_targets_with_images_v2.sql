-- Fixed version - properly handle images array in JSONB

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
    
    -- Build result with targets and staging
    -- The trick: we build everything in JSONB, then cast to JSON at the very end
    SELECT (jsonb_build_object(
        'targets', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', t.id,
                    'type', t.type,
                    'created_at', t.created_at
                ) || 
                CASE WHEN t.type = 'person' THEN
                    jsonb_build_object(
                        'person', jsonb_build_object(
                            'first_name', COALESCE(t.data->>'first_name', ''),
                            'last_name', COALESCE(t.data->>'last_name', ''),
                            'phone_number', t.data->>'phone_number',
                            'notes', t.data->>'notes'
                        ) || jsonb_build_object(
                            'images', COALESCE(t.data->'images', '[]'::jsonb)
                        )
                    )
                WHEN t.type = 'vehicle' THEN
                    jsonb_build_object(
                        'vehicle', jsonb_build_object(
                            'make', t.data->>'make',
                            'model', t.data->>'model',
                            'color', t.data->>'color',
                            'plate', t.data->>'plate',
                            'notes', t.data->>'notes'
                        ) || jsonb_build_object(
                            'images', COALESCE(t.data->'images', '[]'::jsonb)
                        )
                    )
                WHEN t.type = 'location' THEN
                    jsonb_build_object(
                        'location', jsonb_build_object(
                            'label', t.data->>'label',
                            'address', COALESCE(t.data->>'address', ''),
                            'latitude', (t.data->>'latitude')::double precision,
                            'longitude', (t.data->>'longitude')::double precision,
                            'notes', t.data->>'notes'
                        ) || jsonb_build_object(
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

