---
name: app-release
description: Package and distribute Python desktop applications — AppImage, PyInstaller, Docker, and simple install-script distributions. Use this skill whenever the user asks to build a distributable app, create an AppImage, package a Python GUI, make an installer, ship a desktop tool, create a portable binary, or set up a "one-click run" distribution for a Python project. Also use when debugging distribution issues (missing .so, FUSE errors, bloated builds, GUI not starting on remote machines).
---

# App Release — Packaging & Distribution for Python Desktop Apps

## When to use

- "Build me an AppImage for this app"
- "How do I ship this so someone can just double-click and run it?"
- "My PyInstaller binary crashes on another machine"
- "Set up an install script so a user can get this running in one command"
- "Make a Docker image for this CLI tool"
- "The AppImage is 2 GB — why so big?"
- "FUSE error when extracting AppImage"
- "GUI won't start in the AppImage / headless environment"

## Core principles

1. **Prefer the simplest format that works.** A venv + `install_and_run.sh` is easier to maintain than an AppImage, which is easier than PyInstaller. Only use the heavier format when the target user cannot install Python or run a shell script.
2. **Bundle the interpreter, not the system Python.** The target machine's Python version, site-packages, and system libs are unpredictable. A self-contained venv (copied into AppDir or frozen via PyInstaller) eliminates the "works on my machine" class of bugs.
3. **Always test on a clean machine (or at minimum, a minimal Docker container).** The first run on the build machine has cached state, FUSE modules, and system libs that mask real failures.
4. **Strip aggressively before packaging.** `torch/test/`, `torch/bin/test_*`, `__pycache__/`, `*.pyc`, `tests/`, `.git/`, `.venv/` — every one of these adds bloat or causes breakage.

## How to do it

### 1. Choose the distribution format

| Format | Best for | Target user | Size |
|---|---|---|---|
| `install_and_run.sh` + zip | Internal team, tech-savvy users | Anyone with `bash` + `python3` | Small (source only) |
| AppImage | Desktop Linux, double-click UX | Non-technical Linux users | 200 MB – 2 GB |
| PyInstaller (onefile) | Cross-platform single-file, CLI or simple GUI | Any OS | 100 MB – 1 GB |
| Docker image | Server / headless / reproducible env | DevOps, any OS | 300 MB – 5 GB |
| PyInstaller (onedir) | Faster startup than onefile, Linux desktop | Linux users | 200 MB – 2 GB |

**Decision heuristic:**
- Only your team uses it → `install_and_run.sh` + zip
- Need it to "just work" on a colleague's Linux desktop → AppImage
- Need it to run on macOS/Windows too → PyInstaller
- It's a service / runs headless / needs exact reproducibility → Docker

---

### 2. Simple install-script distribution (lightest weight)

Create `install_and_run.sh` at the project root:

```bash
#!/bin/bash
# install_and_run.sh — one-command setup for <App Name>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Check prerequisites
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found. Install it first."
  exit 1
fi

# 2. Create venv (idempotent)
VENV_DIR="$SCRIPT_DIR/.venv"
[[ -f "$VENV_DIR/bin/python3" ]] || python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# 3. Install dependencies
pip install --upgrade pip --quiet
pip install -r "$SCRIPT_DIR/requirements.txt"

# 4. Run
exec python "$SCRIPT_DIR/main.py" "$@"
```

`chmod +x install_and_run.sh`

Package it:
```bash
zip -r app_dist.zip . \
  -x "*.git*" "*.venv*" "__pycache__*" "*.pyc" \
     ".claude*" ".superpowers*" "build*" "dist*" "*.egg-info*"
```

**Why this works:** the user only needs `python3` and `bash`. The venv isolates everything. No compilation, no FUSE, no AppImageKit.

---

### 3. AppImage (Linux desktop, double-click)

Use the build pattern from the Financial Terminal (`build_appimage.sh`). The key steps:

1. **Create a clean venv** in a temp build directory (never the dev venv).
2. **Build AppDir** — the on-disk layout AppImageKit packages:
   ```
   AppDir/
   ├── AppRun                          ← entry point (bash script)
   ├── myapp.desktop                   ← .desktop file (at root for appimagetool)
   ├── myapp.png                       ← icon (at root for appimagetool)
   └── usr/
       ├── bin/python3                 ← interpreter
       ├── lib/python3.X/             ← stdlib + site-packages
       └── share/myapp/               ← your app source
   ```
3. **Bundle Python + site-packages:**
   ```bash
   cp "$VENV_DIR/bin/python3" "$APPDIR/usr/bin/python3"
   cp -r "$VENV_DIR/lib/python3.X" "$APPDIR/usr/lib/"
   cp -r "$VENV_DIR/lib/tcl8.6" "$APPDIR/usr/lib/" 2>/dev/null || true
   cp -r "$VENV_DIR/lib/tk8.6"  "$APPDIR/usr/lib/" 2>/dev/null || true
   ```
4. **Write `AppRun`:**
   ```bash
   #!/bin/bash
   APPDIR="$(dirname "$(readlink -f "$0")")"
   export LD_LIBRARY_PATH="$APPDIR/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
   export PYTHONPATH="$APPDIR/usr/lib/python3.12/site-packages${PYTHONPATH:+:$PYTHONPATH}"
   exec "$APPDIR/usr/bin/python3" "$APPDIR/usr/share/myapp/main.py" "$@"
   ```
5. **Strip torch test binaries before packaging** (if torch is a dependency):
   ```bash
   rm -rf "$APPDIR/usr/lib/python3.12/site-packages/torch/test"
   rm -rf "$APPDIR/usr/lib/python3.12/site-packages/torch/bin/test_*"
   ```
6. **Deploy missing .so files** with linuxdeploy (optional but recommended):
   ```bash
   ./linuxdeploy-x86_64.AppImage --appdir "$APPDIR" -e "$APPDIR/usr/bin/python3"
   ```
7. **Build with `APPIMAGE_EXTRACT_AND_RUN=1`** so FUSE is not required on the target machine:
   ```bash
   export ZSYNC=1
   export APPIMAGE_EXTRACT_AND_RUN=1
   ./appimagetool-x86_64.AppImage "$APPDIR" myapp-x86_64.AppImage
   ```

**Critical AppImage gotchas:**
- `APPIMAGE_EXTRACT_AND_RUN=1` — without this, target machines without FUSE get a "FUSE not found" error.
- The `.desktop` and `.png` files must be at the AppDir root, not only in `usr/share/`.
- `PYTHONPATH` in `AppRun` must point to the exact Python version's site-packages (e.g. `python3.12`, not just `python3`).
- `tcl8.6` / `tk8.6` libs must be copied separately if the app uses tkinter.
- Test on a machine **without** the system Python matching the build Python.

---

### 4. PyInstaller (cross-platform single file or dir)

```bash
pip install pyinstaller
# Single-file (slower startup, simpler distribution):
pyinstaller --onefile --name myapp \
  --add-data "assets/:assets" \
  --add-data "config.py:." \
  main.py

# Or one-dir (faster startup, more reliable with GUIs):
pyinstaller --onedir --name myapp \
  --add-data "assets/:assets" \
  main.py
```

**PyInstaller gotchas:**
- Dynamic imports (e.g. `importlib`, `pkg_resources`) may be silently dropped. Add `--hidden-import=module_name`.
- Data files must use `sys._MEIPASS` at runtime, not relative paths:
  ```python
  import sys, os
  base = sys._MEIPASS if hasattr(sys, '_MEIPASS') else os.path.dirname(os.path.abspath(__file__))
  ```
- Tkinter apps: PyInstaller handles this, but test — some systems need `--collect-all tkinter`.
- The resulting binary is architecture-specific. Build on the target architecture or use a matching CI runner.

---

### 5. Docker (reproducible, headless, or server)

```dockerfile
# Minimal Python + app
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENTRYPOINT ["python", "main.py"]
```

For GUI apps, add a display layer:
```dockerfile
# GUI via VNC
FROM python:3.12-slim
RUN apt-get update && apt-get install -y x11vnc xvfb && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["Xvfb", ":99", "-screen", "0", "1920x1080x24", "&", "x11vnc", "-display", ":99", "-nopw", "-forever", "-rfbport", "5900", "&", "python", "main.py"]
```

---

### 6. Add a `launch.sh` that picks the best format

The Financial Terminal pattern is good: try AppImage first, fall back to venv:

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try AppImage
APPIMAGE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "myapp-*.AppImage" -type f 2>/dev/null | head -1)
[[ -n "$APPIMAGE" ]] && exec "$APPIMAGE" "$@"

# Fallback: venv
VENV="$SCRIPT_DIR/.venv"
[[ -f "$VENV/bin/python3" ]] || python3 -m venv "$VENV"
source "$VENV/bin/activate"
pip install -r "$SCRIPT_DIR/requirements.txt" --quiet
exec python "$SCRIPT_DIR/main.py" "$@"
```

This way, the same project works both "dev mode" (venv) and "dist mode" (AppImage) with one entry point.

---

### 7. Strip & bloat-check before release

Before building, verify what's actually needed:

```bash
# See what's in requirements.txt that's heavy
pip install -r requirements.txt --dry-run 2>&1 | grep -i "will install" | sort -k4 -rn | head -10

# After building, check size breakdown (AppImage):
# Extract to /tmp and look at the big dirs:
./myapp.AppImage --appimage-internal-extract-only
du -sh /tmp/myapp.AppDir/usr/lib/python3.12/site-packages/*/
```

Common bloat sources:
| Package | Typical size | Fix |
|---|---|---|
| `torch` | 2 GB+ | Strip `torch/test`, `torch/bin/test_*`, `torch/lib/libtorch_cuda.so` if CPU-only |
| `tensorflow` | 800 MB+ | Use `tensorflow-cpu` instead |
| `numpy` + `pandas` + `scipy` | ~200 MB | Unavoidable, but don't also bundle `pyarrow` + `duckdb` if unused |
| `pyinstaller` onefile | 50 MB overhead | Use onedir if startup time matters |
| `*.pyc` files | Varies | `find . -name "*.pyc" -delete` before packaging |

---

### 8. Test checklist (run before shipping)

- [ ] `./myapp-x86_64.AppImage` runs on a machine with **no** Python installed (or a different Python version)
- [ ] GUI window opens (not just "started, no window")
- [ ] All API keys / config files are read from the expected location (not the build machine's paths)
- [ ] `requirements.txt` has no packages that fail to install on the target (e.g. `python-picache`)
- [ ] No absolute paths hardcoded (use `__file__` or `sys.argv[0]`-relative paths)
- [ ] Log output goes to a writable location (not `/root/` or a build-only path)
- [ ] File size is under the threshold you'll actually distribute over (e.g. < 500 MB for email, < 5 GB for USB)

---

### 9. Version the build

Tag or name the output with the version:

```bash
VERSION="1.0.0"
APPIMAGE_NAME="myapp-${ARCH}-v${VERSION}.AppImage"
```

Use `git describe --tags` if the project is version-controlled:
```bash
VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo dev)"
```

---

## Examples

**Example 1:**
Input: "I need to ship this backtesting GUI to my trading partner. They use Ubuntu, they're not a developer."
Output: AppImage. Build with `APPIMAGE_EXTRACT_AND_RUN=1`, strip torch test dirs, name it `myapp-x86_64-v1.0.0.AppImage`. They double-click it. No install, no Python needed.

**Example 2:**
Input: "Can I just zip this up and send it?"
Output: Yes — `install_and_run.sh` + zip is the right answer for internal/team distribution. The zip should exclude `.venv/`, `__pycache__/`, `.git/`. Include a one-line `README.txt`: `chmod +x install_and_run.sh && ./install_and_run.sh`.

**Example 3:**
Input: "My PyInstaller binary crashes with 'No module named tkinter' on the target machine."
Output: Tkinter isn't bundled by default in all PyInstaller cases. Add `--collect-all tkinter` to the PyInstaller invocation. Also verify the target machine has `python3-tk` installed if using the system Python, or that the venv's tcl/tk libs were copied into the bundle.

**Example 4:**
Input: "The AppImage works on my build machine but gives a FUSE error on the target."
Output: The target machine doesn't have FUSE. Rebuild with `export APPIMAGE_EXTRACT_AND_RUN=1` before running `appimagetool`. This makes the AppImage extract to `/tmp` instead of mounting via FUSE.

---

## Anti-patterns

- **Building AppImage with the dev venv.** The dev venv has IDE plugins, `python-picache`, test fixtures, and other cruft. Always build in a fresh venv in a temp directory.
- **Hardcoding build-machine paths in `AppRun`.** Use `APPDIR="$(dirname "$(readlink -f "$0")")"` so it's relocatable.
- **Shipping `tests/` or `docs/` in the AppImage.** They add size and clutter. Strip them from AppDir.
- **Using `--onefile` PyInstaller for a GUI app.** Onefile extracts to a temp dir on every launch — slow and fragile. Use `--onedir` for GUIs.
- **Forgetting `APPIMAGE_EXTRACT_AND_RUN=1`.** The #1 cause of "works on my machine, FUSE error on theirs."
- **Not stripping `torch/test/` and `torch/bin/test_*`.** They're test-only, add 500 MB+, and cause linuxdeploy to fail on unresolved `libtorch.so` dependencies.
- **Assuming the target has the same Python version.** The AppImage bundles its own Python — but `AppRun` must set `PYTHONPATH` to the exact version (e.g. `python3.12/site-packages`, not a symlink).
