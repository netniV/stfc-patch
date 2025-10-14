#!/usr/bin/env zsh
setopt NO_RCS

# Function to handle errors
handle_error() {
    local exit_code=$1
    local message="$2"
    if [ $exit_code -ne 0 ]; then
        echo "❌ Error ($exit_code): $message"
        exit $exit_code
    fi
}

# Function to normalize a filesystem path
normalize_path() {
    local input_path="$1"
    # Remove trailing slashes (but not if path is just "/")
    input_path="${input_path%/}"
    # Replace multiple leading slashes with a single one
    input_path="${input_path/#\/\/*/\/}"
    echo "$input_path"
}

# Function to patch app entitlements
patch_app_entitlements() {
    local app_path="$1"
    local entitlements_plist=/tmp/debug_entitlements.plist

    echo "🔧 Preparing entitlements plist..."
    /usr/libexec/PlistBuddy -c "Clear dict" "$entitlements_plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add : dict" "$entitlements_plist"
    handle_error $? "Failed to initialize $entitlements_plist"

    echo "🧩 Adding entitlements..."
    /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$entitlements_plist"
    handle_error $? "Failed to add disable-library-validation"

    /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.allow-unsigned-executable-memory bool true" "$entitlements_plist"
    handle_error $? "Failed to add allow-unsigned-executable-memory"

    /usr/libexec/PlistBuddy -c "Add :com.apple.security.get-task-allow bool true" "$entitlements_plist"
    handle_error $? "Failed to add get-task-allow"

    /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.allow-dyld-environment-variables bool true" "$entitlements_plist"
    handle_error $? "Failed to add allow-dyld-environment-variables"

    echo "🪪 Re-signing app..."
    /usr/bin/codesign --force --options runtime --sign - --entitlements "$entitlements_plist" "$app_path"
    handle_error $? "/usr/bin/codesign failed on $app_path"

    echo "🧹 Cleaning up..."
    /bin/rm -f "$entitlements_plist"
    handle_error $? "Failed to remove temporary plist $entitlements_plist"

    echo "✅ Successfully patched entitlements for: $app_path"
}

# Path to the INI file
ini_path="$HOME/Library/Preferences/Star Trek Fleet Command/launcher_settings.ini"
game_path=""

# Try to extract game path from INI
if [[ -f "$ini_path" ]]; then
    echo "📄 Reading launcher_settings.ini..."
    game_install_path=$(awk -F= '/^\[General\]/ { in_section=1; next } /^\[/ { in_section=0 } in_section && /^152033..GAME_PATH/ { print $2 }' "$ini_path" | xargs)
    if [[ -n "$game_install_path" && -d "$game_install_path" ]]; then
        echo "📁 Found game install path from INI: $game_install_path"
        game_path="$game_install_path"
    else
        echo "⚠️  Could not find valid GAME_PATH in launcher_settings.ini"
    fi
else
    echo "⚠️  launcher_settings.ini not found at $ini_path"
fi

# Possible app locations (first non-empty, valid one wins)
locations=(
    "$1"
    "$game_path"
    "$HOME/Library/Application Support"
    "$HOME/Applications"
    "/Applications"
)

echo "🔍 Searching for Star Trek Fleet Command.app..."

app_path=""
for raw_path in "${locations[@]}"; do
    # Skip blank entries
    if [[ -z "$raw_path" ]]; then
        continue
    fi

    # Normalize path (remove trailing /, collapse //)
    path=$(normalize_path "$raw_path")

    echo "  → Checking: $path"

    # Check both folder types
    if [[ -d "$path/Star Trek Fleet Command.app" ]]; then
        app_path="$path/Star Trek Fleet Command.app"
        echo "  ✅ Found app bundle at: $app_path"
        break
    elif [[ "$path" == *".app" && -d "$path" ]]; then
        app_path="$path"
        echo "  ✅ Found app bundle at: $app_path"
        break
    fi
done

if [[ -z "$app_path" ]]; then
    echo "❌ Star Trek Fleet Command.app not found!"
    exit 1
fi

# Locate the internal binary
binary_path="$app_path/Contents/MacOS/Star Trek Fleet Command"
if [[ -f "$binary_path" ]]; then
    echo "🚀 Found game binary at: $binary_path"
    patch_app_entitlements "$app_path"
else
    echo "❌ Game binary not found inside bundle at expected path:"
    echo "   $binary_path"
    exit 1
fi
