-- Create join_requests table for operation join requests

CREATE TABLE IF NOT EXISTS public.join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES public.operations(id) ON DELETE CASCADE,
    requester_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    responded_at TIMESTAMPTZ,
    responded_by UUID REFERENCES auth.users(id),
    
    -- Prevent duplicate pending requests
    UNIQUE(operation_id, requester_user_id, status)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_join_requests_operation 
ON public.join_requests(operation_id, status);

CREATE INDEX IF NOT EXISTS idx_join_requests_requester 
ON public.join_requests(requester_user_id, status);

-- Enable RLS
ALTER TABLE public.join_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view join requests for operations they're members of (case agents)
CREATE POLICY "Members can view join requests for their operations"
ON public.join_requests
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM operation_members om
        WHERE om.operation_id = join_requests.operation_id
        AND om.user_id = auth.uid()
        AND om.left_at IS NULL
    )
);

-- Policy: Users can create join requests for operations they're not in
CREATE POLICY "Users can create join requests"
ON public.join_requests
FOR INSERT
WITH CHECK (
    requester_user_id = auth.uid()
    AND NOT EXISTS (
        SELECT 1 FROM operation_members om
        WHERE om.operation_id = join_requests.operation_id
        AND om.user_id = auth.uid()
        AND om.left_at IS NULL
    )
);

-- Policy: Users can view their own join requests
CREATE POLICY "Users can view their own join requests"
ON public.join_requests
FOR SELECT
USING (requester_user_id = auth.uid());

-- Policy: Case agents can update join requests (approve/reject)
CREATE POLICY "Case agents can update join requests"
ON public.join_requests
FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM operations o
        WHERE o.id = join_requests.operation_id
        AND o.case_agent_id = auth.uid()
    )
);

-- Grant permissions
GRANT SELECT, INSERT ON public.join_requests TO authenticated;
GRANT UPDATE ON public.join_requests TO authenticated;

-- Verify table
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'join_requests'
ORDER BY ordinal_position;

