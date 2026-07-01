export PATH=/data/data/com.termux/files/usr/bin:$PATH

# LD_LIBRARY_PATH only needed if you are building without rpath
# export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib:$LD_LIBRARY_PATH

export XDG_DATA_DIRS=/data/data/com.termux/files/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
export XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg:${XDG_CONFIG_DIRS:-/etc/xdg}

export QT_PLUGIN_PATH=/data/data/com.termux/files/usr/lib/qt6/plugins:$QT_PLUGIN_PATH
export QML2_IMPORT_PATH=/data/data/com.termux/files/usr/lib/qt6/qml:$QML2_IMPORT_PATH

export QT_QUICK_CONTROLS_STYLE_PATH=/data/data/com.termux/files/usr/lib/qt6/qml/QtQuick/Controls.2/:$QT_QUICK_CONTROLS_STYLE_PATH

export MANPATH=/data/data/com.termux/files/usr/share/man:${MANPATH:-/usr/local/share/man:/usr/share/man}

export SASL_PATH=/data/data/com.termux/files/usr/lib/sasl2:${SASL_PATH:-/usr/lib/sasl2}

export PYTHONPATH="/data/data/com.termux/files/usr/lib/python3.14/site-packages":$PYTHONPATH
