# Patch %APPDATA%\Godot\editor_settings-4.tres so headless export can locate SDK/JDK/keystore.
$ErrorActionPreference = "Stop"
$ks = $env:KEYSTORE
if (-not $ks) { $ks = "$env:PROJECT_DIR\build\keystore\debug.keystore" }
if (-not $env:ANDROID_SDK) { $env:ANDROID_SDK = "D:\software\AndroidSDK" }
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = "D:\software\jdk-17" }
$sdk = $env:ANDROID_SDK -replace '\\','/'
$jdk = $env:JAVA_HOME -replace '\\','/'
$ks  = $ks -replace '\\','/'
$ed = Join-Path $env:APPDATA "Godot\editor_settings-4.tres"
if (-not (Test-Path $ed)) { Set-Content $ed "" -Encoding UTF8 }
$t = Get-Content $ed -Raw -Encoding UTF8
if (-not $t) { $t = "" }
function upsert($key,$val){
  $pat = '(?m)^' + [regex]::Escape($key) + '\s*=.*\r?\n'
  $line = $key + '="' + $val + '"' + "`r`n"
  if ($script:t -match $pat){ $script:t = [regex]::Replace($script:t, $pat, $line) } else { $script:t += $line }
}
upsert 'export/android/android_sdk_path' $sdk
upsert 'export/android/debug_keystore' $ks
upsert 'export/android/debug_keystore_user' ''
upsert 'export/android/debug_keystore_pass' 'cardmaster'
upsert 'export/android/force_system_user' 'false'
upsert 'export/android/shutdown_adb_on_exit' 'true'
Set-Content $ed $t -Encoding UTF8
Write-Host "  editor_settings-4.tres patched for Android export."
