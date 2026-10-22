# Flutter platform setup checklist

`flutter_app` contains source-only UI. `flutter create --project-name drivedesk_pro --platforms=windows,android,web .` generates missing platform runner folders. Then run `flutter pub get` and `flutter analyze`. Resolve any plugin compatibility warnings using your local supported Flutter release. Flutter was unavailable in the packaged environment.

## Windows

Install Flutter, Git, Visual Studio with **Desktop development with C++**, and ensure `flutter doctor` is green. `flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000`. No WAMP is required.

## Android

Install Android Studio / Android SDK. For emulator use `10.0.2.2` (host machine) and set Node `HOST=0.0.0.0` on trusted dev LAN only. Use TLS for deployed environments. Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

For development-only cleartext HTTP, add `android:usesCleartextTraffic="true"` under `<application>` within the debug manifest; don't enable cleartext in a production build.

Mobile ML Kit uses the native text recognition plugin on Android/iOS. Follow that plugin's platform-specific minSdk/Android build and iOS deployment target requirements in the installed plugin README.

## Flutter Web

Use `flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://127.0.0.1:3000`. The Node CORS allow-list has http://localhost:8080; if you choose a different port, update `CORS_ORIGIN` appropriately. Web does not use native ML Kit; optional Tesseract must be configured server-side.

## iOS

Configure `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription` in `ios/Runner/Info.plist`; run on macOS with Xcode and code signing. Ensure `google_mlkit_text_recognition` deployment target is respected.

## Inspect before interview

Run `flutter analyze`, `flutter test`, and demonstrate login/dashboard + New rental guided wizard + Rental desk pickup QR, return inspection and payment completion + one duplicate booking conflict. See `/docs/DEMO_SCRIPT.md` for talking points. Use fake customer records only.


## CarZone showroom integration

After login, open CarZone showroom. The dark/teal CarZone interface gets vehicles/customers/bookings from the shared DriveApi and creates actual pending self-drive bookings; the booking success screen takes you to Rental Desk. Run `flutter analyze` after `flutter pub get`. Driver cards and map remain demos; the backend does not store driver selection or location/time selectors.
