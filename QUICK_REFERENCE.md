# 🚀 Quick Reference - Play Store Upload

## 📋 Checklist Before Building

- [ ] **Update Password**: Edit `android/key.properties` - replace `your_keystore_password_here` with your actual keystore password
- [ ] **Verify Keystore**: Ensure `/home/cybrosys/manufacturing-app-keystore.jks` exists
- [ ] **Test App**: Run `flutter run --release` to test the release build
- [ ] **Update Version**: Update version in `pubspec.yaml` if needed (currently: 1.0.0+1)

## 🔨 Build Commands

### Option 1: Use the Build Script (Recommended)
```bash
./build_aab.sh
```

### Option 2: Manual Build
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

## 📁 Output Files
- **AAB File**: `build/app/outputs/bundle/release/app-release.aab` ← Upload this to Play Store
- **APK File**: `build/app/outputs/flutter-apk/app-release.apk` (if you build APK)

## 🔐 Security Reminders

### 🚨 CRITICAL - Keep These Safe:
1. **Keystore File**: `/home/cybrosys/manufacturing-app-keystore.jks`
2. **Keystore Password**: The password you entered during keystore creation
3. **Key Alias**: `manufacturing-app-key`

### ⚠️ Never Do This:
- Don't commit `key.properties` to Git
- Don't share your keystore file publicly
- Don't lose your keystore password (you'll need it for updates)

## 📱 App Information
- **Package Name**: `com.cybrosys.mobo_mfg`
- **App Name**: Odoo Manufacturing App
- **Organization**: Cybrosys Technologies
- **Current Version**: 1.0.0+1

## 🐛 Troubleshooting

### Build Fails?
1. Run `flutter doctor` to check setup
2. Ensure Android SDK is properly installed
3. Check if keystore password is correct
4. Try `flutter clean` and rebuild

### Signing Issues?
1. Verify keystore file path in `key.properties`
2. Check password is correct (no extra spaces)
3. Ensure key alias matches: `manufacturing-app-key`

## 📞 Need Help?
Contact Cybrosys Technologies development team for support.

---
**Generated**: $(date)
**Keystore Location**: `/home/cybrosys/manufacturing-app-keystore.jks`
