#!/bin/bash

set -e

source ./setup_environment.sh

# 创建单个库的 DEB 包
create_library_deb() {
    local lib_name=$1
    local version=$2
    local description=$3
    local dependencies=$4
    
    echo "Creating DEB package for $lib_name..."
    
    local install_dir="$CROSS_BASE/install/$lib_name"
    local pkg_dir="$CROSS_BASE/packages/${lib_name}_${version}_armel"
    
    # 检查安装目录是否存在
    if [ ! -d "$install_dir" ]; then
        echo "Error: Install directory $install_dir does not exist!"
        return 1
    fi
    
    # 清理并创建包目录结构
    rm -rf "$pkg_dir"
    mkdir -p "$pkg_dir/DEBIAN"
    
    # 复制库文件到包目录，保持目录结构
    if [ -d "$install_dir" ]; then
        # 创建 usr 目录结构
        mkdir -p "$pkg_dir/usr"
        
        # 复制文件，但排除一些不需要的文件
        rsync -av \
            --exclude='pkgconfig' \
            "$install_dir/" "$pkg_dir/usr/"
        
        # 如果有 pkgconfig 文件，放到正确位置
        if [ -d "$install_dir/lib/pkgconfig" ]; then
            mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi/pkgconfig"
            cp "$install_dir/lib/pkgconfig"/* "$pkg_dir/usr/lib/arm-linux-gnueabi/pkgconfig/" 2>/dev/null || true
        fi
        
        # 移动库文件到 multiarch 目录
        if [ -d "$pkg_dir/usr/lib" ] && [ "$(ls -A $pkg_dir/usr/lib)" ]; then
            mkdir -p "$pkg_dir/usr/lib/arm-linux-gnueabi"
            find "$pkg_dir/usr/lib" -maxdepth 1 -name "*.so*" -exec mv {} "$pkg_dir/usr/lib/arm-linux-gnueabi/" \;
            find "$pkg_dir/usr/lib" -maxdepth 1 -name "*.a" -exec mv {} "$pkg_dir/usr/lib/arm-linux-gnueabi/" \;
            find "$pkg_dir/usr/lib" -maxdepth 1 -name "*.la" -exec mv {} "$pkg_dir/usr/lib/arm-linux-gnueabi/" \;
            find "$pkg_dir/usr/lib" -maxdepth 1 -name "lib*" -type d -exec mv {} "$pkg_dir/usr/lib/arm-linux-gnueabi/" \;
        fi
    fi
    
    # 计算安装大小
    local installed_size=$(du -sk "$pkg_dir/usr" | cut -f1)
    
    # 创建控制文件
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: lib${lib_name}-cross-armel
Version: ${version}
Section: libs
Priority: optional
Architecture: armel
Maintainer: ianchb <i@4t.pw>
Installed-Size: ${installed_size}
Description: ${description}
 Cross-compiled ${lib_name} library for ARM architecture (armel).
 This package contains the shared libraries and development files.
EOF
    
    # 如果有依赖关系，添加到控制文件
    if [ -n "$dependencies" ]; then
        echo "Depends: $dependencies" >> "$pkg_dir/DEBIAN/control"
    fi
    
    # 创建 postinst 脚本
    cat > "$pkg_dir/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
if [ "$1" = "configure" ]; then
    ldconfig
fi
EOF
    chmod 755 "$pkg_dir/DEBIAN/postinst"
    
    # 创建 postrm 脚本
    cat > "$pkg_dir/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    ldconfig
fi
EOF
    chmod 755 "$pkg_dir/DEBIAN/postrm"
    
    # 创建文件清单
    find "$pkg_dir/usr" -type f | sed "s|$pkg_dir||" > "$pkg_dir/DEBIAN/files.list"
    
    # 构建 DEB 包
    dpkg-deb -Zgzip --uniform-compression --build "$pkg_dir"
    
    echo "Created: ${pkg_dir}.deb"
    
    # 验证包
    echo "Package info:"
    dpkg-deb -I "${pkg_dir}.deb"
    echo ""
}

# 创建所有库的 DEB 包
echo "Creating DEB packages for all libraries..."

create_library_deb "zlib" "1.3.1-1" "Compression library - runtime" "libc6"

create_library_deb "openssl" "3.5.0-1" "Secure Sockets Layer toolkit - runtime" "libc6"

create_library_deb "libffi" "3.4.8-1" "Foreign Function Interface library runtime" "libc6"

create_library_deb "sqlite" "3.50.0-1" "SQLite 3 shared library" "libc6"

create_library_deb "ncurses" "6.5-1" "shared libraries for terminal handling" "libc6"

create_library_deb "readline" "8.2-1" "GNU readline and history libraries, runtime" "libc6, libncurses6"

create_library_deb "bzip2" "1.0.8-1" "high-quality block-sorting file compressor library - runtime" "libc6"

create_library_deb "xz" "5.8.1-1" "XZ-format compression library" "libc6"

create_library_deb "gdbm" "1.25-1" "GNU dbm database routines (runtime version)" "libc6"

create_library_deb "util-linux" "2.40.4-1" "miscellaneous system utilities - runtime libraries" "libc6"

echo "All DEB packages created successfully!"
echo "Packages location: $CROSS_BASE/packages/"
ls -la "$CROSS_BASE/packages/"*.deb
