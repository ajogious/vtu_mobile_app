# A3Tech Data - VTU Mobile App 📱

A fast, reliable, and secure Virtual Top-Up (VTU) mobile application built for seamless utility payments in Nigeria. Users can easily fund their wallets and pay for Airtime, Mobile Data, Cable TV subscriptions, and Electricity bills with a few taps.

## ✨ Features

* **Secure Authentication:** Multi-layered security including password login, biometric login (Face ID/Fingerprint), and an App Lock screen for inactivity.
* **Wallet System:** Users can fund their wallets via Paystack or unique virtual bank accounts, and view their balance/transaction history in real-time.
* **Utility Payments:**
  * 📱 **Airtime & Data:** Instant recharge for all major networks (MTN, Airtel, GLO, 9mobile) with support for network auto-detection.
  * 📺 **Cable TV:** Subscribe to DSTV, GOTV, and Startimes.
  * 💡 **Electricity:** Pay for prepaid/postpaid electricity across major DISCOs (Ikeja, Eko, Abuja, Kano, etc.).
* **Transaction Security:** Every transaction requires a secure 5-digit PIN confirmation via a modern bottom-sheet keypad.
* **Referral System:** Built-in affiliate and referral program tracking.
* **Modern UI/UX:** Premium glassmorphism design, interactive animations, and automatic dark/light theme support.

## 🛠️ Tech Stack

* **Framework:** [Flutter](https://flutter.dev/) (SDK ^3.9.2) - Cross-platform mobile development.
* **State Management:** [Riverpod](https://riverpod.dev/) - For robust, scalable, and testable reactive state.
* **Networking:** [Dio](https://pub.dev/packages/dio) - Advanced HTTP client handling requests to the live `a3tech.com.ng` API.
* **Local Storage:** [Hive](https://pub.dev/packages/hive) (Fast NoSQL) & [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage) (Encrypted keys/PINs).
* **Security:** [local_auth](https://pub.dev/packages/local_auth) for biometrics.
* **Payment Gateway:** [Paystack](https://paystack.com/) integrations.

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
- Android Studio / Xcode for emulators and building native apps.
- A connected physical device or running emulator.

### Installation

1. **Clone the repository** (if applicable):
   ```bash
   git clone <repository-url>
   cd vtu_mobile
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run Code Generation** (if you modify any Hive adapters or Riverpod providers):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the App:**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```text
lib/
├── config/         # API endpoints and global configurations
├── core/           # App themes, constants, and utilities
├── providers/      # Riverpod state managers
├── screens/        # UI layer (Auth, Home, Wallet, Buy Data, Settings, etc.)
├── services/       # Business logic (API requests, Storage, Biometrics)
├── utils/          # Helpers (Validators, formatters, UI helpers)
└── main.dart       # Application entry point
```

## 📦 Building for Production

This app is configured with a production package ID (`com.a3tech.vtumobile`) and optimized native assets.

**To build an Android App Bundle (AAB) for the Google Play Store:**
```bash
flutter build appbundle --release
```
*The output will be located at: `build/app/outputs/bundle/release/app-release.aab`*

**To build an APK for direct testing:**
```bash
flutter build apk --release
```

## 🔐 Security Notes
- **Never commit `.jks` Keystore files** or raw API tokens directly to version control.
- Ensure any `api_config.dart` pointing to `https://a3tech.com.ng` uses HTTPS.
- Sensitive user data (Passwords, PINs, Tokens) are strictly managed via `flutter_secure_storage`.
