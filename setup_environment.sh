#!/bin/bash

# 定义颜色和输出函数
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# 日志输出函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "\n${CYAN}===========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}===========================================${NC}\n"
}

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

log_success "Environment setup completed!"
log_info "Work directory: $CROSS_BASE"
