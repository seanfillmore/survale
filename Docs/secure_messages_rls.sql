-- Secure op_messages with Row Level Security (RLS)
-- This ensures users can only see messages from operations they're members of

-- Enable RLS on op_messages table
ALTER TABLE op_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only SELECT messages from operations they're active members of
CREATE POLICY "Users can view messages from their operations"
ON op_messages
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = op_messages.operation_id
        AND operation_members.user_id = auth.uid()
        AND operation_members.left_at IS NULL  -- Only active members
    )
);

-- Policy: Users can only INSERT messages to operations they're active members of
CREATE POLICY "Users can send messages to their operations"
ON op_messages
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_members.operation_id = op_messages.operation_id
        AND operation_members.user_id = auth.uid()
        AND operation_members.left_at IS NULL  -- Only active members
    )
);

-- Policy: Users can UPDATE their own messages
CREATE POLICY "Users can update their own messages"
ON op_messages
FOR UPDATE
USING (sender_user_id = auth.uid());

-- Policy: Users can DELETE their own messages
CREATE POLICY "Users can delete their own messages"
ON op_messages
FOR DELETE
USING (sender_user_id = auth.uid());

-- Verify policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'op_messages';

