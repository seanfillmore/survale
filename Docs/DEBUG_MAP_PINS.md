# Debug Guide - Map Pins Not Appearing

## Rebuild and Check Console

After rebuilding, go to the Map tab and look for these log messages:

### Expected Flow:

```
🔄 Loading targets for operation: [uuid]
🔍 RPC Response: 0 targets, 1 staging
   📍 Staging from DB: HOJ at (37.7749, -122.4194)
✅ Converted 1 staging points
📍 Loaded 0 targets and 1 staging points
   Staging: HOJ at (37.7749, -122.4194)
```

## Troubleshooting Scenarios

### Scenario 1: "⚠️ No active operation ID"
**Problem**: No operation is set as active
**Fix**: 
1. Go to Ops tab
2. Create an operation OR tap an existing operation
3. Go back to Map tab

### Scenario 2: "🔍 RPC Response: 0 targets, 0 staging"
**Problem**: Database returned empty
**Causes**:
- RPC function returned empty arrays
- Operation has no targets/staging
- Wrong operation ID

**Fix**: Run in Supabase SQL Editor:
```sql
SELECT * FROM staging_areas 
WHERE operation_id = '[your-operation-id]'
ORDER BY created_at DESC;
```

### Scenario 3: Staging loaded but "NO COORDINATES"
**Problem**: `lat` or `lon` is NULL in database
**Fix**: Verify in Supabase:
```sql
SELECT id, name, lat, lon FROM staging_areas 
WHERE lat IS NULL OR lon IS NULL;
```

If NULL, the address wasn't properly geocoded when creating.

### Scenario 4: Coordinates exist but pin not visible
**Problem**: Pin might be outside map view
**Try**:
1. Zoom out on the map
2. Tap the "Locate Me" button
3. Check if coordinates are reasonable:
   - Latitude: -90 to 90
   - Longitude: -180 to 180

### Scenario 5: "📍 Loaded 1 staging points" but still not visible
**Problem**: SwiftUI rendering issue or coordinate property
**Check**: 
- Is `staging.coordinate` computed property working?
- Run this in a playground:
```swift
let staging = StagingPoint(
    id: UUID(),
    label: "Test",
    address: "",
    lat: 37.7749,
    lng: -122.4194
)
print(staging.coordinate) // Should print CLLocationCoordinate2D
```

## Quick Verification SQL

Run this in Supabase to see all your staging data:

```sql
SELECT 
    sa.id,
    sa.name,
    sa.lat,
    sa.lon,
    sa.created_at,
    o.name as operation_name,
    o.id as operation_id
FROM staging_areas sa
JOIN operations o ON sa.operation_id = o.id
ORDER BY sa.created_at DESC
LIMIT 5;
```

## Common Issues

### Map Zoomed to Wrong Location
The map might be showing San Francisco Bay Area by default.
- Your staging point might be in a different location
- Solution: Zoom out or check the coordinates

### Operation Not Active
- The map only loads targets for `appState.activeOperationID`
- Make sure you've "activated" the operation
- Check: Go to Ops tab, tap the operation

### Permissions
- If map is gray, check location permissions
- App needs "While Using" at minimum

## Still Not Working?

Send me the console output when you navigate to Map tab. It should show all the logs above and help pinpoint the issue!

