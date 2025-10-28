-- Add address column to template_staging_points
-- Run this in your Supabase SQL Editor

-- Add address column if it doesn't exist
ALTER TABLE public.template_staging_points 
ADD COLUMN IF NOT EXISTS address text;

-- Update the rpc_save_operation_as_template function to include address
DROP FUNCTION IF EXISTS public.rpc_save_operation_as_template(text, text, boolean, jsonb, jsonb) CASCADE;

CREATE OR REPLACE FUNCTION public.rpc_save_operation_as_template(
    p_name text,
    p_description text DEFAULT NULL,
    p_is_public boolean DEFAULT false,
    p_targets jsonb DEFAULT '[]'::jsonb,
    p_staging jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_team_id uuid;
    v_agency_id uuid;
    v_template_id uuid;
    v_target jsonb;
    v_staging_point jsonb;
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user's team and agency
    SELECT team_id, agency_id INTO v_team_id, v_agency_id
    FROM public.users
    WHERE id = v_user_id;

    IF v_team_id IS NULL OR v_agency_id IS NULL THEN
        RAISE EXCEPTION 'User must belong to a team and agency';
    END IF;

    -- Create template
    INSERT INTO public.operation_templates (
        name,
        description,
        created_by_user_id,
        team_id,
        agency_id,
        is_public,
        created_at,
        updated_at
    ) VALUES (
        p_name,
        p_description,
        v_user_id,
        v_team_id,
        v_agency_id,
        p_is_public,
        now(),
        now()
    ) RETURNING id INTO v_template_id;

    -- Insert targets
    FOR v_target IN SELECT * FROM jsonb_array_elements(p_targets)
    LOOP
        INSERT INTO public.template_targets (
            template_id,
            kind,
            person_first_name,
            person_last_name,
            phone,
            vehicle_make,
            vehicle_model,
            vehicle_color,
            license_plate,
            location_name,
            location_address,
            location_lat,
            location_lng
        ) VALUES (
            v_template_id,
            v_target->>'kind',
            v_target->>'person_first_name',
            v_target->>'person_last_name',
            v_target->>'phone',
            v_target->>'vehicle_make',
            v_target->>'vehicle_model',
            v_target->>'vehicle_color',
            v_target->>'license_plate',
            v_target->>'location_name',
            v_target->>'location_address',
            (v_target->>'location_lat')::double precision,
            (v_target->>'location_lng')::double precision
        );
    END LOOP;

    -- Insert staging points (now includes address)
    FOR v_staging_point IN SELECT * FROM jsonb_array_elements(p_staging)
    LOOP
        INSERT INTO public.template_staging_points (
            template_id,
            label,
            address,
            latitude,
            longitude
        ) VALUES (
            v_template_id,
            v_staging_point->>'label',
            v_staging_point->>'address',
            (v_staging_point->>'latitude')::double precision,
            (v_staging_point->>'longitude')::double precision
        );
    END LOOP;

    RETURN jsonb_build_object('template_id', v_template_id);
END;
$$;

-- Update the rpc_get_template_details function to return address
DROP FUNCTION IF EXISTS public.rpc_get_template_details(uuid) CASCADE;

CREATE OR REPLACE FUNCTION public.rpc_get_template_details(
    p_template_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_template jsonb;
    v_targets jsonb;
    v_staging jsonb;
BEGIN
    -- Get template metadata
    SELECT jsonb_build_object(
        'id', t.id,
        'name', t.name,
        'description', t.description,
        'is_public', t.is_public,
        'created_at', t.created_at,
        'updated_at', t.updated_at
    ) INTO v_template
    FROM public.operation_templates t
    WHERE t.id = p_template_id;

    IF v_template IS NULL THEN
        RAISE EXCEPTION 'Template not found';
    END IF;

    -- Get targets
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', tgt.id,
            'kind', tgt.kind,
            'person_first_name', tgt.person_first_name,
            'person_last_name', tgt.person_last_name,
            'phone', tgt.phone,
            'vehicle_make', tgt.vehicle_make,
            'vehicle_model', tgt.vehicle_model,
            'vehicle_color', tgt.vehicle_color,
            'license_plate', tgt.license_plate,
            'location_name', tgt.location_name,
            'location_address', tgt.location_address,
            'location_lat', tgt.location_lat,
            'location_lng', tgt.location_lng
        )
    ), '[]'::jsonb) INTO v_targets
    FROM public.template_targets tgt
    WHERE tgt.template_id = p_template_id;

    -- Get staging points (now includes address)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sp.id,
            'label', sp.label,
            'address', sp.address,
            'latitude', sp.latitude,
            'longitude', sp.longitude
        )
    ), '[]'::jsonb) INTO v_staging
    FROM public.template_staging_points sp
    WHERE sp.template_id = p_template_id;

    -- Return combined result
    RETURN v_template || jsonb_build_object(
        'targets', v_targets,
        'staging', v_staging
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.rpc_save_operation_as_template(text, text, boolean, jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_template_details(uuid) TO authenticated;

COMMENT ON COLUMN public.template_staging_points.address IS 'Human-readable address for the staging point';

