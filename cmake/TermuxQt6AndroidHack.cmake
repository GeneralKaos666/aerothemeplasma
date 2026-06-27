# Termux Qt6 leaves qt6_android_apply_arch_suffix undefined despite
# Qt6CoreMacros.cmake calling it for any qt_add_executable / qt_add_qml_module.
# Provide stubs for all missing Qt6 Android macros.

if(NOT COMMAND qt6_android_apply_arch_suffix)
    function(qt6_android_apply_arch_suffix target)
        # stub: Termux does not build Android APKs
    endfunction()
endif()

if(NOT COMMAND qt6_android_add_apk_target)
    function(qt6_android_add_apk_target target)
    endfunction()
endif()

if(NOT COMMAND _qt_internal_collect_qml_root_paths)
    function(_qt_internal_collect_qml_root_paths)
    endfunction()
endif()

if(NOT COMMAND qt6_android_build_apk)
    function(qt6_android_build_apk)
    endfunction()
endif()
