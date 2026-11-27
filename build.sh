#!/bin/bash
set -euo pipefail

echo "🚀 Starting build process..."

# Set variables
APP_NAME="BTCWatcher"
APP_BUNDLE="$APP_NAME.app"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
ZIP_NAME="$APP_NAME.app.zip"
MIN_MACOS_VERSION=$(plutil -extract LSMinimumSystemVersion raw -o - Info.plist)
SWIFT_TARGET="$(uname -m)-apple-macosx${MIN_MACOS_VERSION}"
SWIFT_FLAGS=(-target "$SWIFT_TARGET" -parse-as-library)

if [[ -n "${SPARKLE_DIR:-}${SPARKLE_PUBLIC_KEY:-}" ]]; then
    if [[ -z "${SPARKLE_DIR:-}" || ! -d "$SPARKLE_DIR/Sparkle.framework" || ! -f "$SPARKLE_DIR/LICENSE" ]]; then
        echo "SPARKLE_DIR must point to the extracted Sparkle distribution." >&2
        exit 1
    fi
    if [[ ! "${SPARKLE_PUBLIC_KEY:-}" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
        echo "SPARKLE_PUBLIC_KEY must be a base64-encoded Sparkle public key." >&2
        exit 1
    fi
    SWIFT_FLAGS+=(-D BTCWATCHER_SPARKLE -F "$SPARKLE_DIR" -framework Sparkle)
    SWIFT_FLAGS+=(-Xlinker -rpath -Xlinker @executable_path/../Frameworks)
fi

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
swiftc "${SWIFT_FLAGS[@]}" -o "$APP_EXECUTABLE" "${SWIFT_SOURCES[@]}"

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

if [[ -n "${SPARKLE_DIR:-}" ]]; then
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    ditto "$SPARKLE_DIR/Sparkle.framework" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    cp "$SPARKLE_DIR/LICENSE" "$APP_BUNDLE/Contents/Resources/Sparkle-LICENSE.txt"
    plutil -insert SUPublicEDKey -string "$SPARKLE_PUBLIC_KEY" "$APP_BUNDLE/Contents/Info.plist"
fi

# Remove extended attributes
echo "🧹 Removing extended attributes..."
xattr -cr "$APP_BUNDLE"

# Sign the application
echo "📝 Signing application..."
codesign --force --sign - "$APP_BUNDLE"
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
