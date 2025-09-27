#!/bin/bash

# Build script to ensure SDUI JSON files are always fresh
# This prevents caching issues where old JSON files remain in the bundle

set -e

echo "🔄 Refreshing SDUI JSON files..."

# Source directory containing JSON files
JSON_SOURCE_DIR="${SRCROOT}/PestGenie"

# Destination directory in the app bundle
JSON_DEST_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"

# List of critical JSON files that should always be fresh
JSON_FILES=(
    "ProfileScreen.json"
    "TechnicianScreen.json"
    "TechnicianScreen_v2.json"
    "TechnicianScreen_v3.json"
)

# Force copy each JSON file to ensure it's up to date
for json_file in "${JSON_FILES[@]}"; do
    source_file="${JSON_SOURCE_DIR}/${json_file}"
    dest_file="${JSON_DEST_DIR}/${json_file}"

    if [[ -f "$source_file" ]]; then
        echo "📋 Copying $json_file..."
        cp "$source_file" "$dest_file"

        # Verify the copy was successful
        if [[ -f "$dest_file" ]]; then
            echo "✅ $json_file updated successfully"
        else
            echo "❌ Failed to copy $json_file"
            exit 1
        fi
    else
        echo "⚠️  Warning: $json_file not found in source directory"
    fi
done

echo "🎉 All SDUI JSON files refreshed successfully!"