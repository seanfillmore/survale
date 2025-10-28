# Operation Improvements - Implementation Roadmap

## 🎯 Selected Improvements

Based on user priorities, implementing:

### **Phase 1: Operation Details Page** ✅
1. Better layout/visual design
2. Show member list directly on details

### **Phase 2: Creation Workflow** ✅
3. Save as draft functionality
4. Template system

---

## 📋 Detailed Implementation Plan

### **Task 1: Better Layout/Visual Design (Operation Details)**

#### **Changes to `ActiveOperationDetailView`:**

**A. Add Summary Header Card**
```swift
// At the top - Quick stats overview
VStack(spacing: 12) {
    // Operation title with status badge
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text(operation.name)
                .font(.title2.bold())
            
            if let incidentNumber = operation.incidentNumber {
                Text("Incident #\(incidentNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        
        Spacer()
        
        // Status badge
        StatusBadge(state: operation.state)
    }
    
    // Quick statistics
    HStack(spacing: 16) {
        StatCard(icon: "person.3.fill", value: memberCount, label: "Members", color: .blue)
        StatCard(icon: "target", value: targets.count, label: "Targets", color: .orange)
        StatCard(icon: "mappin.circle.fill", value: stagingPoints.count, label: "Staging", color: .green)
        StatCard(icon: "clock.fill", value: durationText, label: "Duration", color: .purple)
    }
}
.padding()
.background(LinearGradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
.cornerRadius(16)
.shadow(color: .black.opacity(0.05), radius: 8, y: 2)
```

**B. Improved Section Headers**
```swift
// Better visual hierarchy for sections
struct SectionHeader: View {
    let icon: String
    let title: String
    let count: Int?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue.gradient)
                .font(.title3)
            
            Text(title)
                .font(.headline)
            
            if let count = count {
                Text("(\(count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
```

**C. Enhanced Target/Staging Cards**
```swift
// More visual, card-based design
VStack(alignment: .leading, spacing: 8) {
    HStack {
        // Icon based on type
        Image(systemName: target.iconName)
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(target.color.gradient)
            .cornerRadius(10)
        
        VStack(alignment: .leading, spacing: 4) {
            Text(target.label)
                .font(.headline)
            
            Text(target.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        // Navigate arrow
        Image(systemName: "chevron.right")
            .foregroundStyle(.tertiary)
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
}
```

---

### **Task 2: Show Member List Directly on Details**

#### **Add Members Section:**

```swift
Section {
    SectionHeader(icon: "person.3.fill", title: "Team Members", count: operationMembers.count)
    
    if operationMembers.isEmpty {
        ContentUnavailableView(
            "No Team Members",
            systemImage: "person.slash",
            description: Text("Add members to collaborate on this operation")
        )
    } else {
        ForEach(operationMembers) { member in
            MemberRow(member: member, isCaseAgent: member.id == operation.createdByUserId)
        }
    }
    
    // Add member button for case agent
    if isCaseAgent {
        Button {
            showingAddMembers = true
        } label: {
            Label("Add Team Member", systemImage: "person.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}
```

**Member Row Component:**
```swift
struct MemberRow: View {
    let member: User
    let isCaseAgent: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar circle with initials
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(member.initials)
                        .font(.headline)
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.callsign ?? member.email)
                        .font(.subheadline.weight(.medium))
                    
                    if isCaseAgent {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                
                HStack(spacing: 8) {
                    // Vehicle info
                    Circle()
                        .fill(Color(hex: member.vehicleColor) ?? .gray)
                        .frame(width: 8, height: 8)
                    
                    Text(member.vehicleType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator (online/offline)
            Circle()
                .fill(member.isOnline ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}
```

---

### **Task 3: Save as Draft Functionality**

#### **Database Schema:**
```sql
-- Add draft support to operations table
ALTER TABLE operations ADD COLUMN is_draft BOOLEAN DEFAULT false;

-- Create drafts table for additional metadata
CREATE TABLE IF NOT EXISTS operation_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    operation_id UUID REFERENCES operations(id) ON DELETE CASCADE,
    created_by_user_id UUID REFERENCES users(id),
    last_edited_at TIMESTAMPTZ DEFAULT NOW(),
    completion_percentage INTEGER DEFAULT 0,
    UNIQUE(operation_id)
);
```

#### **Swift Model Update:**
```swift
extension Operation {
    var isDraft: Bool { state == .draft }
    var completionPercentage: Int {
        var completed = 0
        var total = 5 // 5 steps in creation
        
        if !name.isEmpty { completed += 1 }
        if !targets.isEmpty { completed += 1 }
        if !staging.isEmpty { completed += 1 }
        // Member selection is optional
        completed += 2 // Review auto-completes
        
        return (completed * 100) / total
    }
}
```

#### **CreateOperationView Changes:**
```swift
@State private var operationId: UUID? // Track draft ID

// Add save as draft button
Button {
    Task { await saveDraft() }
} label: {
    Label("Save Draft", systemImage: "tray.and.arrow.down")
}
.buttonStyle(.bordered)

private func saveDraft() async {
    do {
        // Create draft operation
        let draftId = try await OperationStore.shared.createDraft(
            name: name.isEmpty ? "Untitled Operation" : name,
            incidentNumber: incidentNumber,
            userId: appState.currentUserID!,
            teamId: appState.currentUser!.teamId,
            agencyId: appState.currentUser!.agencyId,
            targets: targets,
            staging: staging,
            selectedMembers: Array(selectedMemberIds)
        )
        
        print("✅ Draft saved: \(draftId)")
        
        // Show success message
        await MainActor.run {
            // Show toast or alert
            dismiss()
        }
    } catch {
        print("❌ Failed to save draft: \(error)")
    }
}
```

#### **Draft List View:**
```swift
// In OperationsView, add Drafts section
Section("Drafts") {
    if store.draftOperations.isEmpty {
        Text("No drafts")
            .foregroundStyle(.secondary)
            .font(.subheadline)
    } else {
        ForEach(store.draftOperations) { draft in
            DraftRow(draft: draft) {
                // Resume editing
                showingCreate = true
                draftToEdit = draft
            }
        }
    }
}

struct DraftRow: View {
    let draft: Operation
    let onResume: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.name)
                    .font(.headline)
                
                Text("Last edited: \(draft.updatedAt.formatted(.relative(presentation: .numeric)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Progress indicator
            CircularProgressView(progress: Double(draft.completionPercentage) / 100.0)
                .frame(width: 40, height: 40)
            
            Button("Resume", systemImage: "arrow.right.circle.fill") {
                onResume()
            }
            .buttonStyle(.bordered)
        }
    }
}
```

---

### **Task 4: Template System**

#### **Database Schema:**
```sql
-- Create templates table
CREATE TABLE IF NOT EXISTS operation_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    created_by_user_id UUID REFERENCES users(id),
    team_id UUID REFERENCES teams(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    use_count INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT false
);

-- Template targets (pre-defined targets for template)
CREATE TABLE IF NOT EXISTS template_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID REFERENCES operation_templates(id) ON DELETE CASCADE,
    kind TEXT NOT NULL,
    label TEXT NOT NULL,
    data JSONB NOT NULL
);

-- Template staging points
CREATE TABLE IF NOT EXISTS template_staging (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID REFERENCES operation_templates(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);
```

#### **Swift Models:**
```swift
struct OperationTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String?
    let createdByUserId: UUID
    let teamId: UUID
    let createdAt: Date
    var useCount: Int
    let isPublic: Bool
    
    // Pre-defined content
    var targets: [OpTarget]
    var staging: [StagingPoint]
}
```

#### **UI Implementation:**
```swift
// In CreateOperationView, add template selection
@State private var showingTemplates = false
@State private var selectedTemplate: OperationTemplate?

// Button to open template picker
Button {
    showingTemplates = true
} label: {
    Label("Use Template", systemImage: "doc.on.doc")
}
.sheet(isPresented: $showingTemplates) {
    TemplatePickerSheet { template in
        applyTemplate(template)
    }
}

private func applyTemplate(_ template: OperationTemplate) {
    name = template.name
    targets = template.targets
    staging = template.staging
    
    print("✅ Applied template: \(template.name)")
}

// Template Picker Sheet
struct TemplatePickerSheet: View {
    let onSelect: (OperationTemplate) -> Void
    @State private var templates: [OperationTemplate] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("My Templates") {
                    ForEach(templates.filter { !$0.isPublic }) { template in
                        TemplateRow(template: template) {
                            onSelect(template)
                            dismiss()
                        }
                    }
                }
                
                Section("Team Templates") {
                    ForEach(templates.filter { $0.isPublic }) { template in
                        TemplateRow(template: template) {
                            onSelect(template)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Operation Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Create Template", systemImage: "plus") {
                        // Show create template sheet
                    }
                }
            }
            .task {
                await loadTemplates()
            }
        }
    }
}

// Save current operation as template
func saveAsTemplate() async {
    // Show dialog to name template
    // Save current targets/staging as template
}
```

---

## 🚀 Implementation Order

### **Week 1: Visual Improvements**
1. ✅ Summary header card
2. ✅ Enhanced section headers
3. ✅ Better target/staging cards
4. ✅ Member list section
5. ✅ Member row component

### **Week 2: Draft System**
1. ✅ Database schema
2. ✅ Swift models
3. ✅ Save draft functionality
4. ✅ Draft list UI
5. ✅ Resume editing

### **Week 3: Template System**
1. ✅ Database schema
2. ✅ Swift models
3. ✅ Template picker UI
4. ✅ Apply template
5. ✅ Save as template

---

## 📊 Success Metrics

- Better visual hierarchy ✅
- Members visible at a glance ✅
- Can save work in progress ✅
- Faster operation creation with templates ✅
- Reduced data entry with templates ✅

---

**Ready to start implementation!** 🎨


