#!/bin/bash

set -e

source ./setup_environment.sh

create_python_deb() {
    local python_version="3.13.5"
    local install_dir="$CROSS_BASE/install/python"
    local pkg_dir="$CROSS_BASE/packages/python3_${python_version}_armel"

    echo "Creating Python DEB package..."

    if [ ! -d "$install_dir" ]; then
        echo "Error: Python install directory $install_dir does not exist!"
        return 1
    fi

    # 清理并创建包目录
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr"

    # 复制 Python 安装文件
    rsync -av \
        --exclude='*.pyc' \
        --exclude='__pycache__' \
        --exclude='*.pyo' \
        "$install_dir/" "$pkg_dir/usr/"

    # 移动库文件到正确位置
    if [ -d "$pkg_dir/usr/lib" ]; then
        mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi"
        find "$pkg_dir/usr/lib" -maxdepth 1 -name "*.so*" -exec mv {} "$pkg_dir/usr/lib/arm-linux-gnueabi/" \; 2>/dev/null || true
    fi

    # 计算安装大小
    local installed_size=$(du -sk "$pkg_dir/usr" | cut -f1)

    # 创建控制文件
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: python3-cross-armel
Version: ${python_version}
Section: python
Priority: optional
Architecture: armel
Maintainer: ianchb <i@4t.pw>
Installed-Size: ${installed_size}
Depends: libc6, libzlib-cross-armel, libopenssl-cross-armel, liblibffi-cross-armel, libsqlite-cross-armel, libncurses-cross-armel, libreadline-cross-armel, libbzip2-cross-armel, libxz-cross-armel, libgdbm-cross-armel
Description: Python 3.13 interpreter (cross-compiled for ARM)
 Python is an interpreted, interactive, object-oriented programming
 language. This package contains Python 3.13 interpreter cross-compiled
 for ARM architecture (armel).
 .
 This package includes the Python interpreter, standard library modules,
 and development files.
EOF

    # 创建 postinst 脚本
    cat > "$pkg_dir/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "configure" ]; then
    # 更新动态链接器缓存
    ldconfig

    # 编译 Python 标准库
    if [ -x /usr/bin/python3.13 ]; then
        /usr/bin/python3.13 -m compileall -q /usr/lib/python3.13 2>/dev/null || true
    fi
fi
EOF
    chmod 755 "$pkg_dir/DEBIAN/postinst"

    # 创建 prerm 脚本
    cat > "$pkg_dir/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    # 清理编译的字节码文件
    find /usr/lib/python3.13 -name "*.pyc" -delete 2>/dev/null || true
    find /usr/lib/python3.13 -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
fi
EOF
    chmod 755 "$pkg_dir/DEBIAN/prerm"

    # 创建 postrm 脚本
    cat > "$pkg_dir/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    ldconfig
fi
EOF
    chmod 755 "$pkg_dir/DEBIAN/postrm"

    # 构建 DEB 包
    dpkg-deb -Zgzip --uniform-compression --build "$pkg_dir"

    echo "Created: ${pkg_dir}.deb"

    # 显示包信息
    echo "Package info:"
    dpkg-deb -I "${pkg_dir}.deb"
}

create_python_deb