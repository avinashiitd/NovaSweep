#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "=== Building NovaSweep for macOS ==="

# 1. Clean previous build
rm -rf build/NovaSweep build/NovaSweep.app
mkdir -p build/NovaSweep.app/Contents/MacOS
mkdir -p build/NovaSweep.app/Contents/Resources

# 2. Generate AppIcon.icns if not present
if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "Rendering AppIcon..."
    swift Resources/generate_icon.swift
    iconutil -c icns /tmp/NovaSweep.iconset -o Resources/AppIcon.icns
    rm -rf /tmp/NovaSweep.iconset
fi

# 3. Compile Swift sources
echo "Compiling Swift sources with optimizations..."
swiftc -O -parse-as-library \
  src/Models/Models.swift \
  src/Engine/ScannerEngine.swift \
  src/Engine/CleanerEngine.swift \
  src/Engine/AppState.swift \
  src/Views/SidebarView.swift \
  src/Views/DashboardView.swift \
  src/Views/CategoryDetailView.swift \
  src/Views/LargeFilesView.swift \
  src/Views/SettingsView.swift \
  src/Views/CleanCompleteModal.swift \
  src/NovaSweepApp.swift \
  -o build/NovaSweep.app/Contents/MacOS/NovaSweep

# 4. Copy Bundle Assets
cp Resources/Info.plist build/NovaSweep.app/Contents/Info.plist
cp Resources/AppIcon.icns build/NovaSweep.app/Contents/Resources/AppIcon.icns
chmod +x build/NovaSweep.app/Contents/MacOS/NovaSweep
touch build/NovaSweep.app

echo "=== Packaging Complete: build/NovaSweep.app ==="

# 5. Install to ~/Applications
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/NovaSweep.app"
cp -R build/NovaSweep.app "$HOME/Applications/NovaSweep.app"
touch "$HOME/Applications/NovaSweep.app"

echo "=== Installed to $HOME/Applications/NovaSweep.app ==="
echo "You can launch it anytime by running: open $HOME/Applications/NovaSweep.app"
