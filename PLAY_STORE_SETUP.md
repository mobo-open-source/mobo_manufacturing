# Play Store Setup Guide for Odoo Manufacturing App

## 🔐 Keystore Information
- **Keystore File**: `/home/cybrosys/manufacturing-app-keystore.jks`
- **Key Alias**: `manufacturing-app-key`
- **Organization**: Cybrosys Technologies
- **Location**: Kozhikode, Kerala, India

## 📱 App Details
- **Package Name**: `com.cybrosys.mobo_mfg`
- **App Name**: Odoo Manufacturing App
- **Version**: 1.0.0+1
- **Target SDK**: Latest Flutter target SDK

## 🛠️ Build Commands

### 1. Build AAB (Android App Bundle) for Play Store
```bash
cd /home/cybrosys/Downloads/mobo_manufacturing_app
flutter build appbundle --release
```

### 2. Build APK for Testing
```bash
flutter build apk --release
```

## 📁 Output Locations
- **AAB File**: `build/app/outputs/bundle/release/app-release.aab`
- **APK File**: `build/app/outputs/flutter-apk/app-release.apk`

## 🔒 Security Notes

### Important Files (Keep Secure):
1. **Keystore File**: `/home/cybrosys/manufacturing-app-keystore.jks`
2. **Key Properties**: `android/key.properties`

### ⚠️ CRITICAL SECURITY REMINDERS:
- **NEVER** commit `key.properties` to version control
- **BACKUP** your keystore file securely
- **REMEMBER** your keystore password (you'll need it for future updates)
- Store keystore password in a secure password manager

## 📝 Key Properties File Content
The file `android/key.properties` contains:
```
storePassword=your_keystore_password_here
keyPassword=your_keystore_password_here
keyAlias=manufacturing-app-key
storeFile=/home/cybrosys/manufacturing-app-keystore.jks
```

## 🚀 Next Steps for Play Store Upload

1. **Update key.properties**: Replace `your_keystore_password_here` with your actual keystore password
2. **Build AAB**: Run `flutter build appbundle --release`
3. **Test thoroughly**: Test the release build on multiple devices
4. **Upload to Play Console**: Upload the AAB file to Google Play Console
5. **Complete Play Store listing**: Add screenshots, descriptions, etc.

## 📋 Play Store Requirements Checklist

### App Information:
- [ ] App title and description
- [ ] App icon (already configured in pubspec.yaml)
- [ ] Screenshots (phone and tablet)
- [ ] Feature graphic
- [ ] Privacy policy URL
- [ ] App category selection

### Technical Requirements:
- [x] Signed AAB file
- [x] Target API level compliance
- [x] App permissions review
- [ ] Content rating questionnaire
- [ ] Pricing and distribution settings

## 🔧 Troubleshooting

### If build fails:
1. Clean the project: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Try building again

### If signing fails:
1. Verify keystore file exists at specified path
2. Check key.properties file has correct password
3. Ensure keystore alias matches

## 📞 Support
For any issues with the build process, contact the development team at Cybrosys Technologies.

---
**Generated on**: $(date)
**Keystore Created**: $(date)
