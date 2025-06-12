#!/bin/bash

# 创建工作目录结构
mkdir -p ~/cross-compile/{src,build,packages}
mkdir -p ~/cross-compile/install/{zlib,openssl,libffi,sqlite,ncurses,readline,bzip2,xz,gdbm,util-linux,python}

# 设置基础环境变量
export CROSS_BASE=$HOME/cross-compile
export CROSS_HOST=arm-ev3-linux-gnueabi
export CROSS_CC=arm-ev3-linux-gnueabi-gcc
export CROSS_CXX=arm-ev3-linux-gnueabi-g++
export CROSS_AR=arm-ev3-linux-gnueabi-ar
export CROSS_STRIP=arm-ev3-linux-gnueabi-strip
export CROSS_RANLIB=arm-ev3-linux-gnueabi-ranlib

# 通用编译参数
export CFLAGS="-O2 -mcpu=arm926ej-s"
export CXXFLAGS="$CFLAGS"

echo "Environment setup completed"
echo "Work directory: $CROSS_BASE"