# 🎯 Survale

**Tactical Operations Coordination Platform for iOS**

A professional-grade mobile application designed for law enforcement, security teams, and emergency response units to coordinate tactical operations in real-time.

[![Platform](https://img.shields.io/badge/platform-iOS%2016.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)]()

---

## 🚀 Features

### 📍 **Real-Time Location Tracking**
- Live team member locations on interactive map
- Location history and trail replay
- Multiple map styles (standard, satellite, hybrid)
- Zoom to team or target locations

### 🎯 **Target Management**
- Person profiles with photos and details
- Vehicle information with image galleries
- Location targets with coordinates
- Multi-image galleries for each target
- Editable target details

### 💬 **Secure Team Chat**
- Operation-specific messaging
- Photo and video sharing from camera or library
- Real-time message delivery
- Full message history for all team members
- Message bubbles with auto-scroll

### 🗺️ **Map Features**
- Target and staging area markers
- Team member location pins
- Zoom to all targets button
- Zoom to team members button
- Map type switcher (Standard/Hybrid/Satellite)
- "View on Map" from detail views

### 👥 **Team Coordination**
- Create and manage operations
- Join request approval system
- Team member roster with call signs
- Vehicle information tracking
- Agency and team organization

### 🔒 **Security**
- Row-level security (RLS)
- Operation-based access control
- Secure authentication
- Member-only data access

---

## 📱 Screenshots

_Coming soon_

---

## 🛠️ Tech Stack

### **Frontend**
- **SwiftUI** - Modern declarative UI framework
- **MapKit** - Interactive mapping
- **CoreLocation** - GPS tracking
- **PhotosUI** - Photo library integration
- **AVFoundation** - Camera capture

### **Backend**
- **Supabase** - Backend as a Service
  - PostgreSQL database
  - Real-time subscriptions
  - Row Level Security
  - Storage for media files
  - Authentication

### **Architecture**
- MVVM pattern
- SwiftUI views with observable objects
- Singleton services for shared state
- Async/await for concurrency
- Real-time data synchronization

---

## 📋 Requirements

- iOS 16.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Active Supabase account
- GPS/Location services
- Camera access
- Internet connection

---

## 🚀 Getting Started

### **1. Clone the Repository**
```bash
git clone https://github.com/seanfillmore/survale.git
cd survale
```

### **2. Set Up Secrets**
Create a `Secrets.swift` file in the project root:

```swift
import Foundation

struct Secrets {
    static let supabaseURL = URL(string: "YOUR_SUPABASE_URL")!
    static let anonKey = "YOUR_SUPABASE_ANON_KEY"
}
```

### **3. Database Setup**
Run the SQL scripts in order:
1. `Docs/setup_database.sql` - Core tables
2. `Docs/create_rpc_functions.sql` - Database functions
3. `Docs/add_performance_indexes.sql` - Performance optimization
4. Additional scripts as needed

### **4. Configure Supabase**
- Enable Row Level Security on all tables
- Set up storage buckets:
  - `target-images` - For target photos
  - `chat-media` - For chat photos/videos
- Configure authentication providers

### **5. Build and Run**
```bash
open Survale.xcodeproj
```
- Select your development team
- Choose target device/simulator
- Press ⌘ + R to build and run

---

## 📂 Project Structure

```
Survale/
├── Models/
│   ├── OperationModels.swift      # Core data models
│   └── OpTargetModels.swift       # Target data structures
├── Services/
│   ├── SupabaseAuthService.swift  # Authentication & database
│   ├── SupabaseRPCService.swift   # RPC function calls
│   ├── LocationServices.swift     # GPS tracking
│   └── RealtimeService.swift      # Real-time updates
├── Views/
│   ├── OperationsView.swift       # Operations list
│   ├── MapOperationView.swift     # Interactive map
│   ├── ChatView.swift             # Team messaging
│   ├── CreateOperationView.swift  # Create/edit operations
│   ├── ActiveOperationDetailView.swift  # Operation details
│   └── SettingsView.swift         # User settings
├── OpTargetImageManager.swift     # Image handling
├── TargetMedia.swift              # Media models
├── AppState.swift                 # App state management
├── OperationStore.swift           # Operations data store
└── Docs/                          # Documentation & SQL scripts
```

---

## 🗄️ Database Schema

### **Core Tables**
- `users` - User profiles and credentials
- `teams` - Team organization
- `agencies` - Agency organization
- `operations` - Tactical operations
- `operation_members` - Team assignments
- `targets` - Person/vehicle/location targets
- `staging_areas` - Rally points
- `op_messages` - Chat messages
- `locations_stream` - GPS tracking data
- `join_requests` - Operation join requests

### **RPC Functions**
- `rpc_create_operation` - Create new operation
- `rpc_get_operation_targets` - Fetch targets
- `rpc_publish_location` - Update GPS location
- `rpc_post_message` - Send chat message
- `rpc_request_join_operation` - Request to join
- Many more...

---

## 🔧 Configuration

### **Location Tracking**
- Publishes location every 4 seconds when active
- Background location updates supported
- Configurable accuracy and update interval

### **Real-Time Updates**
- Postgres Change subscriptions for live data
- Location updates via database triggers
- Chat messages with instant delivery

### **Image Storage**
- Compressed JPEG format
- Supabase Storage integration
- Thumbnail generation
- Image caching for performance

---

## 🚀 Performance Optimizations

### **Implemented**
- ✅ Database indexes on critical columns
- ✅ Singleton service pattern
- ✅ Image compression and caching
- ✅ Efficient SQL queries with RPC functions
- ✅ Lazy loading for lists
- ✅ Auto-refresh with pull-to-refresh

### **Planned**
- Client-side caching layer
- Message pagination
- Offline mode
- Background sync

---

## 📱 TestFlight & App Store

### **Current Status**
- ✅ Core features complete
- ✅ Performance optimized
- ✅ Info.plist configured
- ⏳ Awaiting TestFlight submission

### **Version History**
- **v1.0.0** - Initial release
  - Operation management
  - Real-time tracking
  - Team chat
  - Target galleries
  - Map features

---

## 🤝 Contributing

This is a proprietary project. Contributions are by invitation only.

---

## 📄 License

Proprietary - All rights reserved

---

## 👨‍💻 Author

Sean Fillmore

---

## 📞 Support

For issues and feature requests, please contact the development team.

---

## 🙏 Acknowledgments

- **Supabase** - Backend infrastructure
- **Apple** - iOS platform and frameworks
- **SwiftUI** - Modern UI framework

---

## 📚 Documentation

Full documentation available in the `Docs/` folder:
- Database setup guides
- Performance optimization docs
- TestFlight submission checklist
- GitHub workflow guide
- API documentation

---

**Built with ❤️ for tactical operations professionals**

