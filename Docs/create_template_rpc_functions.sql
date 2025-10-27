-- Create RPC functions for operation templates
-- Run this AFTER create_templates_schema.sql

-- ============================================
-- Function: Save an operation as a template
-- ============================================

CREATE OR REPLACE FUNCTION public.rpc_save_operation_as_template(
    p_name text,
    p_description text DEFAULT NULL,
    p_operation_id uuid DEFAULT NULL,
    p_is_public boolean DEFAULT false,
    p_targets jsonb DEFAULT '[]'::jsonb,
    p_staging jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_template_id uuid;
    v_user_id uuid;
    v_team_id uuid;
    v_agency_id uuid;
    v_target jsonb;
    v_staging_point jsonb;
    v_target_id uuid;
    v_staging_id uuid;
BEGIN
    -- Get the authenticated user's ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user's team and agency from users table
    SELECT team_id, agency_id INTO v_team_id, v_agency_id
    FROM public.users
    WHERE id = v_user_id;

    IF v_team_id IS NULL OR v_agency_id IS NULL THEN
        RAISE EXCEPTION 'User must belong to a team and agency';
    END IF;

    -- Generate new template ID
    v_template_id := gen_random_uuid();

    -- Insert the template
    INSERT INTO public.operation_templates (
        id,
        name,
        description,
        created_by_user_id,
        team_id,
        agency_id,
        is_public,
        created_at,
        updated_at
    ) VALUES (
        v_template_id,
        p_name,
        p_description,
        v_user_id,
        v_team_id,
        v_agency_id,
        p_is_public,
        now(),
        now()
    );

    -- Insert targets
    FOR v_target IN SELECT * FROM jsonb_array_elements(p_targets)
    LOOP
        v_target_id := gen_random_uuid();
        
        INSERT INTO public.template_targets (
            id,
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
            v_target_id,
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
            CASE WHEN v_target->>'location_lat' IS NOT NULL 
                THEN (v_target->>'location_lat')::double precision 
                ELSE NULL END,
            CASE WHEN v_target->>'location_lng' IS NOT NULL 
                THEN (v_target->>'location_lng')::double precision 
                ELSE NULL END
        );
    END LOOP;

    -- Insert staging points
    FOR v_staging_point IN SELECT * FROM jsonb_array_elements(p_staging)
    LOOP
        v_staging_id := gen_random_uuid();
        
        INSERT INTO public.template_staging_points (
            id,
            template_id,
            label,
            latitude,
            longitude
        ) VALUES (
            v_staging_id,
            v_template_id,
            v_staging_point->>'label',
            (v_staging_point->>'latitude')::double precision,
            (v_staging_point->>'longitude')::double precision
        );
    END LOOP;

    -- Return the template ID
    RETURN jsonb_build_object('template_id', v_template_id);
END;
$$;

-- ============================================
-- Function: Get templates (personal or agency-wide)
-- ============================================

CREATE OR REPLACE FUNCTION public.rpc_get_templates(
    p_scope text DEFAULT 'mine'
)
RETURNS TABLE (
    id uuid,
    name text,
    description text,
    created_by_user_id uuid,
    is_public boolean,
    created_at timestamptz,
    updated_at timestamptz,
    target_count bigint,
    staging_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_agency_id uuid;
BEGIN
    -- Get the authenticated user's ID
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user's agency
    SELECT agency_id INTO v_agency_id
    FROM public.users
    WHERE id = v_user_id;

    -- Return templates based on scope
    IF p_scope = 'mine' THEN
        -- Return only user's own templates
        RETURN QUERY
        SELECT
            t.id::uuid,
            t.name::text,
            t.description::text,
            t.created_by_user_id::uuid,
            t.is_public::boolean,
            t.created_at::timestamptz,
            t.updated_at::timestamptz,
            COUNT(DISTINCT tgt.id)::bigint as target_count,
            COUNT(DISTINCT sp.id)::bigint as staging_count
        FROM public.operation_templates t
        LEFT JOIN public.template_targets tgt ON tgt.template_id = t.id
        LEFT JOIN public.template_staging_points sp ON sp.template_id = t.id
        WHERE t.created_by_user_id = v_user_id
        GROUP BY t.id, t.name, t.description, t.created_by_user_id, t.is_public, t.created_at, t.updated_at
        ORDER BY t.updated_at DESC NULLS LAST, t.created_at DESC;
    ELSE
        -- Return agency-wide public templates (excluding user's own)
        RETURN QUERY
        SELECT
            t.id::uuid,
            t.name::text,
            t.description::text,
            t.created_by_user_id::uuid,
            t.is_public::boolean,
            t.created_at::timestamptz,
            t.updated_at::timestamptz,
            COUNT(DISTINCT tgt.id)::bigint as target_count,
            COUNT(DISTINCT sp.id)::bigint as staging_count
        FROM public.operation_templates t
        LEFT JOIN public.template_targets tgt ON tgt.template_id = t.id
        LEFT JOIN public.template_staging_points sp ON sp.template_id = t.id
        WHERE t.is_public = true
          AND t.agency_id = v_agency_id
          AND t.created_by_user_id != v_user_id
        GROUP BY t.id, t.name, t.description, t.created_by_user_id, t.is_public, t.created_at, t.updated_at
        ORDER BY t.updated_at DESC NULLS LAST, t.created_at DESC;
    END IF;
END;
$$;

-- ============================================
-- Function: Get template details with targets and staging
-- ============================================

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

    -- Get staging points
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sp.id,
            'label', sp.label,
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
GRANT EXECUTE ON FUNCTION public.rpc_save_operation_as_template(text, text, uuid, boolean, jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_templates(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_get_template_details(uuid) TO authenticated;

