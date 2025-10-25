# Staging Points - Coordinates Fix

## Problem
The `staging_areas` table stores coordinates (`latitude`, `longitude`) not addresses. This is correct for real-time mapping!

## Solution
Updated the app to geocode addresses to coordinates before saving.

## What Changed

### 1. SQL (`create_target_rpc_functions.sql`)
- `rpc_create_staging_point` now takes `latitude` and `longitude` instead of `address`
- `rpc_get_operation_targets` returns `latitude` and `longitude`

### 2. iOS (`AddressSearchField.swift`)
- Now captures coordinates when user selects an address
- Added `@Binding var latitude: Double?` and `@Binding var longitude: Double?`
- Automatically geocodes the selected address using MapKit

### 3. iOS (`CreateOperationView.swift` - StagingEditor)
- Added `@State private var latitude: Double?` and `@State private var longitude: Double?`
- Button is disabled until address is geocoded (has coordinates)
- Coordinates automatically populate when user selects an address from the dropdown

### 4. iOS (`OperationStore.swift`)
- Only saves staging points that have valid coordinates
- Logs warning if coordinates are missing

### 5. iOS (`SupabaseRPCService.swift`)
- `createStagingPoint` now sends `latitude` and `longitude`
- `getOperationTargets` parses coordinates from database

## How It Works

1. **User types address** → MapKit suggests addresses
2. **User taps suggestion** → Address is geocoded to coordinates
3. **User taps "Add Staging Point"** → Saved with lat/lng to database
4. **Map loads** → Pins appear at exact coordinates

## Setup Steps

### Step 1: Re-run SQL Script
1. Open Supabase SQL Editor
2. Copy entire contents of `create_target_rpc_functions.sql`
3. Click **Run**

### Step 2: Rebuild App
```bash
# In Xcode
Cmd+B to build
Cmd+R to run
```

### Step 3: Test
1. Create a new operation
2. Add a staging point:
   - Type an address (e.g., "Times Square")
   - **Tap on a suggestion** from the dropdown
   - Label it (e.g., "Base Camp")
   - Tap "Add Staging Point"
3. Go to Map tab

Expected logs:
```
💾 Saving 0 targets and 1 staging points to database...
  ✅ Saved staging point: Base Camp
```

On map:
- GREEN pin at the staging location 🟢
- Tappable with label

## Troubleshooting

### "Skipping staging point: no coordinates"
- You didn't select an address from the dropdown
- You must **tap** a suggestion, not just type
- The coordinates are only captured when you tap a suggestion

### Still getting "column 'address' does not exist"
- Re-run the SQL script
- The function wasn't updated properly

### Staging points don't appear on map
- Check console for "📍 Loaded X targets and Y staging points"
- Verify coordinates were saved by running in Supabase SQL Editor:
```sql
SELECT * FROM staging_areas ORDER BY created_at DESC LIMIT 5;
```

## Why Coordinates?
- **Precise mapping**: GPS coordinates are exact
- **Works offline**: No need to geocode on device
- **Performance**: Direct plotting on map
- **Multi-device sync**: Everyone sees exact same location

The address is still stored for display (`label` field), but the pin location uses lat/lng!

