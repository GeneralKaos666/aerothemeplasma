#!/bin/bash
CUR_DIR="${PWD}"

INSTALL_PREFIX="${CMAKE_INSTALL_PREFIX:-${PREFIX:-/usr}}"
TERMUX_INSTALL=0

if [[ -n "${PREFIX}" && "${INSTALL_PREFIX}" == "${PREFIX}" ]]; then
    TERMUX_INSTALL=1
fi

run_install_cmd() {
    if [[ -n "${SU_CMD}" ]]; then
        "${SU_CMD}" "$@"
    else
        "$@"
    fi
}

clone_or_update_repo() {
    local repo_url="$1"
    local repo_dir="$2"

    if [[ -d "${repo_dir}/.git" ]]; then
        git -C "${repo_dir}" pull --ff-only || exit 1
    elif [[ -e "${repo_dir}" ]]; then
        echo "Path '${repo_dir}' already exists but is not a git checkout."
        exit 1
    else
        git clone "${repo_url}" "${repo_dir}" || exit 1
    fi
}

if [[ "${TERMUX_INSTALL}" -eq 0 ]]; then
    SU_CMD=sudo
    if [[ -z "$(command -v "${SU_CMD}")" ]]; then
        SU_CMD=doas
        if [[ -z "$(command -v "${SU_CMD}")" ]]; then
            echo "Neither sudo or doas were detected on the system."
            exit 1
        fi
    fi
else
    SU_CMD=
fi

if [[ -z "${LIBEXEC_DIR}" ]]; then
    LIBEXEC_DIR=lib
fi

if [[ -z "${UAC_LIBEXEC_DIR}" ]]; then
    UAC_LIBEXEC_DIR="${LIBEXEC_DIR}"
fi

if [[ "$(command -v dnf)" ]]; then # Automatically change for Fedora
    LIBEXEC_DIR=libexec
    UAC_LIBEXEC_DIR=libexec/kf6
fi

if [[ "${TERMUX_INSTALL}" -eq 1 ]]; then
    # Termux places libexec binaries under lib/libexec/
    if [[ -x "${INSTALL_PREFIX}/libexec/plasma-dbus-run-session-if-needed" ]]; then
        LIBEXEC_DIR=libexec
    elif [[ -x "${INSTALL_PREFIX}/lib/libexec/plasma-dbus-run-session-if-needed" ]]; then
        LIBEXEC_DIR=lib/libexec
    elif [[ -x "${INSTALL_PREFIX}/lib/plasma-dbus-run-session-if-needed" ]]; then
        LIBEXEC_DIR=lib
    fi

    if [[ -x "${INSTALL_PREFIX}/libexec/kf6/polkit-kde-authentication-agent-1" ]]; then
        UAC_LIBEXEC_DIR=libexec/kf6
    elif [[ -x "${INSTALL_PREFIX}/lib/libexec/kf6/polkit-kde-authentication-agent-1" ]]; then
        UAC_LIBEXEC_DIR=lib/libexec/kf6
    elif [[ -x "${INSTALL_PREFIX}/libexec/polkit-kde-authentication-agent-1" ]]; then
        UAC_LIBEXEC_DIR=libexec
    elif [[ -x "${INSTALL_PREFIX}/lib/libexec/polkit-kde-authentication-agent-1" ]]; then
        UAC_LIBEXEC_DIR=lib/libexec
    elif [[ -x "${INSTALL_PREFIX}/lib/polkit-kde-authentication-agent-1" ]]; then
        UAC_LIBEXEC_DIR=lib
    fi
fi

export CMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"
export LIBEXEC_DIR
export UAC_LIBEXEC_DIR

CMAKE_CONFIGURE_ARGS=()

mkdir -p repos
mkdir -p manifest

if [[ "${TERMUX_INSTALL}" -eq 1 ]]; then
    # Termux's GCC has broken OpenMP CXX support; clang works correctly.
    export CC=clang
    export CXX=clang++

    TERMUX_QT_SHIM="${CUR_DIR}/manifest/termux-qt-shim.cmake"
    cat > "${TERMUX_QT_SHIM}" <<'EOF'
if(NOT COMMAND _qt_internal_collect_qml_root_paths)
    function(_qt_internal_collect_qml_root_paths target)
    endfunction()
endif()
if(NOT COMMAND qt6_android_apply_arch_suffix)
    function(qt6_android_apply_arch_suffix target)
    endfunction()
endif()
EOF
    CMAKE_CONFIGURE_ARGS+=("-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=${TERMUX_QT_SHIM}")
    CMAKE_CONFIGURE_ARGS+=("-DCMAKE_POSITION_INDEPENDENT_CODE=ON")

    # Termux ships KWin as KWinX11; provide a shim so find_package(KWin) works.
    TERMUX_KWIN_SHIM_DIR="${CUR_DIR}/manifest/cmake"
    CMAKE_CONFIGURE_ARGS+=("-DCMAKE_PREFIX_PATH=${TERMUX_KWIN_SHIM_DIR}")
fi

cd repos

# libplasma last
clone_or_update_repo https://gitgud.io/aeroshell/libplasma.git libplasma
cd libplasma
cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -B build . || exit 1
cmake --build build || exit 1
run_install_cmd cmake --install build || exit 1
cp build/install_manifest.txt "$CUR_DIR/manifest/libplasma_install_manifest.txt"
cd "$CUR_DIR/repos"

# uac-polkit-agent
#clone_or_update_repo https://gitgud.io/aeroshell/uac-polkit-agent.git uac-polkit-agent
#cd uac-polkit-agent
#cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -DCMAKE_INSTALL_LIBEXECDIR="${UAC_LIBEXEC_DIR}" -B build . || exit 1
#cmake --build build || exit 1
#run_install_cmd cmake --install build || exit 1
#cp build/install_manifest.txt "$CUR_DIR/manifest/uac-polkit-agent_install_manifest.txt"
#cd "$CUR_DIR/repos"

# SMOD
clone_or_update_repo https://gitgud.io/aeroshell/smod.git smod
cd smod
if [[ "${TERMUX_INSTALL}" -eq 1 ]]; then
    sed -i "s|/usr|\${CMAKE_INSTALL_PREFIX}|g" install.sh smodglow/install.sh
    sed -i "s|\$SU_CMD||g" install.sh smodglow/install.sh
    sed -i "s|exit||g" install.sh smodglow/install.sh
fi
bash install.sh "$@"
cp build/install_manifest.txt "$CUR_DIR/manifest/smod_install_manifest.txt"

if [[ ! "$*" == *"--skip-wayland"* ]]
then
    cp smodglow/build-wl/install_manifest.txt "$CUR_DIR/manifest/smodglow_install_manifest.txt"
fi

if [[ ! "$*" == *"--skip-x11"* ]]
then
    cp smodglow/build/install_manifest.txt "$CUR_DIR/manifest/smodglow-x11_install_manifest.txt"
fi
cd "$CUR_DIR/repos"

# Aeroshell Workspace
clone_or_update_repo https://gitgud.io/aeroshell/aeroshell-workspace.git aeroshell-workspace
cd aeroshell-workspace
cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -B build . || exit 1
cmake --build build || exit 1
run_install_cmd cmake --install build || exit 1
if command -v update-mime-database >/dev/null 2>&1; then
    run_install_cmd update-mime-database "${INSTALL_PREFIX}/share/mime"
fi
cp build/install_manifest.txt "$CUR_DIR/manifest/aeroshell-workspace_install_manifest.txt"
cd "$CUR_DIR/repos"

if [[ ! "$*" == *"--skip-wayland"* ]]; then
# Aeroshell KWin
clone_or_update_repo https://gitgud.io/aeroshell/aeroshell-kwin-components.git aeroshell-kwin-components
cd aeroshell-kwin-components
cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -DKWIN_BUILD_WAYLAND=ON -B build . || exit 1
cmake --build build || exit 1
run_install_cmd cmake --install build || exit 1
cp build/install_manifest.txt "$CUR_DIR/manifest/aeroshell-kwin-components_install_manifest.txt"
if [[ ! "$*" == *"--skip-x11"* ]]
then
    cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -DKWIN_BUILD_WAYLAND=OFF -DKWIN_INSTALL_MISC=OFF -B build_x11 . || exit 1
    cmake --build build_x11 || exit 1
    run_install_cmd cmake --install build_x11 || exit 1
    cp build_x11/install_manifest.txt "$CUR_DIR/manifest/aeroshell-kwin-components-x11_install_manifest.txt"
fi
cd "$CUR_DIR/repos"
fi

# Aeroshell SDDM KCM
clone_or_update_repo https://gitgud.io/aeroshell/aeroshell-sddm-kcm.git aeroshell-sddm-kcm
cd aeroshell-sddm-kcm
cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -B build . || exit 1
cmake --build build || exit 1
run_install_cmd cmake --install build || exit 1
cp build/install_manifest.txt "$CUR_DIR/manifest/aeroshell-sddm-kcm_install_manifest.txt"
cd "$CUR_DIR/repos"

# Aerothemeplasma icons
clone_or_update_repo https://gitgud.io/aeroshell/atp/aerothemeplasma-icons aerothemeplasma-icons
cd aerothemeplasma-icons
cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -B build . || exit 1
cmake --build build || exit 1
run_install_cmd cmake --install build || exit 1
cp build/install_manifest.txt "$CUR_DIR/manifest/icons_install_manifest.txt"
cd "$CUR_DIR/repos"

# Aerothemeplasma sounds
clone_or_update_repo https://gitgud.io/aeroshell/atp/aerothemeplasma-sounds aerothemeplasma-sounds
cd aerothemeplasma-sounds
cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -B build . || exit 1
cmake --build build || exit 1
run_install_cmd cmake --install build || exit 1
cp build/install_manifest.txt "$CUR_DIR/manifest/sounds_install_manifest.txt"
cd "$CUR_DIR/repos"

# Aerothemeplasma
cd "$CUR_DIR"
cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -DCMAKE_INSTALL_LIBEXECDIR="${LIBEXEC_DIR}" -B build . || exit 1
cmake --build build || exit 1
run_install_cmd cmake --install build || exit 1
cp build/install_manifest.txt "$CUR_DIR/manifest/aerothemeplasma_install_manifest.txt"
if [[ ! "$*" == *"--skip-x11"* ]]
then
    cmake "${CMAKE_CONFIGURE_ARGS[@]}" -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" -DCMAKE_INSTALL_LIBEXECDIR="${LIBEXEC_DIR}" -DINSTALL_X11_COMPONENTS=ON -B build_x11 . || exit 1
    cmake --build build_x11 || exit 1
    run_install_cmd cmake --install build_x11 || exit 1
    cp build_x11/install_manifest.txt "$CUR_DIR/manifest/aerothemeplasma-x11_install_manifest.txt"
fi
cd "$CUR_DIR/repos"


echo "Done."
