-- Fix ambiguous column reference in rpc_add_operation_members (VERSION 3)
-- DROP and recreate with p_ parameter prefix

-- Step 1: Drop the existing function
DROP FUNCTION IF EXISTS public.rpc_add_operation_members(UUID, UUID[]);

-- Step 2: Create the function with p_ parameter prefix
CREATE OR REPLACE FUNCTION public.rpc_add_operation_members(
    p_operation_id UUID,
    p_member_user_ids UUID[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_member_id UUID;
    v_added_count INT := 0;
BEGIN
    -- Verify operation exists (fully qualified)
    IF NOT EXISTS (
        SELECT 1 
        FROM public.operations 
        WHERE operations.id = p_operation_id
    ) THEN
        RAISE EXCEPTION 'Operation not found';
    END IF;
    
    -- Loop through member IDs and add them
    FOREACH v_member_id IN ARRAY p_member_user_ids
    LOOP
        -- Check if user exists (fully qualified)
        IF NOT EXISTS (
            SELECT 1 
            FROM public.users 
            WHERE users.id = v_member_id
        ) THEN
            RAISE WARNING 'User % does not exist, skipping', v_member_id;
            CONTINUE;
        END IF;
        
        -- Check if already a member (fully qualified)
        IF EXISTS (
            SELECT 1 
            FROM public.operation_members
            WHERE operation_members.operation_id = p_operation_id
            AND operation_members.user_id = v_member_id 
            AND operation_members.left_at IS NULL
        ) THEN
            RAISE WARNING 'User % is already a member, skipping', v_member_id;
            CONTINUE;
        END IF;
        
        -- Remove user from any other active operation (fully qualified)
        UPDATE public.operation_members
        SET left_at = NOW()
        WHERE operation_members.user_id = v_member_id 
        AND operation_members.left_at IS NULL
        AND operation_members.operation_id != p_operation_id;
        
        -- Add user to this operation (fully qualified)
        INSERT INTO public.operation_members (operation_id, user_id, role, joined_at)
        VALUES (p_operation_id, v_member_id, 'member', NOW())
        ON CONFLICT (operation_id, user_id) 
        DO UPDATE SET 
            left_at = NULL,
            joined_at = NOW();
        
        v_added_count := v_added_count + 1;
    END LOOP;
    
    -- Post system message if members were added (fully qualified)
    IF v_added_count > 0 THEN
        INSERT INTO public.op_messages (operation_id, sender_user_id, body_text, media_type)
        VALUES (
            p_operation_id,
            auth.uid(),
            format('✅ %s team member%s added to operation', 
                v_added_count::TEXT, 
                CASE WHEN v_added_count > 1 THEN 's' ELSE '' END
            ),
            'text'
        );
        -- Note: created_at will be set automatically by DEFAULT NOW()
        -- Using 'text' media_type since enum doesn't include 'system'
    END IF;
    
    RETURN json_build_object('added_count', v_added_count);
END;
$$;

-- Step 3: Grant execute permission
GRANT EXECUTE ON FUNCTION public.rpc_add_operation_members(UUID, UUID[]) TO authenticated;

-- Verify the function was created
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'rpc_add_operation_members';

-- Test the function (replace with your actual IDs)
-- SELECT rpc_add_operation_members(
--     'YOUR-OPERATION-ID-HERE'::UUID,
--     ARRAY['USER-ID-1'::UUID, 'USER-ID-2'::UUID]::UUID[]
-- );

