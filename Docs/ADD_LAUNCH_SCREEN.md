# Add Static Launch Screen (iOS)

Apple requires a static Launch Screen that appears instantly when the app starts. This is separate from our animated splash screen with progress indicator.

## Steps to Add Launch Screen in Xcode

### Option 1: Storyboard Launch Screen (Recommended)

1. **Create Launch Screen Storyboard**
   - In Xcode, right-click on the `Survale` folder
   - Select `New File...`
   - Choose `Launch Screen` under iOS > User Interface
   - Name it `LaunchScreen.storyboard`
   - Click `Create`

2. **Design the Launch Screen**
   - Open `LaunchScreen.storyboard`
   - Drag an `Image View` onto the canvas
   - Set constraints: Center X, Center Y, Width = 120, Height = 120
   - In Attributes Inspector, set Image to `LoginLogo`
   - Add a `Label` below the image
   - Set text to "Survale", font size 40, bold
   - Add another label with "Tactical Operations Platform"

3. **Configure in Info.plist**
   - Open `Survale/Info.plist`
   - Add key: `UILaunchStoryboardName`
   - Set value: `LaunchScreen`

### Option 2: Image-Based Launch Screen (Simpler)

1. **Create Launch Screen Image**
   - Export a 1170x2532 PNG (iPhone 13 Pro Max size)
   - Design should match your splash screen look
   - Include logo, app name, maybe subtle gradient

2. **Add to Assets**
   - Open `Assets.xcassets`
   - Right-click > New Image Set
   - Name it `LaunchScreenImage`
   - Add your launch screen image

3. **Create Storyboard**
   - Follow Option 1, but use a single full-screen Image View
   - Set image to `LaunchScreenImage`
   - Set Content Mode to `Aspect Fill`

## Current Setup

We've already implemented:
- ✅ **SplashView.swift** - Animated splash with progress indicator
- ✅ **AppState.isInitializing** - Tracks loading state
- ✅ **SurvaleApp initialization** - Shows splash during app setup

## What You'll See

1. **Launch Screen** (static, instant) - iOS shows this immediately
2. **SplashView** (animated, 1.5s) - Our custom loading screen with progress
3. **LoginView or RootView** - Main app content

## Notes

- The static Launch Screen cannot have animations or loading indicators (Apple restriction)
- Our animated SplashView handles the "loading" experience
- Minimum 1.5 second display ensures smooth transition
- Fade animation between splash and main content

## Testing

After adding the launch screen:
1. Clean build folder: `Cmd + Shift + K`
2. Delete app from simulator/device
3. Run fresh install to see launch screen

