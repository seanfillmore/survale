-- ============================================================================
-- CLEANUP: Purge Assigned Locations and Add Single Assignment Constraint
-- ============================================================================
-- This script:
-- 1. Deletes all existing assigned locations
-- 2. Adds a unique constraint to ensure only one active assignment per user
-- ============================================================================

-- Step 1: Delete all existing assigned locations
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.assigned_locations;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % assigned locations', deleted_count;
END $$;

-- Step 2: Add a unique partial index to prevent multiple active assignments per user
-- This allows a user to have only ONE active assignment at a time
-- (Cancelled/completed assignments don't count toward this limit)
DROP INDEX IF EXISTS idx_one_active_assignment_per_user;

CREATE UNIQUE INDEX idx_one_active_assignment_per_user 
ON public.assigned_locations(assigned_to_user_id)
WHERE status NOT IN ('cancelled', 'completed');

COMMENT ON INDEX idx_one_active_assignment_per_user IS 
'Ensures each user can have only one active assignment at a time. Cancelled and completed assignments do not count.';

-- Step 3: Verify the cleanup
SELECT 
    COUNT(*) as total_assignments,
    COUNT(DISTINCT assigned_to_user_id) as unique_users
FROM public.assigned_locations;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Cleanup complete!';
    RAISE NOTICE '✅ Constraint added: Users can only have ONE active assignment at a time';
    RAISE NOTICE '   (Active = not cancelled or completed)';
END $$;

