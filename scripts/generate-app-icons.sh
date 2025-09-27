#!/bin/bash

# App Icon Generator Script for PestGenie
# Generates all required iOS app icon sizes from a source image

set -e

# Configuration
SOURCE_IMAGE="$1"
ICON_DIR="/Users/jbriggs/StudioProjects/PestGenie/PestGenie/Assets.xcassets/AppIcon.appiconset"

# Color for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎨 PestGenie App Icon Generator${NC}"
echo "========================================"

# Check if source image is provided
if [ -z "$SOURCE_IMAGE" ]; then
    echo -e "${RED}❌ Error: Please provide a source image file${NC}"
    echo "Usage: $0 <source_image.png>"
    echo "Example: $0 pestgenie-icon-1024.png"
    exit 1
fi

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo -e "${RED}❌ Error: Source image file not found: $SOURCE_IMAGE${NC}"
    exit 1
fi

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo -e "${RED}❌ Error: ImageMagick is not installed${NC}"
    echo "Please install ImageMagick:"
    echo "  brew install imagemagick"
    exit 1
fi

# Create icon directory if it doesn't exist
mkdir -p "$ICON_DIR"

echo -e "${BLUE}📱 Generating iPhone icons...${NC}"

# iPhone icons
convert "$SOURCE_IMAGE" -resize 40x40 "$ICON_DIR/AppIcon-20@2x.png"
convert "$SOURCE_IMAGE" -resize 60x60 "$ICON_DIR/AppIcon-20@3x.png"
convert "$SOURCE_IMAGE" -resize 58x58 "$ICON_DIR/AppIcon-29@2x.png"
convert "$SOURCE_IMAGE" -resize 87x87 "$ICON_DIR/AppIcon-29@3x.png"
convert "$SOURCE_IMAGE" -resize 80x80 "$ICON_DIR/AppIcon-40@2x.png"
convert "$SOURCE_IMAGE" -resize 120x120 "$ICON_DIR/AppIcon-40@3x.png"
convert "$SOURCE_IMAGE" -resize 120x120 "$ICON_DIR/AppIcon-60@2x.png"
convert "$SOURCE_IMAGE" -resize 180x180 "$ICON_DIR/AppIcon-60@3x.png"

echo -e "${BLUE}📟 Generating iPad icons...${NC}"

# iPad icons
convert "$SOURCE_IMAGE" -resize 20x20 "$ICON_DIR/AppIcon-20.png"
convert "$SOURCE_IMAGE" -resize 40x40 "$ICON_DIR/AppIcon-20@2x-ipad.png"
convert "$SOURCE_IMAGE" -resize 29x29 "$ICON_DIR/AppIcon-29.png"
convert "$SOURCE_IMAGE" -resize 58x58 "$ICON_DIR/AppIcon-29@2x-ipad.png"
convert "$SOURCE_IMAGE" -resize 40x40 "$ICON_DIR/AppIcon-40.png"
convert "$SOURCE_IMAGE" -resize 80x80 "$ICON_DIR/AppIcon-40@2x-ipad.png"
convert "$SOURCE_IMAGE" -resize 76x76 "$ICON_DIR/AppIcon-76.png"
convert "$SOURCE_IMAGE" -resize 152x152 "$ICON_DIR/AppIcon-76@2x.png"
convert "$SOURCE_IMAGE" -resize 167x167 "$ICON_DIR/AppIcon-83.5@2x.png"

echo -e "${BLUE}🏪 Generating App Store icon...${NC}"

# App Store Marketing icon (1024x1024)
convert "$SOURCE_IMAGE" -resize 1024x1024 "$ICON_DIR/AppIcon-1024.png"

# Remove the placeholder file if it exists
if [ -f "$ICON_DIR/pestgenie-original.png" ]; then
    rm "$ICON_DIR/pestgenie-original.png"
fi

echo ""
echo -e "${GREEN}✅ App icon generation complete!${NC}"
echo ""
echo "Generated icons:"
echo "📱 iPhone: 8 sizes (20pt-60pt @ 2x,3x)"
echo "📟 iPad: 9 sizes (20pt-83.5pt @ 1x,2x)"
echo "🏪 App Store: 1024x1024"
echo ""
echo "Location: $ICON_DIR"
echo ""
echo -e "${BLUE}🔄 Next steps:${NC}"
echo "1. Open PestGenie.xcodeproj in Xcode"
echo "2. Build and run to see your new app icon!"

# List generated files
echo ""
echo "Generated files:"
ls -la "$ICON_DIR"/*.png 2>/dev/null | while read line; do
    echo "  📄 $(basename $(echo $line | awk '{print $NF}'))"
done