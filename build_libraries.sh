#!/bin/bash

set -e

# 导入环境变量
source ./setup_environment.sh

# 通用库编译函数
build_library() {
    local lib_name=$1
    local lib_url=$2
    local lib_version=$3
    local configure_opts=$4
    local make_opts=$5
    
    echo "=========================================="
    echo "Building $lib_name version $lib_version"
    echo "=========================================="
    
    local src_dir="$CROSS_BASE/src/$lib_name"
    local build_dir="$CROSS_BASE/build/$lib_name"
    local install_dir="$CROSS_BASE/install/$lib_name"
    
    # 设置库特定的环境变量
    export CC=$CROSS_CC
    export CXX=$CROSS_CXX
    export AR=$CROSS_AR
    export STRIP=$CROSS_STRIP
    export RANLIB=$CROSS_RANLIB
    export PKG_CONFIG_PATH="$install_dir/lib/pkgconfig"
    
    # 下载和解压源码
    cd "$CROSS_BASE/src"
    if [ ! -d "$lib_name" ]; then
        echo "Downloading $lib_name..."
        local archive_name="${lib_name}.tar.gz"
        wget "$lib_url" -O "$archive_name"
        
        # 解压并正确重命名目录
        local extracted_dir="$lib_name"-"$lib_version"
        tar -xzf "$archive_name"
        echo "Renaming $extracted_dir to $lib_name"
        mv "$extracted_dir" "$lib_name"
        
        # 清理压缩包
        rm -f "$archive_name"
    fi
    
    # 创建构建目录
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # 配置
    echo "Configuring $lib_name..."
    if [ -n "$configure_opts" ]; then
        if [ $lib_name == "readline" ]; then
            "$src_dir/configure" --host=$CROSS_HOST --prefix="$install_dir" --enable-shared --disable-static CPPFLAGS="$CPPLAGS -I$CROSS_BASE/install/ncurses/include" CFLAGS="$CFLAGS -I$CROSS_BASE/install/ncurses/include" LDFLAGS="-L$CROSS_BASE/install/ncurses/lib"
        else
          eval "$src_dir/configure --host=$CROSS_HOST --prefix=$install_dir $configure_opts"
        fi
    else
        if [ $lib_name == "zlib" ]; then
            # zlib 特殊处理
            "$src_dir/configure" --prefix="$install_dir"
        else
            "$src_dir/configure" --host=$CROSS_HOST --prefix="$install_dir" --enable-shared --disable-static
        fi
    fi
    
    # 编译
    echo "Compiling $lib_name..."
    if [ -n "$make_opts" ]; then
        eval "make -j$(nproc) $make_opts"
    else
        make -j$(nproc)
    fi

    # 安装
    echo "Installing $lib_name..."
    make install

    if [ $lib_name == "ncurses" ]; then
        for lib in ncurses form panel menu tinfo ; do
            ln -sfv lib${lib}w.so $install_dir/lib/lib${lib}.so
            ln -sfv ${lib}w.pc $install_dir/lib/pkgconfig/${lib}.pc
        done
        ln -sfv libncursesw.so $install_dir/lib/libcurses.so
    fi

    # 记录安装的文件列表
    find "$install_dir" -type f > "$CROSS_BASE/install/${lib_name}_files.list"
    
    echo "$lib_name build completed successfully!"
    echo "Installed to: $install_dir"
    echo ""
}

# 特殊库编译函数
build_openssl() {
    echo "=========================================="
    echo "Building OpenSSL"
    echo "=========================================="
    
    local src_dir="$CROSS_BASE/src/openssl"
    local install_dir="$CROSS_BASE/install/openssl"
    
    cd "$CROSS_BASE/src"
    if [ ! -d "openssl" ]; then
        wget https://www.openssl.org/source/openssl-3.5.0.tar.gz
        tar -xzf openssl-3.5.0.tar.gz
        mv openssl-3.5.0 openssl
    fi
    
    cd "$src_dir"
    make clean || true
    
    ./Configure linux-armv4 \
        --prefix="$install_dir" \
        --cross-compile-prefix= \
        shared \
        no-asm \
        $CFLAGS
    
    make -j$(nproc)
    make install_sw install_ssldirs
    
    find "$install_dir" -type f > "$CROSS_BASE/install/openssl_files.list"
    echo "OpenSSL build completed!"
}

build_bzip2() {
    echo "=========================================="
    echo "Building bzip2"
    echo "=========================================="
    
    local src_dir="$CROSS_BASE/src/bzip2"
    local install_dir="$CROSS_BASE/install/bzip2"
    
    cd "$CROSS_BASE/src"
    if [ ! -d "bzip2" ]; then
        wget https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
        tar -xzf bzip2-1.0.8.tar.gz
        mv bzip2-1.0.8 bzip2
    fi
    
    cd "$src_dir"
    make clean || true
    
    # 修改 Makefile 使用交叉编译器
    sed -i \
        -e "s/CC=gcc/CC=$CROSS_CC/" \
        -e "s/AR=ar/AR=$CROSS_AR/" \
        -e "s/RANLIB=ranlib/RANLIB=$CROSS_RANLIB/" \
        Makefile
    sed -i \
        -e "s/all: libbz2.a bzip2 bzip2recover test/all: libbz2.a bzip2 bzip2recover/" \
        Makefile
    make -j$(nproc) CFLAGS="$CFLAGS -fPIC"
    make install PREFIX="$install_dir"
    make -j$(nproc) libbz2.a CFLAGS="$CFLAGS -fPIC"
    cp libbz2.a "$install_dir"/lib/
    # 创建共享库
    $CROSS_CC -shared -Wl,-soname,libbz2.so.1 -o "$install_dir/lib/libbz2.so.1.0.8" \
        blocksort.o huffman.o crctable.o randtable.o compress.o decompress.o bzlib.o
    
    cd "$install_dir/lib"
    ln -sf libbz2.so.1.0.8 libbz2.so.1
    ln -sf libbz2.so.1 libbz2.so
    
    find "$install_dir" -type f > "$CROSS_BASE/install/bzip2_files.list"
    echo "bzip2 build completed!"
}

# 编译所有库
echo "Starting cross-compilation of all libraries..."

# 1. zlib
build_library "zlib" "https://zlib.net/zlib-1.3.1.tar.gz" "1.3.1" ""

# 2. OpenSSL (特殊处理)
build_openssl

# 3. libffi
build_library "libffi" "https://github.com/libffi/libffi/releases/download/v3.4.8/libffi-3.4.8.tar.gz" "3.4.8" ""

# 4. SQLite
build_library "sqlite" "https://www.sqlite.org/2025/sqlite-autoconf-3500000.tar.gz" "autoconf-3500000" \
    "--enable-threadsafe --enable-fts5"

# 5. ncurses
build_library "ncurses" "https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.5.tar.gz" "6.5" \
    "--with-shared --with-termlib --with-pkg-config-libdir=/home/runner/cross-compile/install/ncurses/lib/pkgconfig --without-debug --enable-widec --enable-pc-files --enable-overwrite --with-strip-program=/home/runner/cross-toolchain/arm-ev3-linux-gnueabi/bin/arm-ev3-linux-gnueabi-strip"    

# 6. readline
build_library "readline" "https://ftp.gnu.org/gnu/readline/readline-8.2.tar.gz" "8.2" \
    "--with-curses"

# 7. bzip2 (特殊处理)
build_bzip2

# 8. xz
build_library "xz" "https://tukaani.org/xz/xz-5.8.1.tar.gz" "5.8.1" \
    "--enable-shared --disable-static"

# 9. gdbm
build_library "gdbm" "https://ftp.gnu.org/gnu/gdbm/gdbm-1.25.tar.gz" "1.25" \
    "--enable-shared --disable-static --enable-libgdbm-compat"

# 10. util-linux (提供 libuuid 等)
build_library "util-linux" "https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.40/util-linux-2.40.4.tar.gz" "2.40.4" \
    "--disable-all-programs --enable-libuuid --enable-libblkid --enable-libmount --enable-libsmartcols --enable-libfdisk --disable-year2038"

echo "All libraries compiled successfully!"
