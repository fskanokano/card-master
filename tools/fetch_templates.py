import urllib.request, os, zipfile, sys, shutil
TEMP = os.environ.get("TEMP", os.path.expanduser("~"))
APPDATA = os.environ.get("APPDATA", "")
DST = os.path.join(TEMP, "godot_templates.tpz")
EXTRACT_ROOT = os.path.join(TEMP, "godot_templates_extract")
DEST = os.path.join(APPDATA, "Godot", "export_templates", "4.7.1.stable.mono")

URLS = [
    "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_mono_export_templates.tpz",
    "https://downloads.tuxfamily.org/godotengine/4.7.1/mono/Godot_v4.7.1-stable_mono_export_templates.tpz",
]

def fetch():
    for url in URLS:
        print(f"Trying {url} ...", flush=True)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=90) as r, open(DST, "wb") as f:
                while True:
                    chunk = r.read(1 << 16)
                    if not chunk:
                        break
                    f.write(chunk)
            sig = open(DST, "rb").read(12)
            print(f"  Sig={' '.join(f'{b:02X}' for b in sig)} Size={os.path.getsize(DST)}")
            head = open(DST, "rb").read(200)
            print(f"  Head: {head[:80]!r}")
            if sig[:2] == b"PK":
                print("  ZIP detected")
                return True
            elif b"<!doctype" in sig.lower() or b"<html" in sig.lower():
                print("  HTML page, trying next URL")
                continue
            else:
                print("  Unknown header, assuming binary")
                return True
        except Exception as e:
            print(f"  FAIL {e}")
    return False

def extract():
    if os.path.isdir(EXTRACT_ROOT):
        shutil.rmtree(EXTRACT_ROOT, ignore_errors=True)
    os.makedirs(EXTRACT_ROOT, exist_ok=True)
    # .tpz is just a zip with different extension
    try:
        with zipfile.ZipFile(DST, "r") as z:
            print(f"Archive members: {z.namelist()[:10]}")
            z.extractall(EXTRACT_ROOT)
    except Exception as e:
        print(f"Zip extract failed: {e}")
        sys.exit(1)
    # Find templates dir inside extract
    inner = EXTRACT_ROOT
    candidates = [d for d in os.listdir(EXTRACT_ROOT) if os.path.isdir(os.path.join(EXTRACT_ROOT, d))]
    if candidates and os.path.isdir(os.path.join(EXTRACT_ROOT, candidates[0], "templates")):
        inner = os.path.join(EXTRACT_ROOT, candidates[0])
    elif os.path.isdir(os.path.join(EXTRACT_ROOT, "templates")):
        inner = EXTRACT_ROOT
    src_templates = os.path.join(inner, "templates")
    if not os.path.isdir(src_templates):
        # maybe files directly
        src_templates = inner
        if not any(f.endswith((".apk", ".exe")) or "android" in f.lower() for f in os.listdir(src_templates)):
            print(f"Cannot locate templates in {EXTRACT_ROOT}, contents: {os.listdir(EXTRACT_ROOT)[:20]}")
            if candidates:
                print(f"  inner {candidates[0]}: {os.listdir(os.path.join(EXTRACT_ROOT, candidates[0]))[:20]}")
            sys.exit(1)
    os.makedirs(DEST, exist_ok=True)
    copied = 0
    for name in os.listdir(src_templates):
        s = os.path.join(src_templates, name)
        d = os.path.join(DEST, name)
        if os.path.isfile(s):
            shutil.copy2(s, d)
            copied += 1
    print(f"Installed {copied} templates to {DEST}")
    for name in sorted(os.listdir(DEST))[:20]:
        print(f"  {name} {os.path.getsize(os.path.join(DEST, name))} bytes")

if __name__ == "__main__":
    if os.path.isdir(DEST) and any(os.listdir(DEST)):
        print(f"Templates already present at {DEST}: {os.listdir(DEST)[:10]}")
        sys.exit(0)
    if not fetch():
        print("All download attempts failed")
        sys.exit(2)
    extract()
