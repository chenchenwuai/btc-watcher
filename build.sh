#!/bin/bash

echo "🚀 Starting build process..."

# Set variables
APP_NAME="BTCWatcher"
MAIN_SWIFT="main.swift"
APP_BUNDLE="$APP_NAME.app"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
ZIP_NAME="$APP_NAME.app.zip"

# Create necessary directories if they don't exist
echo "📁 Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile the Swift code
echo "🔨 Compiling Swift code..."
swiftc -o "$APP_EXECUTABLE" "$MAIN_SWIFT"

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed!"
    exit 1
fi

# Set executable permissions
echo "🔒 Setting permissions..."
chmod +x "$APP_EXECUTABLE"

# Copy Info.plist if it exists
if [ -f "Info.plist" ]; then
    echo "📄 Copying Info.plist..."
    cp "Info.plist" "$APP_BUNDLE/Contents/"
fi

# Copy resources if they exist
if [ -d "Resources" ]; then
    echo "🎨 Copying resources..."
    cp -r Resources/* "$APP_BUNDLE/Contents/Resources/"
fi

# Create zip archive using ditto (preserves permissions and attributes)
echo "📦 Creating zip archive..."
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Build complete!"
    echo "📝 To run the app:"
    echo "1. Double click $APP_BUNDLE"
    echo "   or"
    echo "2. Run: open $APP_BUNDLE"
    echo ""
    echo "Note: Do not run the executable directly. Always use the app bundle."
else
    echo "❌ Failed to create zip archive!"
    exit 1
fi
