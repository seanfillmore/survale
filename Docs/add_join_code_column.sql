-- Add join_code column to operations table
-- This column is needed for the "Join Operation" feature where users can join using a 6-character code

ALTER TABLE operations 
ADD COLUMN IF NOT EXISTS join_code TEXT;

-- Add unique constraint to ensure no duplicate codes
CREATE UNIQUE INDEX IF NOT EXISTS operations_join_code_key 
ON operations(join_code) 
WHERE join_code IS NOT NULL;

-- Add a trigger to auto-generate join codes for new operations
CREATE OR REPLACE FUNCTION generate_join_code()
RETURNS TRIGGER AS $$
BEGIN
    -- Generate a 6-character uppercase code from UUID
    NEW.join_code := UPPER(SUBSTRING(gen_random_uuid()::text, 1, 6));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER operations_join_code_trigger
BEFORE INSERT ON operations
FOR EACH ROW
WHEN (NEW.join_code IS NULL)
EXECUTE FUNCTION generate_join_code();

-- Backfill existing operations with join codes
UPDATE operations 
SET join_code = UPPER(SUBSTRING(gen_random_uuid()::text, 1, 6))
WHERE join_code IS NULL;

