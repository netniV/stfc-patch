#!/usr/bin/env zsh

# Ensure zsh doesn't load user or global rc files
setopt NO_RCS

# Function to handle errors
handle_error() {
    local exit_code=$1
    local message="$2"
    if [ $exit_code -ne 0 ]; then
        echo "Error ($exit_code): $message"
        exit $exit_code
    fi
}

# Function to patch app entitlements
patch_app_entitlements() {
    local app_path="$1"
    local entitlements_plist=/tmp/debug_entitlements.plist

    # Deactivated for now - STFC doesn't set any entitlements so far 
    # echo "Grabbing entitlements from app..."
    # codesign -d --display --entitlements - "$app_path" --xml >> $entitlements_plist
    # handle_error $? "Failed to grab entitlements from $app_path"

    echo "Patching entitlements (if missing)..."
    /usr/libexec/PlistBuddy -c "add :com.apple.security.cs.disable-library-validation bool true" -x $entitlements_plist
    handle_error $? "Failed to add disable-library-validation"

    /usr/libexec/PlistBuddy -c "add :com.apple.security.cs.allow-unsigned-executable-memory bool true" -x $entitlements_plist
    handle_error $? "Failed to add allow-unsigned-executable-memory"

    /usr/libexec/PlistBuddy -c "add :com.apple.security.get-task-allow bool true" -x $entitlements_plist
    handle_error $? "Failed to add get-task-allow"

    /usr/libexec/PlistBuddy -c "add :com.apple.security.cs.allow-dyld-environment-variables bool true" -x $entitlements_plist
    handle_error $? "Failed to add allow-dyld-environment-variables"

    echo "Re-applying entitlements..."
    codesign --force --options runtime --sign - --entitlements $entitlements_plist "$app_path"
    handle_error $? "codesign failed on $app_path"

    echo "Removing temporary plist..."
    rm $entitlements_plist
    handle_error $? "Failed to remove temporary plist $entitlements_plist"
}

# List of potential app locations
locations=(
    "$1"
    "$HOME/Library/Application Support"
    "$HOME/Applications"
    "/Applications"
)

app_path=""

# Find the first existing app path
for path in "${locations[@]}"; do
    if [ -d "$path" ]; then
        if [ -f "$path/Star Trek Fleet Command.app" ]; then
            app_path="$path"
            break
        fi
    fi
done

if [ -z "$app_path" ]; then
    echo "Star Trek Fleet Command.app not found! Please make sure the app is installed."
    exit 1
fi

echo "Found app at: $app_path"

# Call the patching function
patch_app_entitlements "$app_path"
