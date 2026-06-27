# AeroThemePlasma — AGENTS.md

## Project

Windows 7 Aero recreation for KDE Plasma 6 (Plasma 6.7+, Qt 6, KF 6).  
Upstream branch: `Plasma/6.7`. Arch Linux is the only officially supported distro.

This repo is the main orchestrator — it contains theme assets, QML plasmoids, SDDM/login themes, and the `install.sh` entry point that clones and builds **8 external repos**.

## Repo structure

| Path | Purpose |
|------|---------|
| `plasma/plasmoids/io.gitgud.wackyideas.*/` | Pure-QML plasmoids (installed via `plasma_install_package`) |
| `plasma/plasmoids/src/*_src/` | C++ plasmoids (systemtray, notifications, volume, SevenStart, SevenTasks, desktopcontainment) |
| `plasma/shells/`, `look-and-feel/`, `desktoptheme/` | Custom Plasma shell & global theme |
| `plasma/color_scheme/`, `layout-templates/` | Color scheme, panel layout template |
| `plasma/sddm/` | SDDM login theme |
| `misc/kvantum/`, `misc/xdg/` | Kvantum style, mimetype associations |
| `docs/` | Per-component docs (plasmoids, KWin effects, SDDM, etc.) |

## Build & install

The main entry point is `install.sh` — it clones external repos into `repos/`, builds each with CMake, and installs with `sudo`/`doas`. **Do not** run scripts as root.

```bash
bash install.sh                       # full install (X11 + Wayland)
bash install.sh --skip-x11            # Wayland-only
CMAKE_GENERATOR=Ninja bash install.sh # use Ninja instead of Make
```

### External repos cloned by install.sh

All on branch `Plasma/6.7` from `gitgud.io/aeroshell/`:
- `libplasma` — fork of KDE's libplasma
- `uac-polkit-agent` — PolKit UAC dialog
- `smod` — SMOD kdecoration (includes smodglow)
- `aeroshell-workspace` — cursors, fonts, mimetypes, sound theme, branding
- `aeroshell-kwin-components` — C++ KWin effects (AeroGlassBlur, SMOD snap, AeroGlide, etc.)
- `aeroshell-sddm-kcm` — SDDM KCM
- `aerothemeplasma-icons`
- `aerothemeplasma-sounds`

### Direct CMake build (without install.sh)

```bash
cmake -DCMAKE_INSTALL_PREFIX=/usr -B build .
cmake --build build
sudo cmake --install build
```

Add `-DINSTALL_X11_COMPONENTS=ON` for X11 components.

### Distro path overrides

| Variable | Arch | Fedora |
|----------|------|--------|
| `LIBEXEC_DIR` | `lib` | `libexec` |
| `UAC_LIBEXEC_DIR` | `lib` | `libexec/kf6` |

```bash
LIBEXEC_DIR=libexec UAC_LIBEXEC_DIR=libexec/kf6 bash install.sh
```

### Uninstall

```bash
bash uninstall.sh          # new method (reads install_manifest.txt from each build dir)
bash migration-uninstall.sh  # old method (pre-CMake, deprecated)
```

After uninstall, reinstall `libplasma` from distro packages.

## Key plasmoids with C++ backends

| ID | Function |
|----|----------|
| `io.gitgud.wackyideas.seventasks` | Taskbar with thumbnails, jumplists |
| `io.gitgud.wackyideas.SevenStart` | Start menu (floating orb) |
| `io.gitgud.wackyideas.desktopcontainment` | Desktop icons/containment |
| `io.gitgud.wackyideas.volume` | Sound mixer |
| `io.gitgud.wackyideas.systemtray` | Forked KDE system tray |
| `io.gitgud.wackyideas.notifications` | Forked KDE notifications |

Pure-QML plasmoids: battery, clock (`digitalclocklite`), keyboard layout, network manager, show desktop.

## Development commands

```bash
setsid plasmashell --replace              # restart shell
setsid kwin_x11 --replace                 # restart KWin (X11)
setsid kwin_wayland --replace             # restart KWin (Wayland — kills apps)
systemsettings                            # run KCMs from terminal for logs
```

KWin effect debugging:
```bash
qdbus6 org.kde.KWin /Effects activeEffects
qdbus6 org.kde.KWin /Effects loadEffect <name>
```

Testing:
```bash
sddm-greeter-qt6 --test-mode --theme /path/to/sddm/theme
/usr/lib/kscreenlocker_greet --testing
ksplashqml --test /path/to/global/theme
```

## Wayland vs X11

- X11 is more complete. Wayland has known gaps: no Aero Peek overlay, broken context menu detection, no client-side window positioning (jumplist animations), SMOD HiDPI issues.
- Some C++ effects have separate Wayland build dirs (`build-wl`).

## Termux native X11 specifics

### Known build state (tested)

**`install.sh` now works on Termux** with auto-detection. The script detects
Termux via `$PREFIX` and adapts paths, privilege escalation, and build flags.

### Prerequisites

```bash
pkg install plasma-workspace plasma-desktop kwin-x11 libplasma \
  extra-cmake-modules qt6-qtdeclarative qt6-qt5compat qt6-qtwayland \
  qt6-qtsvg plasma5support kvantum plasma-nm plasma-pa kdecoration \
  kf6-{kirigami,kcmutils,package,coreaddons,config,i18n,auth,notifications, \
       notifyconfig,globalaccel,kio,kwindowsystem,ksvg,kirigami,guiaddons, \
       iconthemes,kpackage,krunner,kservice,sonnet,kxmlgui,kwidgetsaddons, \
       kcolorscheme,kitemviews,kjobwidets,solid,kdbusaddons,kcrash,kcompletion} \
  vulkan-headers wayland-protocols
```

### Full install (root repo + external repos)

```bash
bash install.sh --skip-libplasma --skip-uac --skip-smod --skip-sddm-kcm
```

Install all theme assets, QML plasmoids, Plasma shell, KWin C++ effects (AeroGlassBlur,
AeroGlide, SMOD snap, launch feedback), KWin JS effects, desktop theme, look-and-feel,
Kvantum, color scheme, XDG defaults, and login sessions.

The `--skip-*` flags skip external repos that are not yet ready on Termux:

| Flag | Repo | Issue |
|------|------|-------|
| `--skip-libplasma` | libplasma fork | Builds but takes very long; unneeded if system libplasma matches |
| `--skip-uac` | uac-polkit-agent | Needs `polkit-qt6-1` (not in Termux repos) |
| `--skip-smod` | SMOD kdecoration | Not yet tested on Termux |
| `--skip-sddm-kcm` | aeroshell-sddm-kcm | Needs SDDM (not in Termux repos) |
| `--skip-external` | All of the above | Use to skip all external repos |

### Root repo only

```bash
bash install.sh --skip-external
```

Installs all theme content (plasmoids, shell, desktop theme, look-and-feel,
color scheme, Kvantum, XDG configs, SDDM theme, login sessions) without cloning
any external repos.

### Direct CMake build (without install.sh)

```bash
cmake -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DBUILD_ATPOOTB=OFF \
  -DBUILD_CXX_PLASMOIDS=OFF \
  -B build .
cmake --build build
cmake --install build --prefix $PREFIX
```

### What installs

- **KWin C++ effects**: aeroglassblur, aeroglide, smodsnap, launchfeedback
- **KWin JS effects**: aeroshell-thumbnails, dimscreenaero, fadingpopupsaero, loginaero, smodpeekeffect, squashaero
- **Aero QML modules**: taskmanager, showdesktop, utils
- **All QML plasmoids** (battery, clock, keyboard, network, show desktop, panel) + QML packages for C++ plasmoids
- **Custom Plasma shell** (`io.gitgud.wackyideas.desktop`), **Seven-Black** desktop theme
- **authui7** look-and-feel (lock screen, logout, splash)
- **Aero** color scheme, taskbar layout template
- **Windows7Aero** Kvantum theme
- **XDG config defaults** (kwinrc, kdeglobals, etc.)
- **SDDM theme** (only if SDDM is installed)
- **Login sessions** (Wayland + X11)

### What does NOT work yet on Termux

| Component | Issue |
|-----------|-------|
| `atpootb` (OOTB wizard) | Qt6 Android QML macro (`qt6_android_apply_arch_suffix`) |
| C++ plasmoids (systemtray, notifications, volume, SevenStart, SevenTasks, desktopcontainment) | Qt6 Android QML internal macros missing |
| `uac-polkit-agent` | Needs `polkit-qt6-1` (not packaged in Termux) |
| `aeroshell-sddm-kcm` | Needs SDDM (not packaged in Termux) |
| `libplasma` fork (external) | Buildable but long; system package may suffice |
| SMOD kdecoration | Not yet tested |

### Key Termux adaptations in this repo

- `cmake/FindKWin.cmake` — wraps `KWinX11` CMake target as `KWin::kwin`
- `cmake/TermuxQt6AndroidHack.cmake` — stubs for missing Qt6 Android macros
- `install.sh` auto-detects Termux, sets `SU_CMD=""`, `CMAKE_INSTALL_PREFIX=$PREFIX`
- `BUILD_ATPOOTB=OFF` / `BUILD_CXX_PLASMOIDS=OFF` options in CMakeLists.txt

### Dependencies note

Termux's Qt6 packaging includes Android-specific paths. Any CMake target using
`qt_add_qml_module` or `ecm_target_qml_sources` may fail with missing Qt6
internal macros (mitigated by `TermuxQt6AndroidHack.cmake`). Pure content
installs (theme SVGs, QML files, configs) work fine.
