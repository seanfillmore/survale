# Quick SQL Fix - GROUP BY Error ✅

## Problem
```
❌ Failed to load operations: PostgrestError(...)
message: "column \"o.created_at\" must appear in the GROUP BY clause or be used in an aggregate function"
```

## Root Cause
When using aggregate functions like `json_agg()`, the `ORDER BY` clause was outside the aggregation, causing PostgreSQL to require a `GROUP BY`.

## Solution
Move `ORDER BY` **inside** the `json_agg()` function:

### ❌ Before (WRONG):
```sql
SELECT json_agg(json_build_object(...))
FROM operations o
WHERE ...
ORDER BY o.created_at DESC;  -- ❌ Outside aggregation
```

### ✅ After (CORRECT):
```sql
SELECT json_agg(
    json_build_object(...) 
    ORDER BY o.created_at DESC  -- ✅ Inside json_agg()
)
FROM operations o
WHERE ...;
```

## Action Required

1. **Re-run SQL script** in Supabase SQL Editor:
   ```
   Docs/simple_target_rpc.sql
   ```

2. **Rebuild app:**
   ```bash
   Cmd+Shift+K, Cmd+B, Cmd+R
   ```

3. **Test:**
   - Operations should now load
   - Ordered by creation date (newest first)

## Expected Result

Console output:
```
🔄 Loading operations for user: [uuid]
🔄 Loaded 3 operations from database
  ✅ Loaded: Operation C (draft)
  ✅ Loaded: Operation B (active)
  ✅ Loaded: Operation A (ended)
✅ Loaded 3 operations
```

Operations list will show newest operations at the top! ✅

