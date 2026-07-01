# Termux Compatibility Fixes for AeroThemePlasma

This document summarizes the changes made to the repository to enable successful compilation and installation within the Termux environment on Android.

## Global Changes

### 1. Position Independent Code (PIC) Support
- **File:** `CMakeLists.txt`
- **Action:** Added `set(CMAKE_POSITION_INDEPENDENT_CODE ON)`.
- **Reason:** Required on AArch64 Termux to allow static libraries to be linked into shared objects, preventing relocation errors.

### 2. Installation Script Automation
- **File:** `install.sh`
- **Action:** Added `-DCMAKE_POSITION_INDEPENDENT_CODE=ON` to the global `CMAKE_CONFIGURE_ARGS`.
- **Reason:** Ensures that all external sub-repositories (libplasma, smod, etc.) are built with PIC support automatically.

---

## Component-Specific Fixes

### 3. ATP OOTB Executable (`atpootb`)
- **File:** `plasma/atpootb/src/CMakeLists.txt`
- **Changes:**
    - Replaced `qt_add_executable` with standard `add_executable`.
    - Explicitly set installation destination to `${KDE_INSTALL_BINDIR}`.
    - Updated DBus interface logic to use `find_file` searching for both `org.kde.kwin.Effects.xml` and the Termux-specific `kwin_x11_org.kde.kwin.Effects.xml`.
- **Reason:** Fixed an issue where the build system produced a shared library instead of an ELF binary and couldn't find the KWin DBus interface.

### 4. Hardcoded Path Removal (Main Repo)
- **Files:**
    - `plasma/plasmoids/src/sevenstart_src/src/CMakeLists.txt`
    - `plasma/plasmoids/src/seventasks_src/src/CMakeLists.txt`
    - `plasma/plasmoids/src/volume_src/src/CMakeLists.txt`
- **Action:** Replaced `/usr/include` with `${CMAKE_INSTALL_PREFIX}/include`.
- **Reason:** Standardizes header lookup to respect the Termux filesystem prefix.

### 5. Sub-Repository Path Fixes
- **Files:**
    - `repos/aeroshell-sddm-kcm/src/CMakeLists.txt`
    - `repos/aeroshell-kwin-components/effects_cpp/wayland/aeroglide/CMakeLists.txt`
    - `repos/aeroshell-kwin-components/effects_cpp/wayland/startupfeedback/CMakeLists.txt`
    - `repos/aeroshell-kwin-components/effects_cpp/x11/aeroglide/CMakeLists.txt`
    - `repos/aeroshell-kwin-components/effects_cpp/x11/startupfeedback/CMakeLists.txt`
- **Action:** Patched hardcoded `/usr/include` references to use portable CMake variables or the Termux prefix.

---

## System Integration & Portability

### 6. Autostart Configuration
- **File:** `misc/xdg/autostart/x-atpootb.desktop`
- **Action:** Changed `Exec=/usr/bin/atpootb` to `Exec=atpootb`.
- **Reason:** Allows the system to find the binary via the PATH environment variable, which is necessary since `/usr/bin/` does not exist in Termux.

### 7. Python Shebangs
- **Files:**
    - `plasma/look-and-feel/authui7/contents/images/createspinner.py`
    - `plasma/shells/io.gitgud.wackyideas.desktop/contents/images/spinner/createspinner.py`
- **Action:** Updated shebangs from `#!/usr/bin/python3` to `#!/usr/bin/env python3`.
- **Reason:** Ensures scripts run correctly regardless of where the Python binary is installed in the Termux prefix.
