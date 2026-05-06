# VTU Mobile App — Multi-Flavor White-Label Platform 📱

A fast, reliable, and secure **white-label Virtual Top-Up (VTU)** platform built with Flutter. A single codebase powers **four independently branded apps** — each with its own launcher icon, splash screen, app name, and API base URL — all from one `flutter build` command per client.

## 📦 Client Flavors

| Flavor | App Name | Package ID | API |
|---|---|---|---|
| `a3tech` | A3TECH DATA | `com.a3tech.vtumobile` | a3tech.com.ng |
| `amazcom` | Amazcom | `com.amazcom.vtumobile` | amazcom.com.ng |
| `zamanconcept` | ZamanConcept | `com.zamanconcept.vtumobile` | zamanconcept.com.ng |
| `azdigital` | AzDigital | `com.azdigital.vtumobile` | azdigital.com.ng |

---

## ✨ Features

- **Secure Authentication** — Password login, biometric login (Face ID/Fingerprint), app-lock screen for inactivity, and large-transaction re-authentication
- **Wallet System** — Fund via Paystack or virtual bank accounts (KYC-gated), real-time balance and transaction history
- **Utility Payments:**
  - 📱 **Airtime & Data** — All major networks (MTN, Airtel, GLO, 9mobile) with auto-detection
  - 📺 **Cable TV** — DSTV, GOTV, Startimes
  - 💡 **Electricity** — Prepaid/postpaid across all major DISCOs
  - 🎓 **Exam Pins** — WAEC, NECO
  - 💳 **Data Cards** — Scratch card purchases
  - 💸 **Airtime to Cash** — ATC conversion
- **Transaction Security** — Every purchase requires a 5-digit PIN via a modern bottom-sheet keypad
- **Beneficiary Management** — Save and reuse frequent recipients
- **Referral System** — Built-in affiliate and referral earnings withdrawal
- **Modern UI/UX** — Glassmorphism design, micro-animations, dark/light theme support

---

## 🛠️ Tech Stack

| Layer | Library |
|---|---|
| Framework | [Flutter](https://flutter.dev/) SDK ^3.9.2 |
| State Management | [Provider](https://pub.dev/packages/provider) |
| Networking | Custom HTTP client over `dart:io` / `http` |
| Local Storage | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) + shared_preferences |
| Security | [local_auth](https://pub.dev/packages/local_auth) (biometrics) |
| Payment | [Paystack](https://paystack.com/) in-app WebView |
| Notifications | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.9.2
- Android Studio / VS Code with Flutter extension
- A connected device or running emulator

### Installation

```bash
git clone https://github.com/ajogious/vtu_mobile_app.git
cd vtu_mobile_app
flutter pub get
```

### Running a Flavor

> ⚠️ Always specify both `--flavor` and `-t` (target entry point). Running `flutter run` without a flavor will fail.

```bash
# A3TECH DATA
flutter run --flavor a3tech -t lib/main_a3tech.dart

# Amazcom
flutter run --flavor amazcom -t lib/main_amazcom.dart

# ZamanConcept
flutter run --flavor zamanconcept -t lib/main_zamanconcept.dart

# AzDigital
flutter run --flavor azdigital -t lib/main_azdigital.dart
```

---

## 📁 Project Structure

```
lib/
├── flavors/
│   ├── client_config.dart      ← Brand data class (appName, baseUrl, logo, etc.)
│   └── flavor_config.dart      ← Singleton accessor — initialized at startup
├── config/
│   ├── client_config.dart      ← BrandConfig delegates to FlavorConfig
│   ├── app_constants.dart      ← AppConstants delegates to FlavorConfig
│   └── api_config.dart         ← Base URL from FlavorConfig
├── main_a3tech.dart            ← A3TECH entry point
├── main_amazcom.dart           ← Amazcom entry point
├── main_zamanconcept.dart      ← ZamanConcept entry point
├── main_azdigital.dart         ← AzDigital entry point
├── main.dart                   ← Shared app bootstrap (mainApp())
├── providers/                  ← State managers (Auth, Wallet, Network, etc.)
├── screens/                    ← UI (Auth, Dashboard, Buy, Wallet, Settings…)
├── services/                   ← API, Storage, Auth, Notifications
└── utils/                      ← Validators, UI helpers, error handlers

images/
├── a3tech/logo.jpg
├── amazcom/logo.jpg
├── zamanconcept/logo.jpg
└── azdigital/logo.jpg

android/app/src/
├── a3tech/res/        ← Icons + splash for A3TECH
├── amazcom/res/       ← Icons + splash for Amazcom
├── zamanconcept/res/  ← Icons + splash for ZamanConcept
└── azdigital/res/     ← Icons + splash for AzDigital
```

---

## 📦 Building for Production

### APK (for direct installation / client testing)

```bash
flutter build apk --flavor a3tech       -t lib/main_a3tech.dart       --release
flutter build apk --flavor amazcom      -t lib/main_amazcom.dart      --release
flutter build apk --flavor zamanconcept -t lib/main_zamanconcept.dart --release
flutter build apk --flavor azdigital    -t lib/main_azdigital.dart    --release
```

Output: `build/app/outputs/flutter-apk/app-<flavor>-release.apk`

### AAB (for Google Play Store)

```bash
flutter build appbundle --flavor a3tech       -t lib/main_a3tech.dart       --release
flutter build appbundle --flavor amazcom      -t lib/main_amazcom.dart      --release
flutter build appbundle --flavor zamanconcept -t lib/main_zamanconcept.dart --release
flutter build appbundle --flavor azdigital    -t lib/main_azdigital.dart    --release
```

Output: `build/app/outputs/bundle/<flavor>Release/app-<flavor>-release.aab`

---

## 🔑 Signing Setup (Play Store Release)

Each flavor requires its own keystore. Templates are provided:

```
android/a3tech-key.properties.template
android/amazcom-key.properties.template
android/zamanconcept-key.properties.template
android/azdigital-key.properties.template
```

**Steps:**

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore android/amazcom.keystore \
     -alias amazcom -keyalg RSA -keysize 2048 -validity 10000
   ```

2. Copy the template and fill in credentials:
   ```bash
   cp android/amazcom-key.properties.template android/amazcom-key.properties
   # Edit amazcom-key.properties with your keystore path, alias, and passwords
   ```

3. `android/*-key.properties` and `*.keystore` files are gitignored — **never commit them**.

---

## ➕ Adding a New Client (~15 min)

1. Add a flavor block in `android/app/build.gradle.kts` `productFlavors`
2. Create `lib/main_<client>.dart` with a `ClientConfig`
3. Add `images/<client>/logo.jpg`
4. Create `flutter_launcher_icons_<client>.yaml` and `flutter_native_splash_<client>.yaml`
5. Run icon + splash generation, then copy adaptive foreground PNGs to `android/app/src/<client>/res/drawable-*/`
6. Generate keystore + fill `android/<client>-key.properties`
7. Build: `flutter build appbundle --flavor <client> -t lib/main_<client>.dart --release`

---

## 🔐 Security Notes

- **Never commit** `.jks`, `.keystore`, or `*-key.properties` files
- Sensitive data (passwords, PINs, tokens) stored exclusively via `flutter_secure_storage`
- All API communication uses HTTPS
- Large transactions (≥ ₦10,000) require biometric/password re-authentication
- All async UI operations guarded with `mounted` checks to prevent context leaks
