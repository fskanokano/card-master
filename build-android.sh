#!/bin/bash
# ============================================================================
# CardMaster -- Android Release Build (Linux)
#   Builds a signed Android APK for the CardMaster game.
# Outputs: artifact/android/CardMaster.apk
# Prereqs: Godot, Android SDK, JDK 17, debug keystore.
# ============================================================================
set -e

# ---- Configuration ----
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTIFACT_DIR="$PROJECT_DIR/artifact"
ARTIFACT_ANDROID="$ARTIFACT_DIR/android"
BUILD_DIR="$PROJECT_DIR/build"
KEYSTORE_DIR="$BUILD_DIR/keystore"
KEYSTORE="$KEYSTORE_DIR/debug.keystore"
KEYSTORE_PROPS="$KEYSTORE_DIR/debug.keystore.properties"

# Godot executable (look for godot in PATH or use default)
if command -v godot &> /dev/null; then
    GODOT_EXE="godot"
elif [ -f "/usr/local/bin/godot" ]; then
    GODOT_EXE="/usr/local/bin/godot"
else
    echo "ERROR: Godot not found. Please install Godot and ensure it is in PATH."
    exit 1
fi

# Android SDK (try to detect)
if [ -z "$ANDROID_HOME" ]; then
    # Try common locations
    if [ -d "$HOME/Android/Sdk" ]; then
        ANDROID_HOME="$HOME/Android/Sdk"
    elif [ -d "$HOME/android-sdk" ]; then
        ANDROID_HOME="$HOME/android-sdk"
    elif [ -d "/opt/android-sdk" ]; then
        ANDROID_HOME="/opt/android-sdk"
    else
        echo "WARNING: ANDROID_HOME not set. Android export may fail."
        ANDROID_HOME=""
    fi
fi

# Java
if [ -z "$JAVA_HOME" ]; then
    if [ -d "$HOME/jdk-17" ]; then
        JAVA_HOME="$HOME/jdk-17"
    elif [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
        JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
    else
        JAVA_HOME="$(dirname $(dirname $(readlink -f $(which java))))"
    fi
fi

# ---- Preflight checks ----
echo "============================================================"
echo " CardMaster -- Android Release Build"
echo " Project: $PROJECT_DIR"
echo "============================================================"
echo ""

echo "[1/6] Preflight checks..."
# Godot
if ! command -v $GODOT_EXE &> /dev/null; then
    echo "ERROR: Godot not found at '$GODOT_EXE'"
    exit 1
else
    echo "  Godot: $($GODOT_EXE --version) --OK"
fi

# Java
if [ ! -d "$JAVA_HOME" ]; then
    echo "ERROR: JAVA_HOME not found at '$JAVA_HOME'"
    exit 1
else
    echo "  Java: $(java -version 2>&1 | head -1) --OK"
fi

# Android SDK
if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
    echo "  Android SDK: $ANDROID_HOME --OK"
else
    echo "  WARNING: Android SDK not found. Android export may fail."
fi

# ---- Ensure debug keystore ----
echo ""
echo "[2/6] Ensuring Android debug keystore..."
mkdir -p "$KEYSTORE_DIR"
if [ ! -f "$KEYSTORE" ]; then
    echo "  Generating debug keystore at $KEYSTORE ..."
    keytool -genkeypair \
        -keystore "$KEYSTORE" \
        -alias cardmaster \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass cardmaster \
        -keypass cardmaster \
        -dname "CN=CardMaster, OU=Dev, O=CardMaster, L=City, S=State, C=US" \
        -noprompt
    echo "  Keystore generated."
else
    echo "  Keystore exists -- reuse."
fi

# ---- Ensure export templates ----
echo ""
echo "[3/6] Ensuring export templates..."
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/4.7.1.stable"
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "  Export templates not found. Downloading..."
    python3 "$PROJECT_DIR/tools/fetch_templates.py"
    if [ $? -ne 0 ]; then
        echo "  WARNING: Failed to fetch export templates. Android export may fail."
    fi
else
    echo "  Export templates found at $TEMPLATE_DIR"
fi

# ---- Set environment for Android export ----
if [ -n "$ANDROID_HOME" ]; then
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export ANDROID_HOME
    # Add build-tools and platform-tools to PATH
    if [ -d "$ANDROID_HOME/build-tools" ]; then
        LATEST_BUILD_TOOLS=$(ls -d "$ANDROID_HOME/build-tools"/*/ 2>/dev/null | sort -V | tail -1)
        if [ -n "$LATEST_BUILD_TOOLS" ]; then
            export PATH="$LATEST_BUILD_TOOLS:$ANDROID_HOME/platform-tools:$PATH"
        fi
    fi
fi
export JAVA_HOME

# ---- Headless reimport ----
echo ""
echo "[4/6] Reimporting project (headless)..."
$xvfb-run godot --headless --path "$PROJECT_DIR" --import 2>&1 || echo "  WARNING: Godot reimport reported an error -- continuing anyway"
echo "  Reimport done."

# ---- Export Android APK ----
mkdir -p "$ARTIFACT_DIR/android"
echo ""
echo "[5/6] Exporting Android APK..."
echo "  Exporting Android to $ARTIFACT_DIR/android/CardMaster.apk ..."
$xvfb-run godot --headless --path "$PROJECT_DIR" --export-release "Android" "$ARTIFACT_DIR/android/CardMaster.apk" 2>&1
if [ $? -eq 0 ] && [ -f "$ARTIFACT_DIR/android/CardMaster.apk" ]; then
    echo "  Android export OK."
else
    echo "ERROR: Android export failed."
    exit 1
fi

# ---- Sign and align APK ----
echo ""
echo "[5b/6] Verifying / signing Android APK..."
APK_PATH="$ARTIFACT_DIR/android/CardMaster.apk"
if [ ! -f "$APK_PATH" ]; then
    echo "  No APK to verify -- export may have failed."
    exit 1
fi

# Check if already signed
jarsigner -verify "$APK_PATH" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "  APK already signed -- skip signing."
else
    echo "  APK not signed -- signing with debug keystore..."
    jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
        -keystore "$KEYSTORE" -storepass cardmaster \
        "$APK_PATH" cardmaster
    if [ $? -ne 0 ]; then
        echo "ERROR: jarsigner failed"
        exit 1
    fi
    echo "  APK signed."
    # Zipalign
    if [ -n "$ANDROID_HOME" ]; then
        for ver in 36.0.0 35.0.0 34.0.0; do
            ZIPALIGN="$ANDROID_HOME/build-tools/$ver/zipalign"
            if [ -x "$ZIPALIGN" ]; then
                echo "  Zipaligning with build-tools $ver ..."
                $ZIPALIGN -f -v 4 "$APK_PATH" "$APK_PATH-aligned.apk" > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    mv -f "$APK_PATH-aligned.apk" "$APK_PATH"
                fi
                break
            fi
        done
    fi
fi

# Final APK size
APK_SIZE=$(stat -c%s "$APK_PATH" 2>/dev/null || stat -f%z "$APK_PATH" 2>/dev/null)
echo "  APK size: $APK_SIZE bytes"

echo ""
echo "============================================================"
echo " Build finished. Android APK: $APK_PATH"
echo "============================================================"
