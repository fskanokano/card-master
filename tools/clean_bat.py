p = "D:/code/godot/card-master/build-all.bat"
raw = open(p, "rb").read().decode("utf-8", errors="ignore")
# Remove the leftover 11-line PowerShell injection that starts with 2-space indent + "$ks="
lines = raw.split("\r\n")
out = []
i = 0
while i < len(lines):
    if i >= 1 and lines[i].startswith('  "$ks=') and 'patch_editor_settings.ps1' in lines[i-1]:
        # skip until line containing Set-Content
        while i < len(lines) and "Set-Content $ed $t" not in lines[i]:
            i += 1
        i += 1  # skip the Set-Content line itself
        # also skip if next is blank echo.
        continue
    out.append(lines[i])
    i += 1
open(p, "wb").write("\r\n".join(out).encode("utf-8"))
print(f"Cleaned: {len(lines)} -> {len(out)} lines")
for s in ["patch_editor_settings.ps1", "$ks='", "-dProjectDir"]:
    print(f"  {'OK' if s in open(p, encoding='utf-8').read() else 'MISSING'} {s}")
print(f"  leftover $ks: {'FOUND (bad)' if '$ks=' in open(p, encoding='utf-8').read().split('patch_editor_settings')[1] else 'none (good)'}")
