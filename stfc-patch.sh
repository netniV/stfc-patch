#!/bin/zsh --no-rcs

# Function to patch app entitlements
patch_app_entitlements() {
    local app_path="$1"
    
    #Temp file to keep existing entitlements and add new ones
    local entitlements_plist=/tmp/debug_entitlements.plist

    # Deactivated for now STFC doesnt set any entitlements so far 
    # echo "Grabbing entitlements from app..."
    # codesign -d --display --entitlements - "$app_path" --xml >> $entitlements_plist || { exit 1; }

    echo "Patch entitlements (if missing)..."
    /usr/libexec/PlistBuddy -c "add :com.apple.security.cs.disable-library-validation bool true" -x $entitlements_plist
    /usr/libexec/PlistBuddy -c "add :com.apple.security.cs.allow-unsigned-executable-memory bool true" -x $entitlements_plist
    /usr/libexec/PlistBuddy -c "add :com.apple.security.get-task-allow bool true" -x $entitlements_plist
    /usr/libexec/PlistBuddy -c "add :com.apple.security.cs.allow-dyld-environment-variables bool true" -x $entitlements_plist

    echo "Re-applying entitlements (if missing)..."
    codesign --force --options runtime --sign - --entitlements $entitlements_plist "$app_path" || { echo "codesign failed!"; }

    echo "Removing temporary plist..."
    rm $entitlements_plist
}

#STFC default location
# Find the location of Star Trek Fleet Command.app
app_path=$(/usr/bin/find /Applications -name "Star Trek Fleet Command.app" 2>/dev/null | head -n 1)

# If not found in Applications, search in user Applications
if [ -z "$app_path" ]; then
    app_path=$(/usr/bin/find ~/Applications -name "Star Trek Fleet Command.app" 2>/dev/null | head -n 1)
fi

# If not found in user Applications, search in user Library/Application Support
if [ -z "$app_path" ]; then
    app_path=$(/usr/bin/find ~/Library/Application\ Support -name "Star Trek Fleet Command.app" 2>/dev/null | head -n 1)
fi

if [ -z "$app_path" ]; then
    echo "Star Trek Fleet Command.app not found! Please make sure the app is installed."
    exit 1
fi

# Call the patching function
patch_app_entitlements "$app_path"