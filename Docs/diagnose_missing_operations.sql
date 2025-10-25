-- Diagnose why operations aren't showing up

-- 1. Check what operations exist
SELECT 
    o.id,
    o.name,
    o.status,
    o.created_at,
    u.email as created_by
FROM operations o
LEFT JOIN auth.users u ON o.case_agent_id = u.id
ORDER BY o.created_at DESC
LIMIT 10;

-- 2. Check your operation memberships
SELECT 
    om.operation_id,
    o.name as operation_name,
    om.role,
    om.joined_at,
    om.left_at,
    u.email
FROM operation_members om
JOIN operations o ON om.operation_id = o.id
JOIN auth.users u ON om.user_id = u.id
WHERE om.user_id = auth.uid()
ORDER BY om.joined_at DESC;

-- 3. Check what the RPC function returns
SELECT * FROM rpc_get_all_active_operations();

-- 4. Quick fix: Make all operations active
-- UNCOMMENT TO RUN:
-- UPDATE operations SET status = 'active' WHERE status = 'draft';

-- 5. Quick fix: Ensure you're a member of your operations
-- UNCOMMENT TO RUN:
-- INSERT INTO operation_members (operation_id, user_id, role, joined_at)
-- SELECT id, case_agent_id, 'case_agent', created_at
-- FROM operations
-- WHERE case_agent_id = auth.uid()
-- AND id NOT IN (
--     SELECT operation_id FROM operation_members WHERE user_id = auth.uid()
-- );

