-- ============================================
-- FIX TARGETS TABLE - Add created_by column
-- ============================================
-- Run this if you already created the targets table without created_by

-- Check if column exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'targets' 
        AND column_name = 'created_by'
    ) THEN
        -- Add the column
        ALTER TABLE public.targets 
        ADD COLUMN created_by UUID REFERENCES auth.users(id);
        
        RAISE NOTICE '✅ Added created_by column to targets table';
    ELSE
        RAISE NOTICE '✅ created_by column already exists';
    END IF;
END $$;

-- Verify the column exists
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'targets'
ORDER BY ordinal_position;

