# Church App - Setup Guide

## Prerequisites

1. **Flutter SDK** - [Install Flutter](https://flutter.dev/docs/get-started/install)
2. **Android Studio** or **Xcode** (for iOS development)
3. **VS Code** with Dart and Flutter extensions (already installed)

## Initial Setup

### 1. Get Flutter Dependencies
```bash
cd "Church-app (Map finding feature)"
flutter pub get
```

### 2. Configure Google Maps API Key

#### For Android:
1. Get your Google Maps API key from [Google Cloud Console](https://console.cloud.google.com/)
2. Open `android/app/src/main/AndroidManifest.xml`
3. Add the API key:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE"/>
```

#### For iOS:
1. Open `ios/Runner/AppDelegate.swift`
2. Add before `GeneratedPluginRegistrant.register(with: self)`:
```swift
import GoogleMaps
GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
```

### 3. Update Constants
1. Open `lib/constants/app_constants.dart`
2. Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key

### 4. Handle Location Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

#### iOS (`ios/Runner/Info.plist`):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs your location to find nearby churches</string>
```

## Running the App

### Development
```bash
flutter run
```

### Release Build
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── church_model.dart    # Church data model
├── screens/
│   └── home_screen.dart     # Home page
├── widgets/                  # Reusable UI components
├── services/
│   ├── location_service.dart   # Location handling
│   └── church_service.dart     # Church API calls
├── constants/
│   └── app_constants.dart    # App configuration
└── utils/
    └── logger_util.dart      # Logging utility

assets/
├── images/                   # App images
└── icons/                    # App icons
```

## Dependencies Installed

- **google_maps_flutter**: For map display
- **geolocator**: For location services
- **geocoding**: For address lookups
- **provider**: For state management
- **http & dio**: For API calls
- **sqflite**: For local database
- **shared_preferences**: For app preferences

## Next Steps

1. Implement the map screen
2. Integrate church data source
3. Add search and filter functionality
4. Build church details screen
5. Add navigation/directions feature
6. Implement user reviews and ratings
