# 🚀 TestFlight Submission Checklist

## Pre-Submission Requirements

### ✅ **1. App Store Connect Setup**

#### Create App Record
- [ ] Log in to [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Click "My Apps" → "+" → "New App"
- [ ] Fill in:
  - **Platform**: iOS
  - **App Name**: Survale
  - **Primary Language**: English
  - **Bundle ID**: Select your app's bundle ID
  - **SKU**: survale-app (or similar unique identifier)
  - **User Access**: Full Access

#### App Information
- [ ] **Category**: Navigation or Productivity
- [ ] **Subcategory**: (if applicable)
- [ ] **Content Rights**: Check if you own/licensed rights

---

### ✅ **2. Xcode Project Configuration**

#### Bundle Identifier & Version
Open Xcode → Select Target → General:

- [ ] **Bundle Identifier**: `com.yourcompany.survale` (must match App Store Connect)
- [ ] **Version**: `1.0.0` (marketing version)
- [ ] **Build**: `1` (increment for each upload)
- [ ] **Display Name**: `Survale`

#### Signing & Capabilities
- [ ] **Signing**: Automatic or Manual (with Distribution certificate)
- [ ] **Team**: Select your Apple Developer Team
- [ ] **Provisioning Profile**: App Store (Distribution)
- [ ] **Capabilities Enabled**:
  - [ ] Location Services (When In Use + Always if needed)
  - [ ] Background Modes (Location updates, if using)
  - [ ] Push Notifications (if using)

#### Info.plist Required Keys
Check `Survale/Info.plist` has:
- [x] `NSCameraUsageDescription` ✅ Already added
- [x] `NSPhotoLibraryUsageDescription` ✅ Already added
- [x] `NSLocationWhenInUseUsageDescription` - **Add this!**
- [x] `NSLocationAlwaysUsageDescription` - **Add if using background location**
- [ ] `NSMicrophoneUsageDescription` ✅ Already added
- [ ] Privacy policy URL (required if collecting user data)

---

### ✅ **3. App Icon & Screenshots**

#### App Icon
- [ ] **Icon Size**: 1024x1024 pixels
- [ ] **Format**: PNG (no alpha channel)
- [ ] **Location**: `Assets.xcassets/AppIcon.appiconset`
- [ ] **Design**: Professional, represents your app
- [ ] Upload to App Store Connect

#### Screenshots (Required)
You need screenshots for at least one device size:

**6.7" Display (iPhone 14 Pro Max, 15 Pro Max)**
- [ ] 1290 x 2796 pixels (portrait)
- [ ] At least 3 screenshots, up to 10

**Recommended Screenshots:**
1. Login/Welcome screen
2. Operations list
3. Map view with tracking
4. Chat interface
5. Target details

**Tools to Create Screenshots:**
- Use Xcode Simulator → Cmd+S to capture
- Or use real device screenshots
- Edit with Preview or design tool

---

### ✅ **4. App Description & Metadata**

Prepare this content for App Store Connect:

#### App Name
```
Survale
```

#### Subtitle (30 characters)
```
Tactical Operations Tracking
```

#### Description (4000 characters max)
```
Survale is a professional-grade tactical operations coordination platform designed for law enforcement, security teams, and emergency response units.

KEY FEATURES:

🎯 OPERATION MANAGEMENT
• Create and manage tactical operations
• Assign targets with detailed profiles
• Set staging areas and rally points
• Track operation lifecycle from draft to completion

📍 REAL-TIME LOCATION TRACKING
• Live team member location on map
• Location history and trail replay
• Multiple map views (standard, satellite, hybrid)
• Zoom to team or target locations

💬 SECURE TEAM CHAT
• Operation-specific messaging
• Photo and video sharing
• Real-time updates
• Message history for all team members

🎯 TARGET INTELLIGENCE
• Person profiles with photos
• Vehicle information and images
• Location targets with coordinates
• Photo galleries for each target
• Detailed notes and observations

👥 TEAM COORDINATION
• Join request approval system
• Team member roster
• Call signs and vehicle info
• Agency and team organization

🔒 SECURE & PRIVATE
• Row-level security
• Operation-based access control
• Only team members see operation data
• Secure authentication

Perfect for:
• Law enforcement operations
• Security coordination
• Emergency response teams
• Surveillance operations
• Search and rescue missions

REQUIRES:
• Active internet connection
• GPS/location services
• Camera access (for photos)
• iOS 16.0 or later
```

#### Keywords (100 characters, comma-separated)
```
tactical,operations,tracking,law enforcement,security,coordination,team,location,surveillance
```

#### Support URL
```
https://yourdomain.com/support
```

#### Marketing URL (optional)
```
https://yourdomain.com
```

#### Privacy Policy URL (REQUIRED)
```
https://yourdomain.com/privacy
```
⚠️ **You MUST create a privacy policy page!**

---

### ✅ **5. Privacy Policy (REQUIRED)**

Create a simple privacy policy page. Here's a template:

```markdown
# Survale Privacy Policy

Last updated: October 21, 2025

## Information We Collect

**Location Data**: We collect GPS location data when you use the app to track team members during operations. Location data is only shared with members of your active operation.

**User Account**: Email address, name, call sign, team affiliation.

**Photos**: Photos you upload are stored securely and only visible to operation members.

**Messages**: Chat messages are stored and visible to operation members.

## How We Use Your Information

- Coordinate tactical operations
- Display team member locations on maps
- Enable team communication
- Store operation intelligence and targets

## Data Sharing

Your data is ONLY shared with:
- Members of operations you join
- Your team members
- No third parties

## Data Security

All data is encrypted in transit and at rest using industry-standard encryption.

## Your Rights

You can:
- Delete your account and all data
- Request data export
- Opt out of location tracking

## Contact

For privacy questions: privacy@yourdomain.com
```

Host this at: `https://yourdomain.com/privacy`

---

### ✅ **6. Code Quality & Testing**

#### Remove Debug Code
- [ ] Remove excessive print statements
- [ ] Remove debug-only features
- [ ] Comment out or remove test data

#### Test All Features
- [ ] Sign up / Sign in
- [ ] Create operation
- [ ] Add targets with photos
- [ ] Add staging points
- [ ] Join operation (with another test account)
- [ ] Real-time chat
- [ ] Photo/video messages
- [ ] Location tracking
- [ ] Map views and zoom
- [ ] Edit operation
- [ ] Edit targets
- [ ] Settings page
- [ ] Sign out

#### Test on Multiple Devices
- [ ] iPhone (latest iOS)
- [ ] iPhone (iOS 16.0 minimum)
- [ ] Different screen sizes
- [ ] Dark mode
- [ ] Light mode

#### Performance
- [ ] App launches quickly (< 3 seconds)
- [ ] No crashes
- [ ] Smooth scrolling
- [ ] Images load efficiently
- [ ] Database queries are fast

---

### ✅ **7. Required Legal Documents**

#### End User License Agreement (EULA)
- [ ] Use Apple's standard EULA, or
- [ ] Create custom EULA

#### Export Compliance
- [ ] Answer "No" if app doesn't use encryption beyond HTTPS
- [ ] Answer "Yes" if using custom encryption
  - [ ] Complete encryption registration

---

### ✅ **8. Build & Archive**

#### Final Checklist Before Archive
- [ ] Set build configuration to **Release**
- [ ] Version number incremented
- [ ] Build number incremented
- [ ] All debug code removed
- [ ] All tests pass
- [ ] Database indexes created in production
- [ ] Supabase RLS policies verified

#### Create Archive
1. **Select Target**: Survale (not "Any iOS Device")
2. **Select Scheme**: Select real device or "Any iOS Device (arm64)"
3. **Product → Archive** (⌘ + Shift + A)
4. Wait for build to complete
5. Organizer window opens automatically

#### Validate Archive
1. In Organizer, select your archive
2. Click **Validate App**
3. Choose Distribution method: **App Store Connect**
4. Select signing: **Automatic** (recommended)
5. Wait for validation
6. Fix any errors

#### Upload to App Store Connect
1. Click **Distribute App**
2. Choose: **App Store Connect**
3. Select: **Upload**
4. Signing: **Automatic**
5. Review summary
6. Click **Upload**
7. Wait 10-30 minutes for processing

---

### ✅ **9. TestFlight Configuration**

Once build is processed in App Store Connect:

#### Internal Testing
1. Go to **TestFlight** tab
2. Click your build number
3. **Provide Export Compliance**: Answer questions
4. **What to Test**: Add test notes
5. **Internal Testers**: Add team members (up to 100)
6. Build auto-distributes to internal testers

#### External Testing (Optional)
1. Create **External Test Group**
2. Add up to 10,000 testers
3. **Beta App Review**: Required for external testing
4. Provide:
   - Test account credentials
   - Instructions for reviewers
   - Features to test
5. Submit for review (1-2 days)

---

### ✅ **10. Test Notes for Testers**

Create clear instructions in TestFlight "What to Test":

```
SURVALE v1.0.0 - Initial Beta

WELCOME TESTERS!

This is the first beta of Survale, a tactical operations coordination app.

TEST ACCOUNT:
Email: test@survale.com
Password: TestPassword123!

WHAT TO TEST:
1. Sign up with your own account
2. Create a test operation
3. Add a person, vehicle, and location target
4. Upload photos to each target
5. Set a staging point
6. Join the test operation with another device/account
7. Test real-time chat with photos
8. Test location tracking on map
9. Try editing targets
10. Test settings page updates

KNOWN ISSUES:
• First text field tap may be slightly slow (optimizations coming)
• [Add any known bugs here]

FEEDBACK:
Please report bugs and suggestions via TestFlight feedback button or email: feedback@yourdomain.com

Thank you for testing!
```

---

### ✅ **11. App Review Guidelines Compliance**

Check your app complies with:

#### Safety
- [ ] No objectionable content
- [ ] No violence or graphic imagery
- [ ] Clear intended audience (17+ if law enforcement)

#### Performance
- [ ] No crashes
- [ ] Complete, polished app
- [ ] Useful functionality

#### Privacy
- [ ] Privacy policy provided
- [ ] Permission requests have clear explanations
- [ ] Data collection disclosed

#### Legal
- [ ] You own all content/rights
- [ ] No trademark violations
- [ ] EULA accepted

---

## 🚀 Quick Start Steps (TL;DR)

1. **Create app in App Store Connect**
2. **Add Info.plist location permission strings**
3. **Create 1024x1024 app icon**
4. **Take 3-5 screenshots**
5. **Write app description**
6. **Create privacy policy page**
7. **Set version to 1.0.0, build to 1**
8. **Product → Archive in Xcode**
9. **Validate → Upload to App Store Connect**
10. **Configure TestFlight**
11. **Add internal testers**
12. **Test and iterate!**

---

## ⚠️ Common Issues & Solutions

### Issue: "Missing Compliance"
**Solution**: Answer export compliance questions in TestFlight

### Issue: "Invalid Bundle"
**Solution**: Check bundle ID matches App Store Connect

### Issue: "Missing Info.plist Keys"
**Solution**: Add all required usage description strings

### Issue: "Invalid Icon"
**Solution**: Ensure 1024x1024 PNG with no alpha channel

### Issue: "Screenshots Wrong Size"
**Solution**: Use exact pixel dimensions for selected device

### Issue: "Missing Privacy Policy"
**Solution**: Add valid privacy policy URL in App Store Connect

---

## 📋 Files to Create/Update

### MUST CREATE:
1. ✅ Privacy policy webpage
2. ✅ App icon (1024x1024)
3. ✅ Screenshots (at least 3)
4. ⚠️ Add location permission strings to Info.plist

### MUST UPDATE IN XCODE:
1. Version number: `1.0.0`
2. Build number: `1`
3. Info.plist permissions

---

## 🎉 After Successful Upload

1. **Notify Testers**: Send email with TestFlight instructions
2. **Monitor Feedback**: Check TestFlight feedback regularly
3. **Fix Bugs**: Address critical issues quickly
4. **Iterate**: Upload new builds as needed (increment build number)
5. **Prepare for Release**: Once stable, submit for App Review

---

## 📞 Need Help?

- **Apple Developer Forums**: https://developer.apple.com/forums/
- **App Store Connect Help**: https://developer.apple.com/support/app-store-connect/
- **TestFlight Guide**: https://developer.apple.com/testflight/

---

**Good luck with your TestFlight release! 🚀**

