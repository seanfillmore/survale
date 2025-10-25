-- ============================================
-- CREATE TARGET TABLES FOR MVP
-- ============================================
-- This creates the polymorphic target structure

-- 1. Main targets table
CREATE TABLE IF NOT EXISTS public.targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('person', 'vehicle', 'location')),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Person target details
CREATE TABLE IF NOT EXISTS public.target_person (
    target_id UUID PRIMARY KEY REFERENCES targets(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    last_name TEXT,
    phone_number TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Vehicle target details
CREATE TABLE IF NOT EXISTS public.target_vehicle (
    target_id UUID PRIMARY KEY REFERENCES targets(id) ON DELETE CASCADE,
    make TEXT,
    model TEXT,
    color TEXT,
    plate TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Location target details
CREATE TABLE IF NOT EXISTS public.target_location (
    target_id UUID PRIMARY KEY REFERENCES targets(id) ON DELETE CASCADE,
    address TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE target_person ENABLE ROW LEVEL SECURITY;
ALTER TABLE target_vehicle ENABLE ROW LEVEL SECURITY;
ALTER TABLE target_location ENABLE ROW LEVEL SECURITY;

-- ============================================
-- CREATE RLS POLICIES
-- ============================================

-- Targets: Only operation members can view/edit
DROP POLICY IF EXISTS "Operation members can view targets" ON targets;
CREATE POLICY "Operation members can view targets"
    ON targets FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM operation_members
            WHERE operation_members.operation_id = targets.operation_id
            AND operation_members.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Operation members can insert targets" ON targets;
CREATE POLICY "Operation members can insert targets"
    ON targets FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM operation_members
            WHERE operation_members.operation_id = targets.operation_id
            AND operation_members.user_id = auth.uid()
        )
    );

-- Target Person: Same as targets
DROP POLICY IF EXISTS "Operation members can view person targets" ON target_person;
CREATE POLICY "Operation members can view person targets"
    ON target_person FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN operation_members om ON t.operation_id = om.operation_id
            WHERE t.id = target_person.target_id
            AND om.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Operation members can insert person targets" ON target_person;
CREATE POLICY "Operation members can insert person targets"
    ON target_person FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN operation_members om ON t.operation_id = om.operation_id
            WHERE t.id = target_person.target_id
            AND om.user_id = auth.uid()
        )
    );

-- Target Vehicle: Same as targets
DROP POLICY IF EXISTS "Operation members can view vehicle targets" ON target_vehicle;
CREATE POLICY "Operation members can view vehicle targets"
    ON target_vehicle FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN operation_members om ON t.operation_id = om.operation_id
            WHERE t.id = target_vehicle.target_id
            AND om.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Operation members can insert vehicle targets" ON target_vehicle;
CREATE POLICY "Operation members can insert vehicle targets"
    ON target_vehicle FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN operation_members om ON t.operation_id = om.operation_id
            WHERE t.id = target_vehicle.target_id
            AND om.user_id = auth.uid()
        )
    );

-- Target Location: Same as targets
DROP POLICY IF EXISTS "Operation members can view location targets" ON target_location;
CREATE POLICY "Operation members can view location targets"
    ON target_location FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN operation_members om ON t.operation_id = om.operation_id
            WHERE t.id = target_location.target_id
            AND om.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Operation members can insert location targets" ON target_location;
CREATE POLICY "Operation members can insert location targets"
    ON target_location FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN operation_members om ON t.operation_id = om.operation_id
            WHERE t.id = target_location.target_id
            AND om.user_id = auth.uid()
        )
    );

-- ============================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX IF NOT EXISTS idx_targets_operation_id ON targets(operation_id);
CREATE INDEX IF NOT EXISTS idx_targets_type ON targets(type);
CREATE INDEX IF NOT EXISTS idx_target_person_target_id ON target_person(target_id);
CREATE INDEX IF NOT EXISTS idx_target_vehicle_target_id ON target_vehicle(target_id);
CREATE INDEX IF NOT EXISTS idx_target_location_target_id ON target_location(target_id);

-- ============================================
-- VERIFY TABLES CREATED
-- ============================================

SELECT 
    'targets' as table_name,
    COUNT(*) as column_count
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'targets'
UNION ALL
SELECT 
    'target_person',
    COUNT(*)
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_person'
UNION ALL
SELECT 
    'target_vehicle',
    COUNT(*)
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_vehicle'
UNION ALL
SELECT 
    'target_location',
    COUNT(*)
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'target_location';

SELECT '✅ All target tables created successfully!' as status;

