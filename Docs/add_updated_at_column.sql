-- Add updated_at and is_draft columns to operations table
-- Run this in your Supabase SQL Editor

-- Add updated_at column if it doesn't exist
ALTER TABLE public.operations 
ADD COLUMN IF NOT EXISTS updated_at timestamptz;

-- Add is_draft column if it doesn't exist
ALTER TABLE public.operations 
ADD COLUMN IF NOT EXISTS is_draft boolean NOT NULL DEFAULT false;

-- Create a trigger to automatically update updated_at on row updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop the trigger if it exists (to avoid errors on re-run)
DROP TRIGGER IF EXISTS update_operations_updated_at ON public.operations;

-- Create the trigger
CREATE TRIGGER update_operations_updated_at
    BEFORE UPDATE ON public.operations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Set updated_at to created_at for existing rows where updated_at is null
UPDATE public.operations
SET updated_at = created_at
WHERE updated_at IS NULL;

-- Create index for draft operations for better performance
CREATE INDEX IF NOT EXISTS idx_operations_is_draft ON public.operations(is_draft, case_agent_id)
WHERE is_draft = true;

COMMENT ON COLUMN public.operations.updated_at IS 'Timestamp of last update to this operation';
COMMENT ON COLUMN public.operations.is_draft IS 'True if operation is saved as draft, false if active/ended';

