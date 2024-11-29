#!/bin/bash

# Check if rsvg-convert is installed
if ! command -v rsvg-convert &> /dev/null; then
    echo "Installing rsvg-convert..."
    brew install librsvg
fi

# Convert SVG to PNG
if [ -f "AppIcon.svg" ]; then
    echo "🎨 Converting SVG to PNG..."
    rsvg-convert -w 1024 -h 1024 AppIcon.svg > icon.png
fi

# Create temporary iconset directory
ICONSET="AppIcon.iconset"
mkdir -p "$ICONSET"

# Function to create icon from base image
create_icon() {
    local size=$1
    local input=$2
    local output="$ICONSET/icon_${size}x${size}.png"
    sips -z $size $size "$input" --out "$output"
}

# Check if input image exists
if [ ! -f "icon.png" ]; then
    echo "❌ Error: icon.png not found!"
    echo "Please provide a square PNG image named 'icon.png'"
    exit 1
fi

# Create icons of different sizes
create_icon 16 "icon.png"
create_icon 32 "icon.png"
create_icon 64 "icon.png"
create_icon 128 "icon.png"
create_icon 256 "icon.png"
create_icon 512 "icon.png"
create_icon 1024 "icon.png"

# Copy for @2x versions
cp "$ICONSET/icon_32x32.png" "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png" "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png" "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png" "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

# Create icns file
iconutil -c icns "$ICONSET"

# Move to Resources
mkdir -p Resources
mv AppIcon.icns Resources/

# Clean up
rm -rf "$ICONSET"
rm -f icon.png

echo "✅ Icon created successfully!"
