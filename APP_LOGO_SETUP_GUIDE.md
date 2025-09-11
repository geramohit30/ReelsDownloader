# App Logo Setup Guide

## Overview
This guide will help you integrate your beautiful logo into the InstaReelDownloader app for both Android and iOS platforms.

## Your Logo
I can see your logo is a stunning gradient design with:
- Beautiful pink-to-orange gradient background
- Video player interface with film strip at the top
- Play button in the center
- Download arrow at the bottom
- Perfect for an Instagram Reel downloader app!

## Required Files
You need to prepare your logo image in the following formats:

### 1. Main App Icon
- **File name**: `app_icon.png`
- **Size**: 1024x1024 pixels (square)
- **Format**: PNG with transparent background (if possible)
- **Location**: `assets/icon/app_icon.png`

### 2. Android Adaptive Icons (Optional but Recommended)
For modern Android devices, you can also provide:
- **Background**: `app_icon_background.png` (1024x1024px)
- **Foreground**: `app_icon_foreground.png` (1024x1024px)
- **Location**: `assets/icon/`

## Step-by-Step Instructions

### Step 1: Prepare Your Logo Image
1. Save your logo as `app_icon.png` (1024x1024 pixels)
2. Place it in the `assets/icon/` folder (already created)

### Step 2: Install Dependencies and Generate Icons
Run these commands in your terminal:

```bash
# Install the new dependency
flutter pub get

# Generate all app icons automatically
dart run flutter_launcher_icons
```

### Step 3: Update App Name (Optional)
You might also want to update the app name displayed under the icon:

**Android**: Edit `android/app/src/main/AndroidManifest.xml`
- Change `android:label="instareeldownloader"` to your preferred name

**iOS**: Edit `ios/Runner/Info.plist`
- Update the `CFBundleDisplayName` value

## What the Script Will Generate

### Android Icons:
- `mipmap-mdpi/launcher_icon.png` (48x48px)
- `mipmap-hdpi/launcher_icon.png` (72x72px)
- `mipmap-xhdpi/launcher_icon.png` (96x96px)
- `mipmap-xxhdpi/launcher_icon.png` (144x144px)
- `mipmap-xxxhdpi/launcher_icon.png` (192x192px)

### iOS Icons:
- All required sizes for AppIcon.appiconset
- Updated Contents.json file

## Alternative Manual Method
If you prefer to create icons manually, you can use online tools:
1. [AppIcon.co](https://appicon.co) - Upload your logo and download all sizes
2. [Icon.Kitchen](https://icon.kitchen) - Another good option

## Testing
After generating the icons:
1. Run `flutter clean`
2. Run `flutter run`
3. Check that your app shows the new icon on both the home screen and app drawer

## Troubleshooting
- Make sure your source image is exactly 1024x1024 pixels
- Ensure the image has good contrast and is visible at small sizes
- Test on both light and dark wallpapers
- The icon should look good when rounded (Android) and as a rounded rectangle (iOS)

## App Name Suggestions
Consider updating the app display name to something user-friendly like:
- "Reel Downloader"
- "InstaReel"
- "Reel Saver"
- "InstaSave"