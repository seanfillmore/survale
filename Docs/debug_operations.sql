-- Debug: Check what data is being returned for operations

-- 1. Check raw operations data
SELECT 
    id,
    name,
    incident_number,
    status,
    created_at,
    started_at,
    ended_at,
    case_agent_id,
    team_id,
    agency_id
FROM operations
WHERE case_agent_id = auth.uid()
ORDER BY created_at DESC
LIMIT 5;

-- 2. Test the RPC function directly
SELECT * FROM rpc_get_user_operations();

-- 3. Check data types
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'operations'
ORDER BY ordinal_position;

-- 4. Check for NULL values that might cause issues
SELECT 
    COUNT(*) as total_operations,
    COUNT(id) as has_id,
    COUNT(case_agent_id) as has_case_agent_id,
    COUNT(team_id) as has_team_id,
    COUNT(agency_id) as has_agency_id,
    COUNT(created_at) as has_created_at
FROM operations
WHERE case_agent_id = auth.uid();

-- Expected output will show if any required fields are NULL

