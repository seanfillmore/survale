# Database Column Mapping - App vs Database

## 🔍 **Analysis of Your Actual Database**

Based on your Supabase schema export, here are the key differences between what the app expects and what the database has:

---

## ✅ **Tables That Match**

### **1. users** ✅
App model matches database perfectly!

| App Property | Database Column | Type | Notes |
|-------------|----------------|------|-------|
| `id` | `id` | UUID | ✅ Match |
| `email` | `email` | String | ✅ Match |
| `teamId` | `team_id` | UUID | ✅ Match |
| `agencyId` | `agency_id` | UUID | ✅ Match |
| `callsign` | `callsign` | String? | ✅ Match |
| `vehicleType` | `vehicle_type` | String | ✅ Match |
| `vehicleColor` | `vehicle_color` | String | ✅ Match |

---

## ❌ **Tables That Need Updates**

### **2. operations** ❌

| App Property | App Expects | Database Has | Fix Needed |
|-------------|------------|-------------|-----------|
| `createdByUserId` | `created_by_user_id` | `case_agent_id` | ✅ Use `case_agent_id` |
| `state` | `state` | `status` | ✅ Use `status` |
| `createdAt` | `created_at` | `created_at` | ✅ Match |
| `startsAt` | `starts_at` | `started_at` | ✅ Use `started_at` |
| `endsAt` | `ends_at` | `ended_at` | ✅ Use `ended_at` |

**Database has but app doesn't:**
- `join_code` - Missing from database! (App generates this)

---

### **3. locations_stream** ❌

| App Property | App Expects | Database Has | Fix Needed |
|-------------|------------|-------------|-----------|
| `timestamp` | `timestamp` | `ts` | ✅ Use `ts` |
| `latitude` | `latitude` | `lat` | ✅ Use `lat` |
| `longitude` | `longitude` | `lon` | ✅ Use `lon` |
| `accuracy` | `accuracy` | `accuracy_m` | ✅ Use `accuracy_m` |
| `speed` | `speed` | `speed_mps` | ✅ Use `speed_mps` |
| `heading` | `heading` | `heading_deg` | ✅ Use `heading_deg` |

---

### **4. op_messages** ❌

| App Property | App Expects | Database Has | Fix Needed |
|-------------|------------|-------------|-----------|
| `userId` | `user_id` | `sender_user_id` | ✅ Use `sender_user_id` |
| `content` | `content` | `body_text` | ✅ Use `body_text` |
| `operationId` | `operation_id` | `operation_id` | ✅ Match |

---

### **5. targets** ⚠️

**Database Structure:**
- Main `targets` table with `type` field (enum: person/vehicle/location)
- Separate tables: `target_person`, `target_vehicle`, `target_location`
- Photos in separate `target_photos` table

**App Structure:**
- Single `OpTarget` model with all fields
- Local `OpTargetImage` for photos

**This is a bigger refactor** - the database uses polymorphic tables.

---

## 🔧 **Required Fixes**

### **Priority 1: Fix Core Models (30 minutes)**

Update these files to match your database:

1. **`Operation.swift`** - Update `Operation` struct CodingKeys
2. **`Operation.swift`** - Update `LocationPoint` struct CodingKeys
3. **`SupabaseAuthService.swift`** - Update `ChatMessage` CodingKeys
4. **`SupabaseRPCService.swift`** - Update RPC parameter names
5. **`LocationServices.swift`** - Update location publishing field names

### **Priority 2: Add Missing Database Column**

The database is missing `join_code` on `operations` table:

```sql
ALTER TABLE operations ADD COLUMN join_code TEXT;
CREATE UNIQUE INDEX operations_join_code_key ON operations(join_code);
```

Or remove join code logic from the app (if you're using invites instead).

---

## 📊 **Full Column Reference**

### **operations table**
```
id                  uuid (PK)
agency_id           uuid → agencies(id)
team_id             uuid → teams(id)
case_agent_id       uuid → users(id)      ← Use this instead of created_by_user_id
incident_number     text
name                text
status              enum (draft/active/ended) ← Use this instead of state
created_at          timestamptz
started_at          timestamptz           ← Use this instead of starts_at
ended_at            timestamptz           ← Use this instead of ends_at
```

### **locations_stream table**
```
id              bigint (PK)
operation_id    uuid → operations(id)
user_id         uuid → users(id)
ts              timestamptz               ← Use this instead of timestamp
lat             double                    ← Use this instead of latitude
lon             double                    ← Use this instead of longitude
accuracy_m      double                    ← Use this instead of accuracy
speed_mps       double                    ← Use this instead of speed
heading_deg     double                    ← Use this instead of heading
```

### **op_messages table**
```
id                  uuid (PK)
operation_id        uuid → operations(id)
sender_user_id      uuid → users(id)      ← Use this instead of user_id
body_text           text                  ← Use this instead of content
media_path          text
media_type          enum (text/photo/video)
created_at          timestamptz
```

---

## 🎯 **Next Steps**

I'll now update the app code to match your database schema:

1. ✅ Update `Operation` model CodingKeys
2. ✅ Update `LocationPoint` model CodingKeys  
3. ✅ Update `ChatMessage` model CodingKeys
4. ✅ Update RPC service to use correct column names
5. ✅ Update Realtime filters to use correct column names
6. ✅ Test database connection

This will make your app work with your existing database! 🚀

