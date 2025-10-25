# 🚀 GitHub Setup Guide for Survale

## Your Repository
**URL:** https://github.com/seanfillmore/survale.git

---

## ✅ Step 1: Create .gitignore File

First, we need to tell Git which files to ignore (like build artifacts, user-specific settings, etc.)

**File:** `.gitignore` (in project root)

```gitignore
# Xcode
#
# gitignore contributors: remember to update Global/Xcode.gitignore, Objective-C.gitignore & Swift.gitignore

## User settings
xcuserdata/

## compatibility with Xcode 8 and earlier (ignoring not required starting Xcode 9)
*.xcscmblueprint
*.xccheckout

## compatibility with Xcode 3 and earlier (ignoring not required starting Xcode 4)
build/
DerivedData/
*.moved-aside
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3

## Obj-C/Swift specific
*.hmap

## App packaging
*.ipa
*.dSYM.zip
*.dSYM

## Playgrounds
timeline.xctimeline
playground.xcworkspace

# Swift Package Manager
#
# Add this line if you want to avoid checking in source code from Swift Package Manager dependencies.
# Packages/
# Package.pins
# Package.resolved
# *.xcodeproj
#
# Xcode automatically generates this directory with a .xcworkspacedata file and xcuserdata
# hence it is not needed unless you have added a package configuration file to your project
# .swiftpm

.build/

# CocoaPods
#
# We recommend against adding the Pods directory to your .gitignore. However
# you should judge for yourself, the pros and cons are mentioned at:
# https://guides.cocoapods.org/using/using-cocoapods.html#should-i-check-the-pods-directory-into-source-control
#
# Pods/
#
# Add this line if you want to avoid checking in source code from the Xcode workspace
# *.xcworkspace

# Carthage
#
# Add this line if you want to avoid checking in source code from Carthage dependencies.
# Cartfile
# Cartfile.resolved

# Accio dependency management
Dependencies/
.accio/

# fastlane
#
# It is recommended to not store the screenshots in the git repo.
# Instead, use fastlane to re-generate the screenshots whenever they are needed.
# For more information about the recommended setup visit:
# https://docs.fastlane.tools/best-practices/source-control/#source-control

fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output

# Code Injection
#
# After new code Injection tools there's a generated folder /iOSInjectionProject
# https://github.com/johnno1962/injectionforxcode

iOSInjectionProject/

# Mac
.DS_Store

# Secrets (IMPORTANT!)
Secrets.swift
**/Secrets.swift

# Temporary files
*.swp
*.swo
*~

# Environment files
.env
.env.local

# IDE
.vscode/
.idea/

# Documentation builds
docs/_build/
</ignore>
```

---

## ✅ Step 2: Initialize Git Repository

Open Terminal and navigate to your project:

```bash
cd /Users/seanfillmore/Code/Survale/Survale
```

---

## ✅ Step 3: Run Git Commands

### **Initialize Git (if not already)**
```bash
git init
```

### **Add the .gitignore file**
First, create the `.gitignore` file in your project root with the content above, then:

```bash
# Stage all files
git add .
```

### **Create your first commit**
```bash
git commit -m "Initial commit: Survale v1.0 - Tactical Operations App

Features:
- Operation management with targets and staging points
- Real-time location tracking
- Team chat with photo/video support
- Image galleries for targets
- Map with multiple view modes
- Join request system
- User profiles and settings
- Performance optimizations
- TestFlight ready"
```

### **Add your GitHub repository as remote**
```bash
git remote add origin https://github.com/seanfillmore/survale.git
```

### **Verify remote was added**
```bash
git remote -v
```

You should see:
```
origin  https://github.com/seanfillmore/survale.git (fetch)
origin  https://github.com/seanfillmore/survale.git (push)
```

### **Push to GitHub**
```bash
git branch -M main
git push -u origin main
```

If this is your first time, Git might ask for authentication. Use a Personal Access Token instead of password.

---

## 🔐 Step 4: GitHub Authentication

### **Option 1: GitHub CLI (Recommended)**
```bash
# Install GitHub CLI (if not installed)
brew install gh

# Authenticate
gh auth login

# Follow the prompts - choose HTTPS
```

### **Option 2: Personal Access Token**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (full control)
4. Generate and copy the token
5. When pushing, use token as password

### **Option 3: SSH Key**
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy public key
cat ~/.ssh/id_ed25519.pub

# Add to GitHub: Settings → SSH Keys → New SSH key
```

Then change remote to SSH:
```bash
git remote set-url origin git@github.com:seanfillmore/survale.git
```

---

## 📝 Daily Git Workflow

### **Check status**
```bash
git status
```

### **Stage changes**
```bash
# Stage specific file
git add path/to/file.swift

# Stage all changes
git add .
```

### **Commit changes**
```bash
git commit -m "Brief description of changes"
```

### **Push to GitHub**
```bash
git push
```

### **Pull latest changes**
```bash
git pull
```

---

## 🌿 Branching Strategy

### **Create a new branch for features**
```bash
# Create and switch to new branch
git checkout -b feature/new-feature-name

# Make changes, commit
git add .
git commit -m "Add new feature"

# Push branch to GitHub
git push -u origin feature/new-feature-name
```

### **Merge back to main**
```bash
# Switch to main
git checkout main

# Merge feature branch
git merge feature/new-feature-name

# Push to GitHub
git push
```

### **Delete feature branch**
```bash
git branch -d feature/new-feature-name
git push origin --delete feature/new-feature-name
```

---

## 📋 Recommended Branches

### **Main Branches:**
- `main` - Production-ready code
- `develop` - Development branch
- `staging` - Pre-production testing

### **Feature Branches:**
- `feature/map-improvements`
- `feature/chat-enhancements`
- `bugfix/location-tracking`
- `hotfix/critical-bug`

---

## 💡 Good Commit Message Examples

### **Feature additions:**
```bash
git commit -m "Add: Real-time location tracking on map"
git commit -m "Feature: Photo gallery for targets"
```

### **Bug fixes:**
```bash
git commit -m "Fix: Ambiguous column error in location publishing"
git commit -m "Bugfix: Chat messages not loading for new members"
```

### **Performance:**
```bash
git commit -m "Perf: Add database indexes for faster queries"
git commit -m "Optimize: Reduce singleton duplication"
```

### **Documentation:**
```bash
git commit -m "Docs: Add TestFlight submission guide"
git commit -m "Update: README with setup instructions"
```

### **Refactoring:**
```bash
git commit -m "Refactor: Split TargetsEditor into separate component"
git commit -m "Clean: Remove debug print statements"
```

---

## 🔒 IMPORTANT: Secrets Management

### **Never commit sensitive data!**

Your `Secrets.swift` file contains:
- Supabase URL
- Supabase Anon Key

These should **NOT** be in Git (already in .gitignore).

### **To share with team:**
1. Create `Secrets.swift.template`:
```swift
struct Secrets {
    static let supabaseURL = URL(string: "YOUR_SUPABASE_URL_HERE")!
    static let anonKey = "YOUR_ANON_KEY_HERE"
}
```

2. Add instructions in README:
```markdown
## Setup
1. Copy `Secrets.swift.template` to `Secrets.swift`
2. Fill in your Supabase credentials
```

---

## 📊 Useful Git Commands

### **View commit history**
```bash
git log
git log --oneline --graph --all
```

### **See what changed**
```bash
git diff
git diff filename.swift
```

### **Undo last commit (keep changes)**
```bash
git reset --soft HEAD~1
```

### **Discard local changes**
```bash
git checkout -- filename.swift
git restore filename.swift  # newer syntax
```

### **View remote info**
```bash
git remote show origin
```

### **List all branches**
```bash
git branch -a
```

---

## 🚀 GitHub Features to Use

### **Issues**
- Track bugs and feature requests
- Create milestones
- Assign to team members

### **Pull Requests**
- Code review before merging
- Automated checks
- Discussion threads

### **Projects**
- Kanban board for tasks
- Link issues and PRs
- Track progress

### **Actions (CI/CD)**
- Automated builds
- Run tests on push
- Deploy to TestFlight

### **Releases**
- Tag versions (v1.0.0, v1.1.0)
- Release notes
- Download builds

---

## 📱 Example Workflow for TestFlight

```bash
# 1. Make changes for new version
git checkout -b release/v1.0.1

# 2. Update version in Xcode (1.0.1, build 2)

# 3. Commit
git add .
git commit -m "Release: v1.0.1 - Bug fixes and improvements

- Fix location publishing ambiguous column
- Add database performance indexes
- Update target editing UI
- Improve settings page"

# 4. Merge to main
git checkout main
git merge release/v1.0.1

# 5. Tag the release
git tag -a v1.0.1 -m "Version 1.0.1"
git push origin main --tags

# 6. Archive and upload to TestFlight

# 7. Create GitHub Release
# Go to GitHub → Releases → Create new release
# Select tag v1.0.1
# Add release notes
```

---

## ✅ Quick Setup Checklist

- [ ] Create `.gitignore` file
- [ ] Run `git init`
- [ ] Run `git add .`
- [ ] Run `git commit -m "Initial commit"`
- [ ] Run `git remote add origin https://github.com/seanfillmore/survale.git`
- [ ] Run `git push -u origin main`
- [ ] Verify code appears on GitHub
- [ ] Add README.md to repository
- [ ] Set up branch protection rules (optional)
- [ ] Enable GitHub Actions (optional)

---

## 🎉 You're All Set!

Your code is now version controlled and backed up on GitHub!

**Next steps:**
1. Make changes to your code
2. Commit regularly
3. Push to GitHub
4. Use branches for new features
5. Create releases for TestFlight versions

---

## 📚 Resources

- **Git Documentation**: https://git-scm.com/doc
- **GitHub Guides**: https://guides.github.com
- **Git Cheat Sheet**: https://education.github.com/git-cheat-sheet-education.pdf
- **Conventional Commits**: https://www.conventionalcommits.org

---

**Happy coding! 🚀**

