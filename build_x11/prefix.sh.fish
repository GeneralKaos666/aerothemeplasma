# SPDX-FileCopyrightText: 2021 Alexander Lohnau <alexander.lohnau@gmx.de>
# SPDX-License-Identifier: BSD-3-Clause

set PATH "/data/data/com.termux/files/usr/bin:$PATH"

# LD_LIBRARY_PATH only needed if you are building without rpath
# set -x LD_LIBRARY_PATH "/data/data/com.termux/files/usr/lib:$LD_LIBRARY_PATH"

if test -z "$XDG_DATA_DIRS"
    set -x --path XDG_DATA_DIRS /usr/local/share/ /usr/share/
end
set -x --path XDG_DATA_DIRS "/data/data/com.termux/files/usr/share" $XDG_DATA_DIRS

if test -z "$XDG_CONFIG_DIRS"
    set -x --path XDG_CONFIG_DIRS /etc/xdg
end
set -x --path XDG_CONFIG_DIRS "/data/data/com.termux/files/usr/etc/xdg" $XDG_CONFIG_DIRS

set -x --path QT_PLUGIN_PATH "/data/data/com.termux/files/usr/lib/qt6/plugins" $QT_PLUGIN_PATH
set -x --path QML2_IMPORT_PATH "/data/data/com.termux/files/usr/lib/qt6/qml" $QML2_IMPORT_PATH

set -x --path QT_QUICK_CONTROLS_STYLE_PATH "/data/data/com.termux/files/usr/lib/qt6/qml/QtQuick/Controls.2/" $QT_QUICK_CONTROLS_STYLE_PATH

set -x --path PYTHONPATH "/data/data/com.termux/files/usr/lib/python3.14/site-packages" $PYTHONPATH
