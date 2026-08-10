@echo off
setlocal EnableDelayedExpansion
REM ============================================================================
REM CardMaster --One-click dual-platform build
REM   Windows: CardMaster.exe (+ .pck) and WiX MSI installer
REM   Android: Signed APK installable on device
REM Outputs: artifact\windows\  and  artifact\android\
REM Prereqs: Godot, Android SDK, JDK 17, WiX Toolset --paths from
REM          basic environment file (MDC) or env vars / defaults below.
REM All messages are in English as required.
REM ============================================================================
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%"
REM Strip trailing backslash for Godot
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
REM ---- Resolve tool paths (MDC values as defaults; env overrides win) ----
if not defined GODOT_EXE set "GODOT_EXE=D:\software\Godot\Godot_v4.7.1-stable_mono_win64.exe"
if not defined GODOT_CONSOLE set "GODOT_CONSOLE=D:\software\Godot\Godot_v4.7.1-stable_mono_win64_console.exe"
if not defined ANDROID_SDK set "ANDROID_SDK=D:\software\AndroidSDK"
set "JAVA_HOME=D:\software\jdk-17"
if not defined WIX_DIR set "WIX_DIR=D:\software\wix"
set "ARTIFACT_DIR=%PROJECT_DIR%\artifact"
set "ARTIFACT_WIN=%ARTIFACT_DIR%\windows"
set "ARTIFACT_ANDROID=%ARTIFACT_DIR%\android"
set "BUILD_DIR=%PROJECT_DIR%\build"
set "WIX_SRC=%BUILD_DIR%\wix\Product.wxs"
set "WIX_OBJ=%BUILD_DIR%\wix\obj"
set "KEYSTORE=%BUILD_DIR%\keystore\debug.keystore"
set "KEYSTORE_PROPS=%BUILD_DIR%\keystore\debug.keystore.properties"
set "FAILED=0"
echo ============================================================
echo  CardMaster --Dual-Platform Build
echo  Project: %PROJECT_DIR%
echo ============================================================
echo.
REM ---- Preflight checks -----------------------------------------------------
echo [1/6] Preflight checks...
if not exist "%GODOT_EXE%" (
  if exist "%GODOT_CONSOLE%" set "GODOT_EXE=%GODOT_CONSOLE%"
)
if not exist "%GODOT_EXE%" (
  echo   ERROR: Godot not found at "%GODOT_EXE%"
  echo          Set GODOT_EXE env var or edit build-all.bat
  set "FAILED=1"
  goto :summary
) else (
  echo   Godot: "%GODOT_EXE%" --OK
)
if not exist "%JAVA_HOME%\bin\java.exe" (
  echo   ERROR: JDK not found at "%JAVA_HOME%"
  echo          Set JAVA_HOME env var
  set "FAILED=1"
  goto :summary
) else (
  echo   JDK: "%JAVA_HOME%" --OK
)
if not exist "%ANDROID_SDK%\platform-tools\adb.exe" (
  echo   WARNING: Android SDK not found at "%ANDROID_SDK%" --Android export may fail
) else (
  echo   Android SDK: "%ANDROID_SDK%" --OK
)
if not exist "%WIX_DIR%\candle.exe" (
  echo   WARNING: WiX not found at "%WIX_DIR%" --MSI packaging will be skipped
  set "WIX_AVAILABLE=0"
) else (
  echo   WiX: "%WIX_DIR%" --OK
  set "WIX_AVAILABLE=1"
)
REM Ensure Godot editor settings know about Android SDK / JDK for export
echo   Configuring Godot editor settings for Android export...
set "EDITOR_SETTINGS=%APPDATA%\Godot\editor_settings-4.tres"
if exist "%EDITOR_SETTINGS%" (
  echo   Editor settings found at "%EDITOR_SETTINGS%"
) else (
  echo   No editor_settings-4.tres yet --Godot will create it on first run
)
REM Write/merge export-related editor settings via a temp GDScript is not needed;
REM Godot 4 Android export reads ANDROID_HOME / ANDROID_SDK_ROOT and JAVA_HOME from env.
set "ANDROID_HOME=%ANDROID_SDK%"
set "ANDROID_SDK_ROOT=%ANDROID_SDK%"
set "PATH=%JAVA_HOME%\bin;%ANDROID_SDK%\platform-tools;%ANDROID_SDK%\build-tools\36.0.0;%ANDROID_SDK%\build-tools\35.0.0;%ANDROID_SDK%\build-tools\34.0.0;%PATH%"
mkdir "%ARTIFACT_WIN%" 2>nul
mkdir "%ARTIFACT_ANDROID%" 2>nul
mkdir "%WIX_OBJ%" 2>nul
mkdir "%BUILD_DIR%\keystore" 2>nul
echo   Preflight done.
echo.
REM ---- Ensure debug keystore -----------------------------------------------
echo [2/6] Ensuring Android debug keystore...
if not exist "%KEYSTORE%" (
  echo   Generating debug keystore at "%KEYSTORE%" ...
  "%JAVA_HOME%\bin\keytool.exe" -genkeypair -keystore "%KEYSTORE%" -alias cardmaster -keyalg RSA -keysize 2048 -validity 10000 -storepass cardmaster -keypass cardmaster -dname "CN=CardMaster, OU=Dev, O=CardMaster, L=City, S=State, C=US" -noprompt
  if errorlevel 1 (
    echo   ERROR: keytool failed to generate keystore
    set "FAILED=1"
    goto :summary
  )
  echo   Keystore generated.
) else (
  echo   Keystore exists --reuse.
)
echo.
REM ---- Ensure export templates ---------------------------------------------
echo [3a/6] Ensuring export templates...
if not exist "%APPDATA%\Godot\export_templates\4.7.1.stable.mono\windows_release_x86_64.exe" (
  echo   Export templates missing -- fetching...
  python "%PROJECT_DIR%\tools\fetch_templates.py" 2>&1
  if errorlevel 1 (
    echo   WARNING: Failed to fetch export templates -- exports will fail
    echo   Manually download Godot_v4.7.1-stable_mono_export_templates.tpz and extract to %APPDATA%\Godot\export_templates\4.7.1.stable.mono\
  )
)
echo [3b/6] Configuring Android signing for export...
REM Patch editor_settings-4.tres so Godot headless export can locate SDK/JDK/keystore.
if not exist "%APPDATA%\Godot" mkdir "%APPDATA%\Godot" 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%\tools\patch_editor_settings.ps1" 2>&1
if errorlevel 1 echo   WARNING: editor_settings patch reported an error
echo.
REM ---- Headless reimport (ensures .godot cache exists for exports) ---------
echo [4/6] Reimporting project (headless)...
"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --import 2>&1
if errorlevel 1 (
  echo   WARNING: Godot reimport reported an error --continuing anyway
)
echo   Reimport done.
echo.
REM ---- Export Windows + Android ---------------------------------------------
echo [5/6] Exporting Windows Desktop and Android...
echo   Exporting Windows Desktop to "%ARTIFACT_WIN%\CardMaster.exe" ...
"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --export-release "Windows Desktop" "%ARTIFACT_WIN%\CardMaster.exe" 2>&1
if errorlevel 1 (
  echo   ERROR: Windows export failed
  set "FAILED=1"
) else (
  if exist "%ARTIFACT_WIN%\CardMaster.exe" (
    echo   Windows export OK: "%ARTIFACT_WIN%\CardMaster.exe"
    if exist "%ARTIFACT_WIN%\CardMaster.pck" echo   Windows PCK: "%ARTIFACT_WIN%\CardMaster.pck"
  ) else (
    echo   ERROR: Windows export produced no file
    set "FAILED=1"
  )
)
echo.
echo   Exporting Android to "%ARTIFACT_ANDROID%\CardMaster.apk" ...
"%GODOT_EXE%" --headless --path "%PROJECT_DIR%" --export-release "Android" "%ARTIFACT_ANDROID%\CardMaster.apk" 2>&1
if errorlevel 1 (
  echo   ERROR: Android export failed
  set "FAILED=1"
) else (
  if exist "%ARTIFACT_ANDROID%\CardMaster.apk" (
    echo   Android export OK: "%ARTIFACT_ANDROID%\CardMaster.apk"
  ) else (
    echo   ERROR: Android export produced no file
    set "FAILED=1"
  )
)
echo.
echo [5b/6] Verifying / signing Android APK...
if not exist "%ARTIFACT_ANDROID%\CardMaster.apk" goto :no_apk
"%JAVA_HOME%\bin\jarsigner.exe" -verify "%ARTIFACT_ANDROID%\CardMaster.apk" >nul 2>&1
if not errorlevel 1 goto :apk_already_signed
echo   APK not signed -- signing with debug keystore...
"%JAVA_HOME%\bin\jarsigner.exe" -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore "%KEYSTORE%" -storepass cardmaster "%ARTIFACT_ANDROID%\CardMaster.apk" cardmaster
if errorlevel 1 (
  echo   ERROR: jarsigner failed
  set "FAILED=1"
) else (
  echo   APK signed.
)
for %%B in (36.0.0 35.0.0 34.0.0) do (
  if exist "%ANDROID_SDK%\build-tools\%%B\zipalign.exe" (
    echo   Zipaligning with build-tools %%B ...
    "%ANDROID_SDK%\build-tools\%%B\zipalign.exe" -f -v 4 "%ARTIFACT_ANDROID%\CardMaster.apk" "%ARTIFACT_ANDROID%\CardMaster-aligned.apk" >nul 2>&1
    if not errorlevel 1 move /Y "%ARTIFACT_ANDROID%\CardMaster-aligned.apk" "%ARTIFACT_ANDROID%\CardMaster.apk" >nul
    goto :after_zipalign
  )
)
:after_zipalign
goto :apk_done
:apk_already_signed
echo   APK already signed -- skip.
for %%B in (36.0.0 35.0.0 34.0.0) do (
  if exist "%ANDROID_SDK%\build-tools\%%B\zipalign.exe" (
    "%ANDROID_SDK%\build-tools\%%B\zipalign.exe" -c -v 4 "%ARTIFACT_ANDROID%\CardMaster.apk" >nul 2>&1
    if errorlevel 1 (
      echo   Aligning APK...
      "%ANDROID_SDK%\build-tools\%%B\zipalign.exe" -f -v 4 "%ARTIFACT_ANDROID%\CardMaster.apk" "%ARTIFACT_ANDROID%\CardMaster-aligned.apk" >nul 2>&1
      if not errorlevel 1 move /Y "%ARTIFACT_ANDROID%\CardMaster-aligned.apk" "%ARTIFACT_ANDROID%\CardMaster.apk" >nul
    )
    goto :after_verify_zipalign
  )
)
:after_verify_zipalign
goto :apk_done
:no_apk
echo   No APK to verify -- export may have failed.
:apk_done
for %%F in ("%ARTIFACT_ANDROID%\CardMaster.apk") do if exist "%%F" echo   APK size: %%~zF bytes
echo.
REM ---- WiX MSI packaging -----------------------------------------------------
echo [6/6] Building WiX installer (MSI)...
if "%WIX_AVAILABLE%"=="0" (
  echo   WiX not available -- skipping MSI. Windows exe is still in artifact\windows\
  goto :summary
)
if not exist "%ARTIFACT_WIN%\CardMaster.exe" (
  echo   No Windows exe found -- skipping MSI.
  goto :summary
)
if not exist "%WIX_SRC%" (
  echo   WiX source not found at "%WIX_SRC%" -- skipping.
  goto :summary
)
echo   Compiling WiX source...
"%WIX_DIR%\candle.exe" -nologo -out "%WIX_OBJ%\Product.wixobj" "%WIX_SRC%" -dSourceDir="%ARTIFACT_WIN%" -dProjectDir="%PROJECT_DIR%" -ext WixUIExtension 2>&1
if errorlevel 1 (
  echo   ERROR: candle failed
  set "FAILED=1"
  goto :summary
)
echo   Linking MSI...
"%WIX_DIR%\light.exe" -nologo -out "%ARTIFACT_WIN%\CardMaster-Setup.msi" "%WIX_OBJ%\Product.wixobj" -ext WixUIExtension -cultures:en-us 2>&1
if errorlevel 1 (
  echo   ERROR: light failed
  set "FAILED=1"
  goto :summary
)
if exist "%ARTIFACT_WIN%\CardMaster-Setup.msi" (
  for %%F in ("%ARTIFACT_WIN%\CardMaster-Setup.msi") do echo   MSI OK: %%F ^(%%~zF bytes^)
  del /Q "%ARTIFACT_WIN%\*.wixpdb" 2>nul
) else (
  echo   ERROR: MSI not produced
  set "FAILED=1"
)
:summary
echo.
echo ============================================================
if "%FAILED%"=="0" (
  echo  Build finished -- all artifacts in "%ARTIFACT_DIR%"
) else (
  echo  Build finished WITH ERRORS -- check messages above
)
echo  Windows: "%ARTIFACT_WIN%\CardMaster.exe" (+ .pck) and CardMaster-Setup.msi
echo  Android: "%ARTIFACT_ANDROID%\CardMaster.apk" (signed, zipaligned)
echo ============================================================
dir /B "%ARTIFACT_WIN%" 2>nul
dir /B "%ARTIFACT_ANDROID%" 2>nul
echo.
if "%FAILED%"=="0" (
  exit /B 0
) else (
  exit /B 1
)
