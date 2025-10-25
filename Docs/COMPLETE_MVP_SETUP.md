# Complete MVP Setup - Full Target Support

## Overview
This setup creates a fully functional MVP with:
- ✅ Person targets (name, phone)
- ✅ Vehicle targets (make, model, color, plate)
- ✅ Location targets (address with coordinates)
- ✅ Staging points (meeting locations)
- ✅ All visible on map (RED = targets, GREEN = staging)
- ✅ Shared across all operation members

## Step 1: Create Target Tables

Run `Docs/create_target_tables.sql` in **Supabase SQL Editor**:

1. Open SQL Editor
2. Copy entire file contents
3. Paste and click **Run**

Expected output:
```
table_name       | column_count
-----------------|-------------
targets          | 4
target_person    | 6
target_vehicle   | 7
target_location  | 4
✅ All target tables created successfully!
```

This creates:
- `targets` - Main table (polymorphic)
- `target_person` - Person-specific fields
- `target_vehicle` - Vehicle-specific fields
- `target_location` - Location-specific fields
- RLS policies for security
- Indexes for performance

## Step 2: Create RPC Functions

Run `Docs/create_target_rpc_functions.sql` in **Supabase SQL Editor**:

1. Copy entire file contents
2. Paste and click **Run**

Expected output:
```
routine_name                    | routine_type
--------------------------------|-------------
rpc_create_person_target        | FUNCTION
rpc_create_vehicle_target       | FUNCTION
rpc_create_location_target      | FUNCTION
rpc_create_staging_point        | FUNCTION
rpc_get_operation_targets       | FUNCTION
✅ All target/staging RPC functions created!
```

## Step 3: Rebuild and Test

### In Xcode:
1. Build (Cmd+B)
2. Run (Cmd+R)

### Create Operation:
1. **Ops Tab** → Create Operation
2. **Name**: "Test Operation"
3. **Add Targets**:
   - Person: "John Doe", phone "555-1234"
   - Vehicle: Make "Honda", Model "Civic", Color "Blue", Plate "ABC123"
   - Location: Type address, **TAP suggestion** (e.g., "Times Square New York")
4. **Add Staging**:
   - Label: "Base Camp"
   - Address: Type and **TAP suggestion** (e.g., "Central Park New York")
5. **Create & Activate**

### Expected Console Output:
```
💾 Saving 3 targets and 1 staging points to database...
  ✅ Saved target: John Doe
  ✅ Saved target: Blue Honda Civic
  ✅ Saved target: Times Square, New York 10036
  ✅ Saved staging point: Base Camp
Operation created successfully
```

### View on Map:
1. **Map Tab**
2. You should see:
   - 🔴 **3 RED pins** for targets
   - 🟢 **1 GREEN pin** for staging
   - Pins at exact coordinates from geocoding

Expected console:
```
🔄 Loading targets for operation: [uuid]
🔍 RPC Response: 3 targets, 1 staging
   📍 Staging from DB: Base Camp at (40.7829, -73.9654)
✅ Converted 1 staging points
📍 Loaded 3 targets and 1 staging points
   Staging: Base Camp at (40.7829, -73.9654)
Showing 1 staging point(s)
```

## Step 4: Multi-User Testing

### On Second Device:
1. Login with different user (same MVP team)
2. **Ops Tab** → Join operation (enter join code)
3. **Map Tab** → See all targets and staging points
4. **Both users see the same map**!

### What Each User Sees:
- ✅ All operation targets (RED pins)
- ✅ Staging point (GREEN pin)
- ✅ All team members' locations (vehicle markers)
- ✅ Real-time location updates every 3-5 seconds

## Verification Queries

### Check Target Data:
```sql
-- See all targets
SELECT 
    t.id,
    t.type,
    tp.first_name,
    tp.last_name,
    tv.make,
    tv.model,
    tv.plate,
    tl.address,
    o.name as operation_name
FROM targets t
LEFT JOIN target_person tp ON t.id = tp.target_id
LEFT JOIN target_vehicle tv ON t.id = tv.target_id
LEFT JOIN target_location tl ON t.id = tl.target_id
JOIN operations o ON t.operation_id = o.id
ORDER BY t.created_at DESC
LIMIT 10;
```

### Check Staging Points:
```sql
SELECT 
    sa.name,
    sa.lat,
    sa.lon,
    o.name as operation_name
FROM staging_areas sa
JOIN operations o ON sa.operation_id = o.id
ORDER BY sa.created_at DESC
LIMIT 5;
```

## Troubleshooting

### "column tp.first_name does not exist"
- Step 1 wasn't completed
- Run `create_target_tables.sql` first

### Targets save but don't appear on map
- Location targets need coordinates
- **You must TAP address suggestions** to capture lat/lng
- Check console for coordinate values

### "User not a member of this operation"
- RLS policies require operation membership
- User must be in `operation_members` table
- This happens automatically when creating or joining

### Staging points work but targets don't
- Check if targets have coordinates (location type only)
- Person/vehicle targets show at their last known location OR staging point
- For MVP, location targets are the main visual markers

## Map Display Summary

### RED Pins 🔴 (Targets):
- Person targets
- Vehicle targets  
- Location targets (if have coordinates)

### GREEN Pins 🟢 (Staging):
- Meeting points
- Rally locations
- Safe houses

### Blue Vehicle Markers 🚗:
- Real-time team member locations
- Updates every 3-5 seconds
- Shows heading/direction

## Ready for MVP!

Once you see:
- ✅ Targets saving to database
- ✅ RED and GREEN pins on map
- ✅ Multi-user access working
- ✅ Real-time location tracking

You're ready for your 8-10 person test group!

## Next Steps After MVP

1. Add target photos
2. Implement chat messages
3. Add replay functionality
4. Export to PDF
5. Advanced filtering/search

But for now, focus on the core: **shared map with targets and real-time tracking**!

