#!/bin/bash
set -euo pipefail

echo "🚀 Starting build process..."

# Set variables
APP_NAME="BTCWatcher"
APP_BUNDLE="$APP_NAME.app"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
ZIP_NAME="$APP_NAME.app.zip"

# 删除已存在的 zip 文件
if [ -f "$ZIP_NAME" ]; then
    echo "🗑️  Removing existing zip file..."
    rm "$ZIP_NAME"
fi

if [ -d "$APP_BUNDLE" ]; then
    echo "🗑️  Removing existing app bundle..."
    rm -rf "$APP_BUNDLE"
fi

# Create necessary directories if they don't exist
echo "📁 Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile the Swift code
echo "🔨 Compiling Swift code..."
SWIFT_SOURCES=()
while IFS= read -r source; do
    SWIFT_SOURCES+=("$source")
done < <(find Sources/BTCMenuBar -name "*.swift" -print | sort)
swiftc -parse-as-library -o "$APP_EXECUTABLE" "${SWIFT_SOURCES[@]}"

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

# Remove extended attributes
echo "🧹 Removing extended attributes..."
xattr -cr "$APP_BUNDLE"

# Sign the application
echo "📝 Signing application..."
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

# Create zip archive using ditto (preserves permissions and attributes)
echo "📦 Creating zip archive..."
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

echo "✅ Build complete!"
echo "📝 To run the app:"
echo "1. Double click $APP_BUNDLE"
echo "   or"
echo "2. Run: open $APP_BUNDLE"
echo ""
echo "If you see 'app is damaged' message:"
echo "1. Right-click the app and select 'Open'"
echo "2. Click 'Open' in the security dialog"
echo "3. The app will be saved as an exception"
