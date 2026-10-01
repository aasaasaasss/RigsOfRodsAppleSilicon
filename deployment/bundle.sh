#!/bin/bash
set -e
echo "Packaging Rigs of Rods.app bundle..."

APP_DIR="RigsOfRods.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary and plugins config
cp bin/RoR "$APP_DIR/Contents/MacOS/"
cp bin/plugins.cfg "$APP_DIR/Contents/Resources/"

# Copy generated resources/content
cp -r bin/resources "$APP_DIR/Contents/Resources/" 2>/dev/null || true
cp -r bin/content "$APP_DIR/Contents/Resources/" 2>/dev/null || true

# Copy dylib dependencies
cp bin/*.dylib "$APP_DIR/Contents/MacOS/" 2>/dev/null || true

echo "App bundle structure created successfully at $APP_DIR"
