-- Fix ambiguous column reference in rpc_add_operation_members
-- This function is called when adding team members to an operation during create/edit

CREATE OR REPLACE FUNCTION public.rpc_add_operation_members(
    operation_id UUID,
    member_user_ids UUID[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_member_id UUID;
    v_added_count INT := 0;
BEGIN
    -- Verify operation exists
    IF NOT EXISTS (SELECT 1 FROM public.operations o WHERE o.id = rpc_add_operation_members.operation_id) THEN
        RAISE EXCEPTION 'Operation not found';
    END IF;
    
    -- Loop through member IDs and add them
    FOREACH v_member_id IN ARRAY member_user_ids
    LOOP
        -- Check if user exists
        IF NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_member_id) THEN
            RAISE WARNING 'User % does not exist, skipping', v_member_id;
            CONTINUE;
        END IF;
        
        -- Check if already a member
        IF EXISTS (
            SELECT 1 
            FROM public.operation_members om 
            WHERE om.operation_id = rpc_add_operation_members.operation_id 
            AND om.user_id = v_member_id 
            AND om.left_at IS NULL
        ) THEN
            RAISE WARNING 'User % is already a member, skipping', v_member_id;
            CONTINUE;
        END IF;
        
        -- Remove user from any other active operation
        UPDATE public.operation_members om
        SET left_at = NOW()
        WHERE om.user_id = v_member_id 
        AND om.left_at IS NULL
        AND om.operation_id != rpc_add_operation_members.operation_id;
        
        -- Add user to this operation
        INSERT INTO public.operation_members (operation_id, user_id, role, joined_at)
        VALUES (rpc_add_operation_members.operation_id, v_member_id, 'member', NOW())
        ON CONFLICT (operation_id, user_id) 
        DO UPDATE SET 
            left_at = NULL,
            joined_at = NOW();
        
        v_added_count := v_added_count + 1;
    END LOOP;
    
    -- Post system message if members were added
    IF v_added_count > 0 THEN
        INSERT INTO public.op_messages (operation_id, sender_user_id, body_text, media_type, sent_at)
        VALUES (
            rpc_add_operation_members.operation_id,
            auth.uid(),
            format('%s team member%s added to operation', 
                v_added_count::TEXT, 
                CASE WHEN v_added_count > 1 THEN 's' ELSE '' END
            ),
            'system',
            NOW()
        );
    END IF;
    
    RETURN json_build_object('added_count', v_added_count);
END;
$$;

-- Test the function
-- SELECT rpc_add_operation_members(
--     'YOUR-OPERATION-ID-HERE'::UUID,
--     ARRAY['USER-ID-1'::UUID, 'USER-ID-2'::UUID]
-- );

