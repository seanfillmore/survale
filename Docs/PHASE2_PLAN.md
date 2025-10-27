# Phase 2: Battery Optimization & Code Organization

## 🎯 Goal
Reduce battery drain by 60% through adaptive location publishing, request debouncing, and eliminating excessive @ObservedObject usage.

---

## ✅ Phase 1 Completed (Recap)
1. ✅ Single SupabaseClient instance (~80% network reduction)
2. ✅ Image downsampling (~76% memory reduction)
3. ✅ Dead code removal (1,100+ lines)
4. ✅ Critical bug fixes (operation creation, team members, assignments)

---

## 🔋 Phase 2: Battery Optimization Tasks

### 1. **Adaptive Location Publishing** (HIGH PRIORITY)
**Current Problem:**
- Publishes location every 4 seconds unconditionally
- 15 updates/minute = 900 requests/hour
- Heavy battery drain during operations

**Solution:**
- Publish based on movement (10+ meters) OR time (30+ seconds fallback)
- Dynamic interval based on speed
- Stop publishing when stationary

**Estimated Impact:**
- 70-80% fewer location updates
- 30-40% battery improvement
- Reduced database load

---

### 2. **Remove Excessive @ObservedObject Usage** (HIGH PRIORITY)
**Current Problem:**
```swift
// MapOperationView.swift - triggers redraws on ANY change!
@ObservedObject private var loc = LocationService.shared
@ObservedObject private var realtimeService = RealtimeService.shared
@ObservedObject private var store = OperationStore.shared
@ObservedObject private var assignmentService = AssignmentService.shared
@ObservedObject private var routeService = RouteService.shared
@ObservedObject private var dataCache = OperationDataCache.shared
```

**Solution:**
- Use `@StateObject` for owned instances
- Use `@ObservedObject` ONLY for data that affects UI
- Access singletons directly without observation

**Estimated Impact:**
- 50% fewer view redraws
- 10-15% CPU reduction
- Smoother UI performance

---

### 3. **Request Debouncing** (MEDIUM PRIORITY)
**Current Problem:**
- Address search on every keystroke
- No throttling or debouncing
- Unnecessary API calls

**Solution:**
- 300ms debounce for search
- Throttle map region changes
- Cancel previous requests

**Estimated Impact:**
- 60-70% fewer search API calls
- Better UX (no lag)

---

### 4. **Operation Cleanup on Leave** (MEDIUM PRIORITY)
**Current Problem:**
- Realtime subscriptions may not unsubscribe
- Location publishing sometimes continues
- Cached data not cleared

**Solution:**
- Centralized cleanup function
- Called on leave/end operation
- Ensures all services stopped

**Estimated Impact:**
- Prevents background battery drain
- Cleaner state management

---

## 📋 Implementation Checklist

### **Task 1: Adaptive Location Publishing**
- [ ] Add movement-based logic to `LocationService`
- [ ] Implement dynamic interval based on speed
- [ ] Add stationary detection
- [ ] Test battery usage before/after

### **Task 2: Optimize @ObservedObject Usage**
- [ ] Audit all views for @ObservedObject
- [ ] Change to direct access where UI doesn't depend on updates
- [ ] Keep @ObservedObject only for UI-critical data
- [ ] Test performance improvements

### **Task 3: Request Debouncing**
- [ ] Add debouncing to `AddressSearchField`
- [ ] Add throttling to map region changes
- [ ] Implement task cancellation
- [ ] Test search performance

### **Task 4: Operation Cleanup**
- [ ] Create `cleanupOperation()` function in AppState
- [ ] Call from `leaveOperation()`, `endOperation()`, `transferOperation()`
- [ ] Ensure all services stop properly
- [ ] Test no background activity after leaving

---

## 🚀 Implementation Order

1. **Start with @ObservedObject audit** (quick wins, immediate perf improvement)
2. **Adaptive location publishing** (biggest battery impact)
3. **Request debouncing** (improves UX + reduces load)
4. **Operation cleanup** (ensures clean state)

---

## 📊 Success Metrics

### **Before Phase 2:**
- Battery drain: ~25%/hour during active operation
- Location updates: 900/hour
- View redraws: Excessive (every service change)
- Background activity: Continues after leaving operation

### **After Phase 2 (Target):**
- Battery drain: ~10-12%/hour (-50-60%)
- Location updates: 180-250/hour (-70-80%)
- View redraws: Only on relevant data changes (-50%)
- Background activity: Fully stopped when not in operation

---

## 🔧 Technical Details

### **Adaptive Location Publishing Algorithm**
```swift
private var lastPublishedLocation: CLLocation?
private var lastPublishedTime: Date = Date()
private var minimumDistance: CLLocationDistance = 10 // meters
private var minimumTime: TimeInterval = 30 // seconds

func shouldPublishLocation(_ newLocation: CLLocation) -> Bool {
    guard let lastLocation = lastPublishedLocation else {
        return true // First location
    }
    
    let distance = newLocation.distance(from: lastLocation)
    let timeSince = Date().timeIntervalSince(lastPublishedTime)
    
    // Calculate dynamic threshold based on speed
    let speed = newLocation.speed // m/s
    let dynamicDistance = speed > 0 ? max(10, speed * 5) : 10
    
    return distance >= dynamicDistance || timeSince >= minimumTime
}
```

### **@ObservedObject Audit Pattern**
```swift
// ❌ BAD: Observing everything
@ObservedObject private var store = OperationStore.shared

// ✅ GOOD: Direct access if not used for UI
private let store = OperationStore.shared

// ✅ GOOD: Observe only if UI depends on it
@ObservedObject private var assignmentService = AssignmentService.shared
```

### **Debounce Implementation**
```swift
@State private var searchTask: Task<Void, Never>?

func search(_ query: String) {
    searchTask?.cancel()
    searchTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        guard !Task.isCancelled else { return }
        await performSearch(query)
    }
}
```

---

## ⚠️ Testing Requirements

### **Location Publishing**
- Test stationary device (should reduce to 30s intervals)
- Test walking speed (should publish every 10-15m)
- Test driving speed (should publish every 25-50m)
- Monitor battery usage over 1 hour

### **@ObservedObject Changes**
- Verify UI still updates correctly
- Check that views don't over-refresh
- Test all affected views thoroughly

### **Request Debouncing**
- Type quickly in search field (should wait 300ms)
- Verify search results are accurate
- Check that previous requests are cancelled

### **Operation Cleanup**
- Leave operation, check background activity
- End operation, check all services stopped
- Transfer operation, verify cleanup happened

---

## 📝 Files to Modify

### **Services/**
- `LocationService.swift` - Adaptive publishing
- `AssignmentService.swift` - Optimize observers

### **Views/**
- `MapOperationView.swift` - Remove excess @ObservedObject
- `OperationsView.swift` - Optimize observers
- `ChatView.swift` - Optimize observers
- `AddressSearchField.swift` - Add debouncing
- `ActiveOperationDetailView.swift` - Add cleanup

### **Core/**
- `AppState.swift` - Add cleanupOperation() function

---

## 🎯 Branch Strategy

**Current Branch:** `refactor/phase-2-code-organization`  
**Commit Strategy:** Small, focused commits for each task  
**Testing:** Test each change before moving to next

---

Ready to start implementation! 🚀


