# Mario Gaming Café — Flutter Sales Dashboard

A real-time mobile dashboard for Mario Gaming Café that reads directly from your existing Firebase Realtime Database. No new backend needed.

## Features

| Feature | Details |
|---|---|
| 💰 Today's Earnings | Gaming + Canteen split, Cash vs UPI breakdown |
| ⚡ Active Sessions | Live PC and PS5 session count with timers |
| 💳 Pending Dues | All unpaid sessions with customer names |
| 🛒 Canteen Sales | Today's canteen revenue |
| 🔌 Electricity Cost | 30-day estimate from metre readings |

---

## Project Structure

```
lib/
├── main.dart                        # App entry, Firebase init
├── firebase_options.dart            # Firebase config (already set)
├── services/
│   ├── firebase_service.dart        # Stream wrappers for each DB node
│   ├── dashboard_provider.dart      # ChangeNotifier — combines all streams
│   └── dashboard_model.dart        # Data models (DashboardStats, PcStatus…)
├── screens/
│   ├── home_screen.dart            # Main dashboard
│   ├── sessions_screen.dart        # Full PC + PS5 session list
│   └── dues_screen.dart            # Full pending dues list
└── widgets/
    ├── stat_card.dart              # Reusable metric card
    └── session_tile.dart           # PC/PS5 status row
```

---

## Setup Steps

### 1. Install Flutter
Download from https://flutter.dev/docs/get-started/install

### 2. Get dependencies
```bash
cd mario_dashboard
flutter pub get
```

### 3. ⚠️ Fix google-services.json (IMPORTANT)

The `android/app/google-services.json` file has a **placeholder** `mobilesdk_app_id`.  
You must replace it with the real one from Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com) → mario-gaming-cafe project
2. Project Settings → Your Apps → Add App → Android
3. Package name: `com.mariogaming.dashboard`
4. Download the real `google-services.json`
5. Replace `android/app/google-services.json` with the downloaded file

### 4. Run on Android
```bash
# Connect your Android phone (enable USB debugging)
flutter run

# Or build APK
flutter build apk --release
# APK will be at: build/outputs/flutter-apk/app-release.apk
```

---

## Firebase Database Nodes Used

| Node | Purpose |
|---|---|
| `pcs` | PC session status, timers, customer info |
| `ps5_sessions` | PS5 session status |
| `pending_dues` | Unpaid session dues |
| `payments` | Completed payments (for today's revenue) |
| `sales` | Canteen sales |
| `metre_readings` | Electricity metre readings |
| `settings` | Café name, electricity rate, pricing |

All reads are **real-time streams** — the dashboard updates instantly when data changes.

---

## Customisation

- **App name**: Change `android:label` in `AndroidManifest.xml`
- **Package name**: Change `applicationId` in `android/app/build.gradle` and re-register in Firebase
- **Colours**: All theme colours are in `home_screen.dart` and widget files
- **Add more screens**: Create a file in `lib/screens/` and link from `HomeScreen`

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `google-services.json` error | Replace with real file from Firebase Console (Step 3) |
| `minSdk` error | Already set to 21 in `build.gradle` |
| Firebase permission denied | Check Firebase Realtime DB rules allow read |
| No data showing | Confirm `databaseURL` in `firebase_options.dart` matches your project |
