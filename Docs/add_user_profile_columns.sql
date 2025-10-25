-- ============================================
-- Add User Profile Columns
-- ============================================
-- Run this to add the new user profile fields
-- for first name, last name, callsign, phone, 
-- and vehicle information
-- ============================================

-- Add new columns to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS first_name TEXT,
ADD COLUMN IF NOT EXISTS last_name TEXT,
ADD COLUMN IF NOT EXISTS callsign TEXT,
ADD COLUMN IF NOT EXISTS phone_number TEXT,
ADD COLUMN IF NOT EXISTS vehicle_color TEXT;

-- Note: full_name and vehicle_type should already exist
-- If they don't, add them too:
ALTER TABLE users
ADD COLUMN IF NOT EXISTS full_name TEXT,
ADD COLUMN IF NOT EXISTS vehicle_type TEXT;

-- ============================================
-- Verification
-- ============================================

-- Check the users table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'users'
ORDER BY ordinal_position;

-- Show sample data (will be empty for new columns)
SELECT 
    id,
    email,
    first_name,
    last_name,
    full_name,
    callsign,
    phone_number,
    vehicle_type,
    vehicle_color
FROM users
LIMIT 5;


