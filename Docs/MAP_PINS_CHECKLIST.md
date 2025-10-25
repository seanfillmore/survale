# Map Pins Troubleshooting Checklist

## Before Starting
1. ✅ SQL script `create_target_rpc_functions.sql` has been run in Supabase
2. ✅ App has been rebuilt (Cmd+B)
3. ✅ Staging point was saved (you saw "✅ Saved staging point: HOJ")

## Step-by-Step Verification

### Step 1: Verify Database
Run this in **Supabase SQL Editor**:

```sql
-- Check if staging point exists
SELECT 
    sa.id,
    sa.name,
    sa.lat,
    sa.lon,
    sa.operation_id,
    o.name as op_name
FROM staging_areas sa
JOIN operations o ON sa.operation_id = o.id
ORDER BY sa.created_at DESC
LIMIT 5;
```

**Expected**: You should see your "HOJ" staging point with valid lat/lon values.

**If empty**: Staging point didn't save to database
**If lat/lon are NULL**: Address wasn't geocoded properly

### Step 2: Check Active Operation

In the app, go to **Ops tab**:
- Do you see your operation listed?
- Tap on the operation to make it active
- You should see operation details

### Step 3: Go to Map Tab

**What do you see?**

#### Option A: "No active operation" message
**Problem**: Operation isn't set as active in `AppState`
**Fix**: Go back to Ops tab, tap the operation again

#### Option B: Map is showing but empty (no pins)
**Good**: Map is loading
**Check Console**: Look for these logs:
```
🔄 Loading targets for operation: [uuid]
🔍 RPC Response: X targets, Y staging
📍 Staging from DB: HOJ at (lat, lon)
```

#### Option C: Map shows "Showing 1 staging point(s)" at top
**Great**: Staging point is loaded!
**Problem**: Pin might be outside view
**Try**:
1. Zoom out (pinch gesture)
2. Pan around
3. Tap "Locate Me" button

#### Option D: Permission card showing
**Problem**: Location permission not granted
**Fix**: Grant "While Using App" permission

### Step 4: Console Output Analysis

**After going to Map tab**, check console for:

#### Scenario 1: No logs at all
**Problem**: Map view isn't loading or app crashed
**Check**: Is the app still running? Any crash logs?

#### Scenario 2: "⚠️ No active operation ID"
**Problem**: `appState.activeOperationID` is nil
**Fix**: 
```swift
// In OperationsView, when creating operation:
appState.activeOperationID = operation.id
appState.activeOperation = operation
```

#### Scenario 3: "❌ Failed to load targets: [error]"
**Problem**: RPC function error
**Check**: Error message details

#### Scenario 4: "🔍 RPC Response: 0 targets, 0 staging"
**Problem**: Database query returned empty
**Fix**: Verify Step 1 - check database directly

#### Scenario 5: "📍 Loaded 1 staging points" but "NO COORDINATES"
**Problem**: `staging.lat` or `staging.lng` is nil
**Verify**: 
```sql
SELECT lat, lon FROM staging_areas WHERE name = 'HOJ';
```

#### Scenario 6: All logs show success
```
🔄 Loading targets for operation: [uuid]
🔍 RPC Response: 0 targets, 1 staging
📍 Staging from DB: HOJ at (37.7749, -122.4194)
✅ Converted 1 staging points
📍 Loaded 0 targets and 1 staging points
   Staging: HOJ at (37.7749, -122.4194)
```
**Status**: Data is loaded correctly!
**Problem**: Pin is likely outside visible map area
**Solutions**:
- Zoom out significantly
- Check if coordinates match your location
- If coordinates are in California but you're in New York, pan to California

### Step 5: Manual Verification

If still not working, manually verify the coordinate:

1. Copy the lat/lon from console
2. Go to Google Maps: `https://www.google.com/maps?q=37.7749,-122.4194`
3. Verify it's a real location
4. In the app, pan the map to that location
5. Look for the GREEN pin

## Common Issues & Solutions

### Issue: Map centered on wrong location
**Cause**: Default map center is San Francisco (37.3349, -122.0090)
**Solution**: 
- Zoom out
- Or update initial region in MapOperationView

### Issue: Pin color is wrong
**Check**: Staging points should be GREEN, targets should be RED
**Verify**: In MapOperationView, line ~102:
```swift
.foregroundStyle(.green)  // For staging
```

### Issue: Map is gray/blank
**Cause**: MapKit not loading
**Check**: Internet connection, simulator vs device

### Issue: "Showing 1 staging point(s)" but no pin
**Cause**: SwiftUI rendering issue or coordinate is invalid
**Try**: 
- Force close and reopen app
- Check if `staging.coordinate` returns nil
- Add breakpoint in `ForEach(stagingPoints)`

## Quick Debug Commands

### In Xcode Debug Console:
```
po appState.activeOperationID
po stagingPoints.count
po stagingPoints.first?.coordinate
```

### In Supabase SQL Editor:
```sql
-- Get operation ID
SELECT id, name FROM operations ORDER BY created_at DESC LIMIT 1;

-- Check staging for that operation
SELECT * FROM staging_areas WHERE operation_id = '[paste-id-here]';
```

## Still Stuck?

Share with me:
1. ✅ Full console output from going to Map tab
2. ✅ SQL query results from Step 1
3. ✅ Screenshot of what you see on Map tab
4. ✅ Do you see "Showing X staging point(s)" text?

This will help pinpoint the exact issue!

