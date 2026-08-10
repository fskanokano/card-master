p="D:/code/godot/card-master/build-all.bat"
raw=open(p,"rb").read().decode("utf-8",errors="ignore")
a='if errorlevel 1 echo   WARNING: editor_settings patch reported an error\r\n  "$ks='
b='Write-Host \'  editor_settings-4.tres patched for Android export.\'"\r\necho.'
if a in raw:
    start=raw.index(a)
    end=raw.index(b, start)+len(b)
    new=raw[:start]+'if errorlevel 1 echo   WARNING: editor_settings patch reported an error\r\necho.'
    new+=raw[end:]
    open(p,"wb").write(new.encode("utf-8"))
    print(f"Removed {end-start} bytes")
else:
    print("Marker not found")
    print(repr(raw[raw.index("patch_editor")-80:raw.index("patch_editor")+300][:300]))
