# 🗺️ Feature: Location Assignment with Turn-by-Turn Navigation

## Branch: `feature/assign-locations-navigation`

---

## 📋 Feature Overview

### **User Story**
As a Case Agent, I want to assign specific locations to team members on the map, so they can receive turn-by-turn directions to their assigned position.

### **Use Cases**
1. **Surveillance Operations**: Assign team members to specific observation posts
2. **Perimeter Security**: Position team members around a target location
3. **Search Operations**: Assign search grid sectors
4. **Entry Teams**: Assign specific entry/exit points
5. **Tactical Positioning**: Place snipers, support units, command posts

---

## 🎯 Core Features

### **1. Case Agent View (Map)**
- [ ] Long-press on map to assign location to team member
- [ ] Drag and drop assignment markers
- [ ] Visual indicators showing:
  - ✅ Team member assigned to location
  - 📍 Assigned location marker
  - 🔄 Team member en route
  - ✅ Team member arrived at assigned location
- [ ] Remove/reassign locations
- [ ] Assign multiple locations to same team member (waypoints)

### **2. Team Member View**
- [ ] Notification when assigned a location
- [ ] "Navigate" button on assignment notification
- [ ] Turn-by-turn directions using Apple Maps
- [ ] ETA display
- [ ] "I've Arrived" button
- [ ] Current distance to assigned location

### **3. Real-time Updates**
- [ ] Assignment notifications via real-time channel
- [ ] Location status updates (assigned/en route/arrived)
- [ ] Live ETA updates
- [ ] All team members see assignments on map

---

## 🏗️ Technical Architecture

### **Database Schema**

#### **New Table: `assigned_locations`**
```sql
CREATE TABLE assigned_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID NOT NULL REFERENCES operations(id) ON DELETE CASCADE,
    assigned_by_user_id UUID NOT NULL REFERENCES users(id),
    assigned_to_user_id UUID NOT NULL REFERENCES users(id),
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    label TEXT,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'assigned' CHECK (status IN ('assigned', 'en_route', 'arrived', 'cancelled')),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_assigned_locations_operation ON assigned_locations(operation_id);
CREATE INDEX idx_assigned_locations_assigned_to ON assigned_locations(assigned_to_user_id, status);
CREATE INDEX idx_assigned_locations_status ON assigned_locations(operation_id, status);
```

#### **RLS Policies**
```sql
-- Members can view assignments in their operation
CREATE POLICY "Members can view operation assignments"
ON assigned_locations FOR SELECT
USING (
    operation_id IN (
        SELECT operation_id FROM operation_members
        WHERE user_id = auth.uid() AND left_at IS NULL
    )
);

-- Only case agent can assign locations
CREATE POLICY "Case agent can assign locations"
ON assigned_locations FOR INSERT
WITH CHECK (
    operation_id IN (
        SELECT id FROM operations
        WHERE case_agent_id = auth.uid()
    )
);

-- Assigned user can update their status
CREATE POLICY "Assigned user can update status"
ON assigned_locations FOR UPDATE
USING (assigned_to_user_id = auth.uid())
WITH CHECK (assigned_to_user_id = auth.uid());
```

---

### **RPC Functions**

#### **1. Assign Location**
```sql
CREATE OR REPLACE FUNCTION rpc_assign_location(
    p_operation_id UUID,
    p_assigned_to_user_id UUID,
    p_lat DOUBLE PRECISION,
    p_lon DOUBLE PRECISION,
    p_label TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_assignment_id UUID;
    v_result JSON;
BEGIN
    -- Check if caller is case agent
    IF NOT EXISTS (
        SELECT 1 FROM operations
        WHERE id = p_operation_id
        AND case_agent_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only case agent can assign locations';
    END IF;
    
    -- Check if assignee is a member
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_id = p_operation_id
        AND user_id = p_assigned_to_user_id
        AND left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User is not a member of this operation';
    END IF;
    
    -- Create assignment
    INSERT INTO assigned_locations (
        operation_id,
        assigned_by_user_id,
        assigned_to_user_id,
        lat,
        lon,
        label,
        notes,
        status
    ) VALUES (
        p_operation_id,
        auth.uid(),
        p_assigned_to_user_id,
        p_lat,
        p_lon,
        p_label,
        p_notes,
        'assigned'
    ) RETURNING id INTO v_assignment_id;
    
    -- Return assignment
    SELECT json_build_object(
        'assignment_id', v_assignment_id,
        'success', true
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;
```

#### **2. Update Assignment Status**
```sql
CREATE OR REPLACE FUNCTION rpc_update_assignment_status(
    p_assignment_id UUID,
    p_status TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is assigned to this location
    IF NOT EXISTS (
        SELECT 1 FROM assigned_locations
        WHERE id = p_assignment_id
        AND assigned_to_user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Not authorized to update this assignment';
    END IF;
    
    -- Update status
    UPDATE assigned_locations
    SET 
        status = p_status,
        acknowledged_at = CASE WHEN p_status = 'en_route' AND acknowledged_at IS NULL 
                              THEN NOW() ELSE acknowledged_at END,
        arrived_at = CASE WHEN p_status = 'arrived' THEN NOW() ELSE arrived_at END,
        updated_at = NOW()
    WHERE id = p_assignment_id;
    
    RETURN json_build_object('success', true);
END;
$$;
```

#### **3. Get Operation Assignments**
```sql
CREATE OR REPLACE FUNCTION rpc_get_operation_assignments(
    p_operation_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user is member
    IF NOT EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_id = p_operation_id
        AND user_id = auth.uid()
        AND left_at IS NULL
    ) THEN
        RAISE EXCEPTION 'User not a member of this operation';
    END IF;
    
    RETURN (
        SELECT json_agg(
            json_build_object(
                'id', al.id,
                'assigned_to_user_id', al.assigned_to_user_id,
                'assigned_to_callsign', u.callsign,
                'assigned_to_full_name', u.full_name,
                'lat', al.lat,
                'lon', al.lon,
                'label', al.label,
                'notes', al.notes,
                'status', al.status,
                'assigned_at', al.assigned_at,
                'acknowledged_at', al.acknowledged_at,
                'arrived_at', al.arrived_at
            )
        )
        FROM assigned_locations al
        JOIN users u ON u.id = al.assigned_to_user_id
        WHERE al.operation_id = p_operation_id
        AND al.status != 'cancelled'
        ORDER BY al.assigned_at DESC
    );
END;
$$;
```

---

### **Swift Models**

#### **AssignedLocation.swift**
```swift
import Foundation

struct AssignedLocation: Identifiable, Codable {
    let id: UUID
    let operationId: UUID
    let assignedByUserId: UUID
    let assignedToUserId: UUID
    let lat: Double
    let lon: Double
    let label: String?
    let notes: String?
    var status: AssignmentStatus
    let assignedAt: Date
    var acknowledgedAt: Date?
    var arrivedAt: Date?
    
    enum AssignmentStatus: String, Codable {
        case assigned = "assigned"
        case enRoute = "en_route"
        case arrived = "arrived"
        case cancelled = "cancelled"
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case operationId = "operation_id"
        case assignedByUserId = "assigned_by_user_id"
        case assignedToUserId = "assigned_to_user_id"
        case lat, lon, label, notes, status
        case assignedAt = "assigned_at"
        case acknowledgedAt = "acknowledged_at"
        case arrivedAt = "arrived_at"
    }
}
```

---

### **Swift Service: AssignmentService.swift**

```swift
import Foundation
import CoreLocation
import MapKit

@MainActor
final class AssignmentService: ObservableObject {
    static let shared = AssignmentService()
    
    @Published var assignments: [AssignedLocation] = []
    @Published var myAssignment: AssignedLocation?
    
    private init() {}
    
    // MARK: - Case Agent Functions
    
    func assignLocation(
        operationId: UUID,
        toUserId: UUID,
        coordinate: CLLocationCoordinate2D,
        label: String?,
        notes: String?
    ) async throws {
        try await SupabaseRPCService.shared.assignLocation(
            operationId: operationId,
            assignedToUserId: toUserId,
            lat: coordinate.latitude,
            lon: coordinate.longitude,
            label: label,
            notes: notes
        )
        
        // Refresh assignments
        try await loadAssignments(for: operationId)
    }
    
    func cancelAssignment(assignmentId: UUID) async throws {
        // Update status to cancelled
        try await SupabaseRPCService.shared.updateAssignmentStatus(
            assignmentId: assignmentId,
            status: "cancelled"
        )
    }
    
    // MARK: - Team Member Functions
    
    func acknowledgeAssignment(assignmentId: UUID) async throws {
        try await SupabaseRPCService.shared.updateAssignmentStatus(
            assignmentId: assignmentId,
            status: "en_route"
        )
    }
    
    func markArrived(assignmentId: UUID) async throws {
        try await SupabaseRPCService.shared.updateAssignmentStatus(
            assignmentId: assignmentId,
            status: "arrived"
        )
    }
    
    // MARK: - Navigation
    
    func startNavigation(to assignment: AssignedLocation) {
        let placemark = MKPlacemark(coordinate: assignment.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = assignment.label ?? "Assigned Location"
        
        let launchOptions = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]
        
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    // MARK: - Data Loading
    
    func loadAssignments(for operationId: UUID) async throws {
        let loaded = try await SupabaseRPCService.shared.getOperationAssignments(
            operationId: operationId
        )
        
        assignments = loaded
        
        // Find my assignment
        if let userId = AppState.shared.currentUserID {
            myAssignment = assignments.first { 
                $0.assignedToUserId == userId && $0.status != .cancelled 
            }
        }
    }
    
    // MARK: - Distance Calculation
    
    func distance(from userLocation: CLLocation, to assignment: AssignedLocation) -> CLLocationDistance {
        let assignedLocation = CLLocation(
            latitude: assignment.lat,
            longitude: assignment.lon
        )
        return userLocation.distance(from: assignedLocation)
    }
    
    func isNearAssignment(
        userLocation: CLLocation,
        assignment: AssignedLocation,
        threshold: CLLocationDistance = 50 // 50 meters
    ) -> Bool {
        distance(from: userLocation, to: assignment) <= threshold
    }
}
```

---

## 🎨 UI Components

### **1. Assignment Sheet (Case Agent)**

```swift
struct AssignLocationSheet: View {
    let coordinate: CLLocationCoordinate2D
    let operationId: UUID
    let teamMembers: [User]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedUserId: UUID?
    @State private var label = ""
    @State private var notes = ""
    @State private var isAssigning = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Location") {
                    Text("Lat: \(coordinate.latitude, specifier: "%.6f")")
                    Text("Lon: \(coordinate.longitude, specifier: "%.6f")")
                }
                
                Section("Assign To") {
                    Picker("Team Member", selection: $selectedUserId) {
                        Text("Select member...").tag(nil as UUID?)
                        ForEach(teamMembers) { member in
                            Text(member.callsign ?? member.fullName ?? "Unknown")
                                .tag(member.id as UUID?)
                        }
                    }
                }
                
                Section("Details") {
                    TextField("Label (e.g., 'North Entry')", text: $label)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button {
                        Task {
                            await assignLocation()
                        }
                    } label: {
                        if isAssigning {
                            ProgressView()
                        } else {
                            Text("Assign Location")
                        }
                    }
                    .disabled(selectedUserId == nil || isAssigning)
                }
            }
            .navigationTitle("Assign Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func assignLocation() async {
        guard let userId = selectedUserId else { return }
        isAssigning = true
        
        do {
            try await AssignmentService.shared.assignLocation(
                operationId: operationId,
                toUserId: userId,
                coordinate: coordinate,
                label: label.isEmpty ? nil : label,
                notes: notes.isEmpty ? nil : notes
            )
            dismiss()
        } catch {
            print("Error assigning location: \(error)")
        }
        
        isAssigning = false
    }
}
```

### **2. Assignment Notification Banner**

```swift
struct AssignmentBanner: View {
    let assignment: AssignedLocation
    @State private var showingDetails = false
    
    var body: some View {
        Button {
            showingDetails = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Assignment")
                        .font(.headline)
                    Text(assignment.label ?? "Location assigned to you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingDetails) {
            AssignmentDetailView(assignment: assignment)
        }
    }
}
```

### **3. Assignment Detail View**

```swift
struct AssignmentDetailView: View {
    let assignment: AssignedLocation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService.shared
    
    var distanceText: String {
        guard let userLocation = locationService.lastLocation else {
            return "Calculating..."
        }
        let distance = AssignmentService.shared.distance(
            from: userLocation,
            to: assignment
        )
        return String(format: "%.1f km", distance / 1000)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Map preview
                Map(position: .constant(.region(
                    MKCoordinateRegion(
                        center: assignment.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                ))) {
                    Marker(assignment.label ?? "Your Assignment", coordinate: assignment.coordinate)
                        .tint(.blue)
                }
                .frame(height: 200)
                .cornerRadius(12)
                
                // Details
                VStack(spacing: 16) {
                    if let label = assignment.label {
                        Text(label)
                            .font(.title2.bold())
                    }
                    
                    if let notes = assignment.notes {
                        Text(notes)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Distance: \(distanceText)")
                    }
                    .font(.subheadline)
                }
                .padding()
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await startNavigation()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                            Text("Start Navigation")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    
                    if assignment.status == .assigned {
                        Button {
                            Task {
                                await acknowledgeAssignment()
                            }
                        } label: {
                            Text("I'm On My Way")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .cornerRadius(12)
                        }
                    }
                    
                    if assignment.status == .enRoute {
                        Button {
                            Task {
                                await markArrived()
                            }
                        } label: {
                            Text("I've Arrived")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func startNavigation() async {
        AssignmentService.shared.startNavigation(to: assignment)
        
        // Update status to en_route
        if assignment.status == .assigned {
            try? await AssignmentService.shared.acknowledgeAssignment(
                assignmentId: assignment.id
            )
        }
    }
    
    private func acknowledgeAssignment() async {
        try? await AssignmentService.shared.acknowledgeAssignment(
            assignmentId: assignment.id
        )
        dismiss()
    }
    
    private func markArrived() async {
        try? await AssignmentService.shared.markArrived(
            assignmentId: assignment.id
        )
        dismiss()
    }
}
```

---

## 📋 Implementation Checklist

### **Database (SQL)**
- [ ] Create `assigned_locations` table
- [ ] Add RLS policies
- [ ] Create indexes
- [ ] Create RPC functions:
  - [ ] `rpc_assign_location`
  - [ ] `rpc_update_assignment_status`
  - [ ] `rpc_get_operation_assignments`
  - [ ] `rpc_cancel_assignment`

### **Swift Models**
- [ ] Create `AssignedLocation` model
- [ ] Add to `OperationModels.swift`

### **Services**
- [ ] Create `AssignmentService.swift`
- [ ] Add RPC methods to `SupabaseRPCService.swift`
- [ ] Add real-time subscription for assignments

### **UI Components**
- [ ] `AssignLocationSheet.swift` - Case agent assigns
- [ ] `AssignmentBanner.swift` - Notification banner
- [ ] `AssignmentDetailView.swift` - Full assignment view
- [ ] Update `MapOperationView.swift` - Show assignment markers
- [ ] Update `MapOperationView.swift` - Long-press to assign (case agent only)

### **Integration**
- [ ] Add assignment markers to map
- [ ] Add real-time assignment notifications
- [ ] Add "My Assignment" banner when assigned
- [ ] Add status indicators (assigned/en route/arrived)
- [ ] Test turn-by-turn navigation

---

## 🧪 Testing Checklist

- [ ] Case agent can assign location
- [ ] Team member receives notification
- [ ] Team member can start navigation
- [ ] Navigation opens Apple Maps
- [ ] Status updates propagate in real-time
- [ ] Distance calculation is accurate
- [ ] "Arrived" detection works
- [ ] Multiple assignments can be active
- [ ] Assignments persist across app restart
- [ ] RLS prevents unauthorized access

---

## 📱 User Flow

### **Case Agent:**
1. Long-press on map
2. "Assign Location" sheet appears
3. Select team member
4. Enter label/notes
5. Tap "Assign"
6. See marker on map with team member name

### **Team Member:**
1. Receive notification: "New Assignment"
2. Tap banner
3. See assignment details and map
4. Tap "Start Navigation"
5. Apple Maps opens with turn-by-turn
6. Tap "I'm On My Way" (status → en_route)
7. Navigate to location
8. Tap "I've Arrived" (status → arrived)

---

**Ready to build! Start with the database schema, then models, then UI components.** 🚀

