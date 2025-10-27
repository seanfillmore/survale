-- Create operation templates schema
-- Run this in your Supabase SQL Editor

-- Create operation_templates table
CREATE TABLE IF NOT EXISTS public.operation_templates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    created_by_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    team_id uuid NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    agency_id uuid NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
    is_public boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz,
    CONSTRAINT valid_name CHECK (char_length(name) > 0 AND char_length(name) <= 200)
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_operation_templates_created_by ON public.operation_templates(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_operation_templates_agency ON public.operation_templates(agency_id);
CREATE INDEX IF NOT EXISTS idx_operation_templates_team ON public.operation_templates(team_id);
CREATE INDEX IF NOT EXISTS idx_operation_templates_public ON public.operation_templates(is_public) WHERE is_public = true;

-- Create template_targets table (similar to op_targets but for templates)
CREATE TABLE IF NOT EXISTS public.template_targets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id uuid NOT NULL REFERENCES public.operation_templates(id) ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('person', 'vehicle', 'location')),
    
    -- Person fields
    person_first_name text,
    person_last_name text,
    phone text,
    
    -- Vehicle fields
    vehicle_make text,
    vehicle_model text,
    vehicle_color text,
    license_plate text,
    
    -- Location fields
    location_name text,
    location_address text,
    location_lat double precision,
    location_lng double precision,
    
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_template_targets_template ON public.template_targets(template_id);

-- Create template_staging_points table
CREATE TABLE IF NOT EXISTS public.template_staging_points (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id uuid NOT NULL REFERENCES public.operation_templates(id) ON DELETE CASCADE,
    label text NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_template_staging_template ON public.template_staging_points(template_id);

-- Enable RLS
ALTER TABLE public.operation_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_staging_points ENABLE ROW LEVEL SECURITY;

-- RLS Policies for operation_templates

-- Users can see their own templates
CREATE POLICY "Users can view own templates" ON public.operation_templates
    FOR SELECT
    USING (auth.uid() = created_by_user_id);

-- Users can see public templates from their agency
CREATE POLICY "Users can view agency public templates" ON public.operation_templates
    FOR SELECT
    USING (
        is_public = true 
        AND agency_id IN (SELECT agency_id FROM public.users WHERE id = auth.uid())
    );

-- Users can create templates
CREATE POLICY "Users can create templates" ON public.operation_templates
    FOR INSERT
    WITH CHECK (auth.uid() = created_by_user_id);

-- Users can update their own templates
CREATE POLICY "Users can update own templates" ON public.operation_templates
    FOR UPDATE
    USING (auth.uid() = created_by_user_id);

-- Users can delete their own templates
CREATE POLICY "Users can delete own templates" ON public.operation_templates
    FOR DELETE
    USING (auth.uid() = created_by_user_id);

-- RLS Policies for template_targets (inherit from template)

CREATE POLICY "Users can view template targets" ON public.template_targets
    FOR SELECT
    USING (
        template_id IN (
            SELECT id FROM public.operation_templates 
            WHERE created_by_user_id = auth.uid() 
               OR (is_public = true AND agency_id IN (SELECT agency_id FROM public.users WHERE id = auth.uid()))
        )
    );

CREATE POLICY "Users can manage own template targets" ON public.template_targets
    FOR ALL
    USING (
        template_id IN (SELECT id FROM public.operation_templates WHERE created_by_user_id = auth.uid())
    );

-- RLS Policies for template_staging_points (inherit from template)

CREATE POLICY "Users can view template staging" ON public.template_staging_points
    FOR SELECT
    USING (
        template_id IN (
            SELECT id FROM public.operation_templates 
            WHERE created_by_user_id = auth.uid() 
               OR (is_public = true AND agency_id IN (SELECT agency_id FROM public.users WHERE id = auth.uid()))
        )
    );

CREATE POLICY "Users can manage own template staging" ON public.template_staging_points
    FOR ALL
    USING (
        template_id IN (SELECT id FROM public.operation_templates WHERE created_by_user_id = auth.uid())
    );

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.operation_templates TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.template_targets TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.template_staging_points TO authenticated;

COMMENT ON TABLE public.operation_templates IS 'Reusable operation templates with targets and staging points';
COMMENT ON COLUMN public.operation_templates.is_public IS 'If true, visible to all users in the agency. If false, only visible to creator';

