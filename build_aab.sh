#!/bin/bash

# Build AAB for Play Store Upload
# Cybrosys Manufacturing App

echo "🏭 Building Odoo Manufacturing App for Play Store..."
echo "=================================================="

# Check if key.properties has been updated
if grep -q "your_keystore_password_here" android/key.properties; then
    echo "❌ ERROR: Please update android/key.properties with your actual keystore password!"
    echo "   Edit the file and replace 'your_keystore_password_here' with your real password."
    exit 1
fi

# Check if keystore file exists
if [ ! -f "/home/cybrosys/manufacturing-app-keystore.jks" ]; then
    echo "❌ ERROR: Keystore file not found at /home/cybrosys/manufacturing-app-keystore.jks"
    echo "   Please ensure the keystore file exists."
    exit 1
fi

echo "✅ Keystore configuration looks good!"
echo ""

# Clean and get dependencies
echo "🧹 Cleaning project..."
flutter clean
echo ""

echo "📦 Getting dependencies..."
flutter pub get
echo ""

# Build AAB
echo "🔨 Building Android App Bundle (AAB)..."
flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS! AAB file created successfully!"
    echo "📁 Location: build/app/outputs/bundle/release/app-release.aab"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Upload app-release.aab to Google Play Console"
    echo "2. Complete your Play Store listing"
    echo "3. Submit for review"
    echo ""
    echo "📊 File size:"
    ls -lh build/app/outputs/bundle/release/app-release.aab
else
    echo ""
    echo "❌ Build failed! Please check the error messages above."
    exit 1
fi
