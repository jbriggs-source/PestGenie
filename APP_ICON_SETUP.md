# PestGenie App Icon Setup Guide

## ✅ What's Already Done

I've set up the complete app icon structure for you:

- ✅ Created `Assets.xcassets` folder
- ✅ Created `AppIcon.appiconset` with proper `Contents.json`
- ✅ Configured all required iOS icon sizes (iPhone, iPad, App Store)
- ✅ Created icon generation script

## 📋 Required Steps to Complete

### Step 1: Save Your App Icon Image

1. **Save your app icon image** (the green pest control character) to:
   ```
   /Users/jbriggs/StudioProjects/PestGenie/PestGenie/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
   ```

2. **Important**: The image must be:
   - Exactly **1024x1024 pixels**
   - **PNG format**
   - No transparency (solid background)
   - High quality/resolution

### Step 2: Generate All Icon Sizes

**Option A: Use Online Tool (Recommended)**
1. Go to https://appicon.co or similar app icon generator
2. Upload your 1024x1024 PNG image
3. Download the generated icons
4. Replace the files in: `/Users/jbriggs/StudioProjects/PestGenie/PestGenie/Assets.xcassets/AppIcon.appiconset/`

**Option B: Use Our Script (Requires ImageMagick)**
```bash
# Install ImageMagick first
brew install imagemagick

# Run our generation script
cd /Users/jbriggs/StudioProjects/PestGenie
./Scripts/generate-app-icons.sh path/to/your/1024x1024-icon.png
```

### Step 3: Required Icon Files

Your `AppIcon.appiconset` folder should contain these files:

#### iPhone Icons
- `AppIcon-20@2x.png` (40x40)
- `AppIcon-20@3x.png` (60x60)
- `AppIcon-29@2x.png` (58x58)
- `AppIcon-29@3x.png` (87x87)
- `AppIcon-40@2x.png` (80x80)
- `AppIcon-40@3x.png` (120x120)
- `AppIcon-60@2x.png` (120x120)
- `AppIcon-60@3x.png` (180x180)

#### iPad Icons
- `AppIcon-20.png` (20x20)
- `AppIcon-20@2x-ipad.png` (40x40)
- `AppIcon-29.png` (29x29)
- `AppIcon-29@2x-ipad.png` (58x58)
- `AppIcon-40.png` (40x40)
- `AppIcon-40@2x-ipad.png` (80x80)
- `AppIcon-76.png` (76x76)
- `AppIcon-76@2x.png` (152x152)
- `AppIcon-83.5@2x.png` (167x167)

#### App Store
- `AppIcon-1024.png` (1024x1024)

## 🎨 Your Icon Image

The green pest control character image you provided is perfect! It features:
- 🟢 Professional green gradient background
- 👨‍🔬 Cartoon technician with goggles and equipment
- 🐛 Various pests around the character (mosquito, ant, spider, mouse)
- 🎯 Clear, recognizable design that works well at small sizes

## 🔧 After Setup

1. **Open Xcode**: Open `PestGenie.xcodeproj`
2. **Check Assets**: Navigate to `Assets.xcassets` → `AppIcon` in Xcode
3. **Verify Icons**: All icon slots should show your green character
4. **Build & Test**: Run the app to see your new icon

## 🏗️ Build Commands

After setting up the icon:
```bash
# Clean build to ensure icon updates
make clean-build

# Or standard build
make build
```

## 📱 Testing

Your new app icon will appear:
- On the iOS simulator home screen
- In the app switcher
- In Spotlight search
- In Settings > General > iPhone Storage

## 🎉 Result

Once complete, your PestGenie app will have a professional, recognizable icon featuring your green pest control character that stands out on users' home screens!

## 🆘 Need Help?

If you encounter issues:
1. Check that all PNG files are the correct pixel dimensions
2. Ensure no transparency in the icons
3. Verify the `Contents.json` file is properly formatted
4. Try a clean build: `make clean-build`