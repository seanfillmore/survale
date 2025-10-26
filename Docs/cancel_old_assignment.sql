-- ============================================================================
-- CLEANUP: Cancel old assignment for user B8EDE013-918E-442D-81E7-A92A1DFEEC06
-- ============================================================================
-- This cancels the old assignment so only the new one remains active
-- ============================================================================

UPDATE public.assigned_locations
SET 
    status = 'cancelled',
    updated_at = NOW(),
    completed_at = NOW()
WHERE id = '74EFD8C2-1C11-4F01-B767-8F1F47F81CC8'::uuid;

-- Verify
SELECT 
    id,
    assigned_to_user_id,
    label,
    status,
    assigned_at
FROM public.assigned_locations
WHERE assigned_to_user_id = 'B8EDE013-918E-442D-81E7-A92A1DFEEC06'::uuid
ORDER BY assigned_at DESC;

