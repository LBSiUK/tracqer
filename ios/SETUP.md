# iOS App — Xcode Setup

## Create the Xcode project

1. Open Xcode → **File › New › Project**
2. Choose **iOS › App** → Next
3. Fill in:
   - **Product Name:** VinylCollection
   - **Team:** your personal team (or None for simulator)
   - **Organization Identifier:** com.yourname (anything)
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Click **Next** and save somewhere (not inside the `ios/` folder — Xcode creates its own directory)

## Add the source files

1. In Xcode's Project Navigator, **delete** the generated `ContentView.swift`
2. Right-click the `VinylCollection` group → **Add Files to "VinylCollection"…**
3. Navigate to `vinyl-collection/ios/VinylCollection/` and select **all the `.swift` files and the `Views/` folder**
4. Make sure **"Copy items if needed"** is checked and the target is ticked → Add

Your project should now have:
```
VinylCollection/
├── VinylCollectionApp.swift
├── Models.swift
├── Crypto.swift
├── APIClient.swift
├── AppState.swift
└── Views/
    ├── LoginView.swift
    ├── CollectionView.swift
    ├── RecordDetailView.swift
    ├── AddEditRecordView.swift
    └── APIImage.swift
```

## Update Info.plist

1. Click the `Info.plist` file already in your Xcode project (the one Xcode generated)
2. Add the following entries (right-click → Add Row):

| Key | Type | Value |
|-----|------|-------|
| NSAppTransportSecurity | Dictionary | — |
| → NSAllowsArbitraryLoads | Boolean | YES |
| NSPhotoLibraryUsageDescription | String | Choose photos from your library for record sleeves and disc labels. |
| NSCameraUsageDescription | String | Take photos of record sleeves and disc labels directly. |

**Why NSAllowsArbitraryLoads?** The home server uses a self-signed certificate.
The app already validates connections via `URLSessionDelegate` — this key just
prevents iOS's ATS layer from blocking it before that delegate fires.

## Build and run

- Select the **iPhone Simulator** or your physical device
- Press **⌘R** to build and run
- Log in with your server URL (e.g. `https://your-server.example:8000`) and the app password

## Notes

- **CommonCrypto** is a system framework — no additional packages needed
- **PhotosUI** is used for the photo picker — also a system framework
- The app stores your session in `UserDefaults`. If you want Keychain storage
  instead, replace the `UserDefaults` calls in `AppState.swift`
- Thumbnails are served at 640px by default; tapping a photo shows the original
