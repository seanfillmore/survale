-- ============================================
-- Add Draft Support to Operations
-- ============================================
--
-- This script adds draft functionality to allow
-- users to save incomplete operations and resume
-- editing them later.
--
-- Run this script in Supabase SQL Editor
-- ============================================

-- Step 1: Add is_draft column to operations table
ALTER TABLE public.operations 
ADD COLUMN IF NOT EXISTS is_draft BOOLEAN DEFAULT false;

-- Create index for quick draft lookups
CREATE INDEX IF NOT EXISTS idx_operations_draft 
ON public.operations(is_draft, created_by_user_id)
WHERE is_draft = true;

-- Step 2: Create operation_drafts table for additional metadata
CREATE TABLE IF NOT EXISTS public.operation_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES public.operations(id) ON DELETE CASCADE,
    created_by_user_id UUID NOT NULL REFERENCES public.users(id),
    last_edited_at TIMESTAMPTZ DEFAULT NOW(),
    completion_percentage INTEGER DEFAULT 0 CHECK (completion_percentage >= 0 AND completion_percentage <= 100),
    
    -- Ensure one draft metadata record per operation
    UNIQUE(operation_id),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for user draft lookups
CREATE INDEX IF NOT EXISTS idx_operation_drafts_user 
ON public.operation_drafts(created_by_user_id, last_edited_at DESC);

-- Step 3: Create RPC function to create a draft operation
CREATE OR REPLACE FUNCTION public.rpc_create_draft_operation(
    p_name TEXT,
    p_incident_number TEXT,
    p_user_id UUID,
    p_team_id UUID,
    p_agency_id UUID,
    p_targets JSONB DEFAULT '[]'::jsonb,
    p_staging JSONB DEFAULT '[]'::jsonb,
    p_member_ids UUID[] DEFAULT ARRAY[]::UUID[]
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_operation_id UUID;
    v_target JSONB;
    v_staging JSONB;
    v_target_id UUID;
    v_staging_id UUID;
    v_member_id UUID;
    v_completion_pct INTEGER := 0;
BEGIN
    -- Create the operation as a draft
    INSERT INTO public.operations (name, incident_number, created_by_user_id, team_id, agency_id, state, is_draft)
    VALUES (p_name, p_incident_number, p_user_id, p_team_id, p_agency_id, 'pending', true)
    RETURNING id INTO v_operation_id;
    
    -- Add targets if provided
    IF jsonb_array_length(p_targets) > 0 THEN
        FOR v_target IN SELECT * FROM jsonb_array_elements(p_targets)
        LOOP
            INSERT INTO public.op_targets (operation_id, kind, label, data)
            VALUES (
                v_operation_id,
                (v_target->>'kind')::TEXT,
                (v_target->>'label')::TEXT,
                v_target->'data'
            );
        END LOOP;
        v_completion_pct := v_completion_pct + 30;
    END IF;
    
    -- Add staging points if provided
    IF jsonb_array_length(p_staging) > 0 THEN
        FOR v_staging IN SELECT * FROM jsonb_array_elements(p_staging)
        LOOP
            INSERT INTO public.staging_points (operation_id, label, address, lat, lng)
            VALUES (
                v_operation_id,
                (v_staging->>'label')::TEXT,
                COALESCE((v_staging->>'address')::TEXT, ''),
                (v_staging->>'lat')::DOUBLE PRECISION,
                (v_staging->>'lng')::DOUBLE PRECISION
            );
        END LOOP;
        v_completion_pct := v_completion_pct + 20;
    END IF;
    
    -- Add team members if provided
    IF array_length(p_member_ids, 1) > 0 THEN
        FOR v_member_id IN SELECT unnest(p_member_ids)
        LOOP
            INSERT INTO public.operation_members (operation_id, user_id, joined_at)
            VALUES (v_operation_id, v_member_id, NOW());
        END LOOP;
        v_completion_pct := v_completion_pct + 20;
    END IF;
    
    -- Basic info counts for 30%
    IF p_name IS NOT NULL AND p_name <> '' THEN
        v_completion_pct := v_completion_pct + 30;
    END IF;
    
    -- Add creator as member
    INSERT INTO public.operation_members (operation_id, user_id, joined_at)
    VALUES (v_operation_id, p_user_id, NOW())
    ON CONFLICT DO NOTHING;
    
    -- Create draft metadata
    INSERT INTO public.operation_drafts (operation_id, created_by_user_id, completion_percentage)
    VALUES (v_operation_id, p_user_id, LEAST(v_completion_pct, 100));
    
    RETURN v_operation_id;
END;
$$;

-- Step 4: Create RPC function to convert draft to active operation
CREATE OR REPLACE FUNCTION public.rpc_activate_draft_operation(
    p_operation_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update operation state
    UPDATE public.operations
    SET is_draft = false, state = 'active', updated_at = NOW()
    WHERE id = p_operation_id AND is_draft = true;
    
    -- Remove draft metadata
    DELETE FROM public.operation_drafts WHERE operation_id = p_operation_id;
    
    -- Add system message
    INSERT INTO public.op_messages (operation_id, sender_user_id, body_text, media_type)
    VALUES (
        p_operation_id,
        (SELECT created_by_user_id FROM public.operations WHERE id = p_operation_id),
        '✅ Operation activated from draft',
        'text'
    );
END;
$$;

-- Step 5: Create RPC function to update draft
CREATE OR REPLACE FUNCTION public.rpc_update_draft_operation(
    p_operation_id UUID,
    p_name TEXT DEFAULT NULL,
    p_incident_number TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Update operation details if provided
    UPDATE public.operations
    SET 
        name = COALESCE(p_name, name),
        incident_number = COALESCE(p_incident_number, incident_number),
        updated_at = NOW()
    WHERE id = p_operation_id AND is_draft = true;
    
    -- Update last_edited_at in draft metadata
    UPDATE public.operation_drafts
    SET last_edited_at = NOW()
    WHERE operation_id = p_operation_id;
END;
$$;

-- Step 6: Create RPC function to delete draft
CREATE OR REPLACE FUNCTION public.rpc_delete_draft_operation(
    p_operation_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Delete the operation (cascade will handle related records)
    DELETE FROM public.operations 
    WHERE id = p_operation_id AND is_draft = true;
    
    -- Draft metadata will be deleted by cascade
END;
$$;

-- Step 7: Create RPC function to get user's drafts
CREATE OR REPLACE FUNCTION public.rpc_get_user_drafts(
    p_user_id UUID
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    incident_number TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    last_edited_at TIMESTAMPTZ,
    completion_percentage INTEGER,
    target_count BIGINT,
    staging_count BIGINT,
    member_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        o.name,
        o.incident_number,
        o.created_at,
        o.updated_at,
        d.last_edited_at,
        d.completion_percentage,
        (SELECT COUNT(*) FROM public.op_targets WHERE op_targets.operation_id = o.id) AS target_count,
        (SELECT COUNT(*) FROM public.staging_points WHERE staging_points.operation_id = o.id) AS staging_count,
        (SELECT COUNT(*) FROM public.operation_members WHERE operation_members.operation_id = o.id) AS member_count
    FROM public.operations o
    JOIN public.operation_drafts d ON d.operation_id = o.id
    WHERE o.created_by_user_id = p_user_id
      AND o.is_draft = true
    ORDER BY d.last_edited_at DESC;
END;
$$;

-- Step 8: Add RLS policies for drafts
ALTER TABLE public.operation_drafts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own drafts
CREATE POLICY "Users can view own drafts"
ON public.operation_drafts
FOR SELECT
TO authenticated
USING (created_by_user_id = auth.uid());

-- Policy: Users can insert their own drafts
CREATE POLICY "Users can create own drafts"
ON public.operation_drafts
FOR INSERT
TO authenticated
WITH CHECK (created_by_user_id = auth.uid());

-- Policy: Users can update their own drafts
CREATE POLICY "Users can update own drafts"
ON public.operation_drafts
FOR UPDATE
TO authenticated
USING (created_by_user_id = auth.uid());

-- Policy: Users can delete their own drafts
CREATE POLICY "Users can delete own drafts"
ON public.operation_drafts
FOR DELETE
TO authenticated
USING (created_by_user_id = auth.uid());

-- ============================================
-- Verification Queries
-- ============================================

-- Check if is_draft column exists
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'operations'
  AND column_name = 'is_draft';

-- Check if operation_drafts table exists
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name = 'operation_drafts';

-- List all RPC functions for drafts
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%draft%'
ORDER BY routine_name;

-- ============================================
-- Success Message
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '✅ Draft support added successfully!';
    RAISE NOTICE '';
    RAISE NOTICE 'Available RPC functions:';
    RAISE NOTICE '- rpc_create_draft_operation()';
    RAISE NOTICE '- rpc_activate_draft_operation()';
    RAISE NOTICE '- rpc_update_draft_operation()';
    RAISE NOTICE '- rpc_delete_draft_operation()';
    RAISE NOTICE '- rpc_get_user_drafts()';
END $$;

