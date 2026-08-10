import pathlib
p = pathlib.Path("D:/code/godot/card-master/build-all.bat")
t = p.read_text(encoding="utf-8", errors="ignore")
# 1) Fix corrupted -- / --- lines: replace mojibake with ASCII --
t2 = t.replace("\u2014", "--").replace("\u2013", "--")
# 2) Fix JAVA_HOME hijack: force JDK 17, ignore system JAVA_HOME
old_java = 'if not defined JAVA_HOME set "JAVA_HOME=D:\\software\\jdk-17"'
new_java = 'set "JAVA_HOME=D:\\software\\jdk-17"'
if old_java in t2:
    t2 = t2.replace(old_java, new_java)
# 3) Replace fragile PowerShell injection with external helper script
old_ps = (
    'powershell -NoProfile -ExecutionPolicy Bypass -Command ^\n'
    '  "$ks=\'%KEYSTORE%\';" ^\n'
    '  "$ks=$ks -replace \'\\\\\\\\\',\'/\';" ^\n'
    '  "$sdk=\'%ANDROID_SDK%\';" ^\n'
    '  "$sdk=$sdk -replace \'\\\\\\\\\',\'/\';" ^\n'
    '  "$jdk=\'%JAVA_HOME%\';" ^\n'
    '  "$jdk=$jdk -replace \'\\\\\\\\\',\'/\';" ^\n'
    '  "$ed=$env:APPDATA + \'\\Godot\\editor_settings-4.tres\';" ^\n'
    '  "if(!(Test-Path $ed)){ Set-Content $ed \\"\\" -Encoding UTF8 };" ^\n'
    '  "$t=Get-Content $ed -Raw -Encoding UTF8;" ^\n'
    '  "function upsert($key,$val){ $pat=\'(?m)^\'+[regex]::Escape($key)+\'\\s*=.*\\r?\\n\'; $line=$key+\'=\\"\'+\n'
)
# More robust: replace whole [3/6] block
old_block = (
    'REM ---- Configure Godot Android signing in export_presets.cfg ---------------\n'
    'echo [3/6] Configuring Android signing for export...\n'
    'REM Patch editor_settings-4.tres so Godot headless export can locate SDK/JDK/keystore.\n'
    'set "EDITOR_SETTINGS=%APPDATA%\\Godot\\editor_settings-4.tres"\n'
    'if not exist "%APPDATA%\\Godot" mkdir "%APPDATA%\\Godot" 2>nul\n'
    'powershell -NoProfile -ExecutionPolicy Bypass -Command ^\n'
)
if old_block in t2:
    new_block = (
        'REM ---- Ensure export templates ---------------------------------------------\n'
        'echo [3a/6] Ensuring export templates...\n'
        'if not exist "%APPDATA%\\Godot\\export_templates\\4.7.1.stable.mono\\windows_release_x86_64.exe" (\n'
        '  echo   Export templates missing -- fetching...\n'
        '  python "%PROJECT_DIR%\\tools\\fetch_templates.py" 2>&1\n'
        '  if errorlevel 1 (\n'
        '    echo   WARNING: Failed to fetch export templates -- exports will fail\n'
        '    echo   Manually download Godot_v4.7.1-stable_mono_export_templates.tpz and extract to %APPDATA%\\Godot\\export_templates\\4.7.1.stable.mono\\\n'
        '  )\n'
        ')\n'
        'echo [3b/6] Configuring Android signing for export...\n'
        'REM Patch editor_settings-4.tres so Godot headless export can locate SDK/JDK/keystore.\n'
        'if not exist "%APPDATA%\\Godot" mkdir "%APPDATA%\\Godot" 2>nul\n'
        'powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_DIR%\\tools\\patch_editor_settings.ps1" 2>&1\n'
        'if errorlevel 1 echo   WARNING: editor_settings patch reported an error\n'
    )
    t2 = t2.replace(old_block, new_block)
    # remove leftover 6 powershell continuation lines + Set-Content line
    lines = t2.split("\r\n")
    out = []
    skip_until_echo = False
    for i, line in enumerate(lines):
        if skip_until_echo:
            if line.strip() == "echo.":
                skip_until_echo = False
                out.append(line)
            # else skip
            continue
        out.append(line)
        if 'patch_editor_settings.ps1' in line:
            # next lines are the old continuation; skip until next echo.
            # We already replaced the header; the old tail lines still remain
            # Detect by checking next line starts with '  "$ks='
            if i + 1 < len(lines) and '"$ks=' in lines[i + 1]:
                skip_until_echo = True
    t2 = "\r\n".join(out)
# 4) Fix WixVariable relative path (License.rtf)
t2 = t2.replace('$(var.SourceDir)\\..\\build\\wix\\License.rtf', '$(var.ProjectDir)\\build\\wix\\License.rtf')
# Also ensure -dProjectDir for WiX
if '-dSourceDir="%ARTIFACT_WIN%"' in t2 and '-dProjectDir=' not in t2:
    t2 = t2.replace('-dSourceDir="%ARTIFACT_WIN%"', '-dSourceDir="%ARTIFACT_WIN%" -dProjectDir="%PROJECT_DIR%"')
# 5) Normalize to CRLF
t2 = t2.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "\r\n")
p.write_text(t2, encoding="utf-8")
print("Patched build-all.bat")
# Also report
for needle in ["JAVA_HOME=D:\\software\\jdk-17", "fetch_templates.py", "patch_editor_settings.ps1", "-dProjectDir"]:
    print(f"  {'OK' if needle in t2 else 'MISSING'}: {needle}")
