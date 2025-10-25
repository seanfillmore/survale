-- Fix rpc_get_operation_targets to include images from JSONB data
-- This updates the function to extract and return the images array

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
    
    -- Get targets from JSONB data column (NOW INCLUDING IMAGES)
    SELECT json_build_object(
        'targets', COALESCE((
            SELECT json_agg(
                (jsonb_build_object(
                    'id', t.id,
                    'type', t.type,
                    'created_at', t.created_at
                ) || 
                CASE WHEN t.type = 'person' THEN
                    jsonb_build_object(
                        'person', to_jsonb(json_build_object(
                            'first_name', t.data->>'first_name',
                            'last_name', t.data->>'last_name',
                            'phone_number', t.data->>'phone_number',
                            'notes', t.data->>'notes',
                            'images', COALESCE((t.data->'images')::json, '[]'::json)
                        ))
                    )
                WHEN t.type = 'vehicle' THEN
                    jsonb_build_object(
                        'vehicle', to_jsonb(json_build_object(
                            'make', t.data->>'make',
                            'model', t.data->>'model',
                            'color', t.data->>'color',
                            'plate', t.data->>'plate',
                            'notes', t.data->>'notes',
                            'images', COALESCE((t.data->'images')::json, '[]'::json)
                        ))
                    )
                WHEN t.type = 'location' THEN
                    jsonb_build_object(
                        'location', to_jsonb(json_build_object(
                            'label', t.data->>'label',
                            'address', t.data->>'address',
                            'latitude', (t.data->>'latitude')::double precision,
                            'longitude', (t.data->>'longitude')::double precision,
                            'notes', t.data->>'notes',
                            'images', COALESCE((t.data->'images')::json, '[]'::json)
                        ))
                    )
                ELSE '{}'::jsonb
                END)::json
            )
            FROM targets t
            WHERE t.operation_id = rpc_get_operation_targets.operation_id
        ), '[]'::json),
        'staging', COALESCE((
            SELECT json_agg(json_build_object(
                'id', sa.id,
                'label', sa.name,
                'latitude', sa.lat,
                'longitude', sa.lon
            ))
            FROM staging_areas sa
            WHERE sa.operation_id = rpc_get_operation_targets.operation_id
        ), '[]'::json)
    ) INTO result;
    
    RETURN result;
END;
$$;

SELECT 'rpc_get_operation_targets updated with images support!' as status;

