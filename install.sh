#!/bin/bash
CUR_DIR=${PWD}

BRANCH_VERSION="Plasma/6.7"

# --- Termux detection -------------------------------------------------------
IS_TERMUX=false
if [[ -n "$PREFIX" && "$PREFIX" == */com.termux/files/usr ]]; then
    IS_TERMUX=true
fi

# --- Privilege escalation ---------------------------------------------------
if $IS_TERMUX; then
    SU_CMD=""   # prefix is user-writable in Termux
else
    SU_CMD=sudo
    if [[ -z "$(command -v $SU_CMD)" ]]; then
        SU_CMD=doas
        if [[ -z "$(command -v $SU_CMD)" ]]; then
            echo "Neither sudo or doas were detected on the system."
            exit
        fi
    fi
fi

# --- Distro paths -----------------------------------------------------------
if $IS_TERMUX; then
    LIBEXEC_DIR=lib
    UAC_LIBEXEC_DIR=lib
elif [ -z $LIBEXEC_DIR ]; then
    LIBEXEC_DIR=lib
    UAC_LIBEXEC_DIR=lib
fi

if [[ "$(command -v dnf)" ]]; then
    LIBEXEC_DIR=libexec
    UAC_LIBEXEC_DIR=libexec/kf6
fi

# --- Termux-specific flags --------------------------------------------------
if $IS_TERMUX; then
    INSTALL_PREFIX="$PREFIX"
    QML_HACK="$CUR_DIR/cmake/TermuxQt6AndroidHack.cmake"
    ROOT_EXTRA_FLAGS="-DBUILD_ATPOOTB=OFF -DBUILD_CXX_PLASMOIDS=OFF"
    KWIN_EXTRA_FLAGS="-DKWIN_BUILD_WAYLAND=OFF"
    # Symlink KWinDBusInterface -> KWinX11DBusInterface if needed
    if [[ -d "$PREFIX/lib/cmake/KWinX11DBusInterface" && ! -d "$PREFIX/lib/cmake/KWinDBusInterface" ]]; then
        mkdir -p "$PREFIX/lib/cmake/KWinDBusInterface"
        cp "$PREFIX/lib/cmake/KWinX11DBusInterface/KWinX11DBusInterfaceConfig.cmake" \
           "$PREFIX/lib/cmake/KWinDBusInterface/KWinDBusInterfaceConfig.cmake"
        echo "Created KWinDBusInterface cmake shim"
    fi
    # Symlink KWin -> KWinX11 so find_package(KWin) works
    if [[ -d "$PREFIX/lib/cmake/KWinX11" && ! -d "$PREFIX/lib/cmake/KWin" ]]; then
        ln -sf "$PREFIX/lib/cmake/KWinX11" "$PREFIX/lib/cmake/KWin"
        echo "Created KWin cmake compat symlink"
    fi
else
    INSTALL_PREFIX="/usr"
    QML_HACK=""
    ROOT_EXTRA_FLAGS=""
    KWIN_EXTRA_FLAGS="-DKWIN_BUILD_WAYLAND=ON"
fi

# --- Shared CMake prefix for all repos --------------------------------------
CMAKE_BASE="-DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX"
CMAKE_HACK="-DCMAKE_PROJECT_INCLUDE=$QML_HACK"

# --- Help / skip-external ---------------------------------------------------
SKIP_EXTERNAL=false
SKIP_LIBPLASMA=false
SKIP_UAC=false
SKIP_SMOD=false
SKIP_SDDM_KCM=false
for arg in "$@"; do
    [[ "$arg" == "--skip-external" ]]  && SKIP_EXTERNAL=true
    [[ "$arg" == "--skip-libplasma" ]] && SKIP_LIBPLASMA=true
    [[ "$arg" == "--skip-uac" ]]       && SKIP_UAC=true
    [[ "$arg" == "--skip-smod" ]]      && SKIP_SMOD=true
    [[ "$arg" == "--skip-sddm-kcm" ]]  && SKIP_SDDM_KCM=true
done
if $SKIP_EXTERNAL; then
    SKIP_LIBPLASMA=true
    SKIP_UAC=true
    SKIP_SMOD=true
    SKIP_SDDM_KCM=true
fi

# Helper: clone or pull a repo, checkout branch with fallback
clone_or_pull() {
    local url="$1"
    local dir="$2"
    local branch="$3"
    if [[ ! -d "$dir" ]]; then
        git clone --depth 1 "$url" "$dir" || return 1
    fi
    cd "$dir" || return 1
    git pull --ff-only 2>/dev/null || true
    # Try the requested branch, fall back to master
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git checkout "$branch" 2>/dev/null || true
    fi
    cd "$CUR_DIR/repos"
}

# ============================================================================
# Build external repos
# ============================================================================
mkdir -p repos
mkdir -p manifest

cd repos

if ! $SKIP_EXTERNAL; then
    # --- libplasma ----------------------------------------------------------
    if ! $SKIP_LIBPLASMA; then
        clone_or_pull https://gitgud.io/aeroshell/libplasma.git libplasma Plasma/6.7
        cd libplasma
        cmake $CMAKE_BASE $CMAKE_HACK -B build . || exit 1
        cmake --build build || exit 1
        ${SU_CMD} cmake --install build --prefix "$INSTALL_PREFIX" || exit 1
        cp build/install_manifest.txt "$CUR_DIR/manifest/libplasma_install_manifest.txt"
        cd "$CUR_DIR/repos"
    fi

    # --- uac-polkit-agent ---------------------------------------------------
    if ! $SKIP_UAC; then
        if $IS_TERMUX; then
            echo "Warning: uac-polkit-agent needs polkit-qt6-1 (not in Termux repos). Skipping."
            echo "Use --skip-uac to silence this message."
        else
            clone_or_pull https://gitgud.io/aeroshell/uac-polkit-agent.git uac-polkit-agent Plasma/6.7
            cd uac-polkit-agent
            cmake $CMAKE_BASE -DCMAKE_INSTALL_LIBEXECDIR=$UAC_LIBEXEC_DIR $CMAKE_HACK -B build . || exit 1
            cmake --build build || exit 1
            ${SU_CMD} cmake --install build --prefix "$INSTALL_PREFIX" || exit 1
            cp build/install_manifest.txt "$CUR_DIR/manifest/uac-polkit-agent_install_manifest.txt"
            cd "$CUR_DIR/repos"
        fi
    fi

    # --- SMOD ---------------------------------------------------------------
    if $IS_TERMUX; then
        echo "Warning: SMOD not yet tested on Termux. Skipping."
    elif ! $SKIP_SMOD; then
        clone_or_pull https://gitgud.io/aeroshell/smod.git smod Plasma/6.7
        cd smod
        bash install.sh $@
        if [[ -f build/install_manifest.txt ]]; then
            cp build/install_manifest.txt "$CUR_DIR/manifest/smod_install_manifest.txt"
        fi
        if [[ -f smodglow/build-wl/install_manifest.txt ]]; then
            cp smodglow/build-wl/install_manifest.txt "$CUR_DIR/manifest/smodglow_install_manifest.txt"
        fi
        if [[ ! "$*" == *"--skip-x11"* ]] && [[ -f smodglow/build/install_manifest.txt ]]; then
            cp smodglow/build/install_manifest.txt "$CUR_DIR/manifest/smodglow-x11_install_manifest.txt"
        fi
        cd "$CUR_DIR/repos"
    fi

    # --- Aeroshell Workspace ------------------------------------------------
    clone_or_pull https://gitgud.io/aeroshell/aeroshell-workspace.git aeroshell-workspace Plasma/6.7
    cd aeroshell-workspace
    cmake $CMAKE_BASE $CMAKE_HACK -B build . || exit 1
    cmake --build build || exit 1
    ${SU_CMD} cmake --install build --prefix "$INSTALL_PREFIX" || exit 1
    ${SU_CMD} update-mime-database "$INSTALL_PREFIX/share/mime"
    cp build/install_manifest.txt "$CUR_DIR/manifest/aeroshell-workspace_install_manifest.txt"
    cd "$CUR_DIR/repos"

    # --- Aeroshell KWin components ------------------------------------------
    clone_or_pull https://gitgud.io/aeroshell/aeroshell-kwin-components.git aeroshell-kwin-components Plasma/6.7
    cd aeroshell-kwin-components
    cmake $CMAKE_BASE $CMAKE_HACK $KWIN_EXTRA_FLAGS -B build . || exit 1
    cmake --build build || exit 1
    ${SU_CMD} cmake --install build --prefix "$INSTALL_PREFIX" || exit 1
    cp build/install_manifest.txt "$CUR_DIR/manifest/aeroshell-kwin-components_install_manifest.txt"
    if [[ ! "$*" == *"--skip-x11"* ]]; then
        cmake $CMAKE_BASE $CMAKE_HACK $KWIN_EXTRA_FLAGS -DKWIN_INSTALL_MISC=OFF -B build_x11 . || exit 1
        cmake --build build_x11 || exit 1
        ${SU_CMD} cmake --install build_x11 --prefix "$INSTALL_PREFIX" || exit 1
        cp build_x11/install_manifest.txt "$CUR_DIR/manifest/aeroshell-kwin-components-x11_install_manifest.txt"
    fi
    cd "$CUR_DIR/repos"

    # --- Aeroshell SDDM KCM -------------------------------------------------
    if ! $SKIP_SDDM_KCM; then
        if $IS_TERMUX; then
            echo "Warning: aeroshell-sddm-kcm needs SDDM (not in Termux repos). Skipping."
        else
            clone_or_pull https://gitgud.io/aeroshell/aeroshell-sddm-kcm.git aeroshell-sddm-kcm Plasma/6.7
            cd aeroshell-sddm-kcm
            cmake $CMAKE_BASE $CMAKE_HACK -B build . || exit 1
            cmake --build build || exit 1
            ${SU_CMD} cmake --install build --prefix "$INSTALL_PREFIX" || exit 1
            cp build/install_manifest.txt "$CUR_DIR/manifest/aeroshell-sddm-kcm_install_manifest.txt"
            cd "$CUR_DIR/repos"
        fi
    fi

    # --- Aerothemeplasma icons ----------------------------------------------
    clone_or_pull https://gitgud.io/aeroshell/atp/aerothemeplasma-icons aerothemeplasma-icons master
    cd aerothemeplasma-icons
    cmake $CMAKE_BASE -B build . || exit 1
    cmake --build build || exit 1
    ${SU_CMD} cmake --install build --prefix "$INSTALL_PREFIX" || exit 1
    cp build/install_manifest.txt "$CUR_DIR/manifest/icons_install_manifest.txt"
    cd "$CUR_DIR/repos"

    # --- Aerothemeplasma sounds ---------------------------------------------
    clone_or_pull https://gitgud.io/aeroshell/atp/aerothemeplasma-sounds aerothemeplasma-sounds master
    cd aerothemeplasma-sounds
    cmake $CMAKE_BASE -B build . || exit 1
    cmake --build build || exit 1
    ${SU_CMD} cmake --install build --prefix "$INSTALL_PREFIX" || exit 1
    cp build/install_manifest.txt "$CUR_DIR/manifest/sounds_install_manifest.txt"
    cd "$CUR_DIR/repos"
fi

# ============================================================================
# Build root repo (AeroThemePlasma)
# ============================================================================
cd "$CUR_DIR"
cmake $CMAKE_BASE -DCMAKE_INSTALL_LIBEXECDIR=$LIBEXEC_DIR $CMAKE_HACK $ROOT_EXTRA_FLAGS -B build . || exit 1
cmake --build build || exit 1
${SU_CMD} cmake --install build --prefix "$INSTALL_PREFIX" || exit 1
cp build/install_manifest.txt "$CUR_DIR/manifest/aerothemeplasma_install_manifest.txt"
if [[ ! "$*" == *"--skip-x11"* ]] && ! $IS_TERMUX; then
    # X11 build is only needed on non-Termux (Termux uses kwin-x11 natively)
    cmake $CMAKE_BASE -DCMAKE_INSTALL_LIBEXECDIR=$LIBEXEC_DIR $CMAKE_HACK $ROOT_EXTRA_FLAGS -DINSTALL_X11_COMPONENTS=ON -B build_x11 . || exit 1
    cmake --build build_x11 || exit 1
    ${SU_CMD} cmake --install build_x11 --prefix "$INSTALL_PREFIX" || exit 1
    cp build_x11/install_manifest.txt "$CUR_DIR/manifest/aerothemeplasma-x11_install_manifest.txt"
fi
cd "$CUR_DIR"

echo "Done."
