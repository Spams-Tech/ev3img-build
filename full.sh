#!/bin/bash

set -e

echo "=========================================="
echo "Cross-compilation build system for Lego EV3"
echo "Target: Debian 10 Buster (armel)"
echo "Host: $(uname -n)"
echo "Date: $(date)"
echo "=========================================="

# 检查必要工具
check_prerequisites() {
    echo "Checking prerequisites..."
    
    local missing_tools=()
    
    for tool in arm-ev3-linux-gnueabi-gcc wget tar rsync dpkg-deb; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo "Error: Missing required tools: ${missing_tools[*]}"
        echo "Please install them first."
        echo "Tips: sudo apt install build-essential debhelper wget rsync"
        exit 1
    fi
    
    echo "All prerequisites satisfied."
}

# 执行各个构建步骤
main() {
    check_prerequisites
    
    echo "Step 1: Setting up environment..."
    bash setup_environment.sh
    
    echo "Step 2: Building all libraries..."
    bash build_libraries.sh
    
    echo "Step 3: Creating library DEB packages..."
    bash create_deb_packages.sh
    
    echo "Step 4: Building Python..."
    bash build_python.sh
    
#    echo "Step 5: Creating Python DEB package..."
#    bash create_python_deb.sh
    
    echo "=========================================="
    echo "Build completed successfully!"
    echo "=========================================="
    
    echo "Generated DEB packages:"
    ls -la ~/cross-compile/packages/*.deb
    
    echo ""
    echo "To install on target system:"
    echo "1. Copy all .deb files to target system"
    echo "2. Install libraries first: sudo dpkg -i lib*-cross-armel.deb"
#    echo "3. Install Python: sudo dpkg -i python3-cross-armel.deb"
    echo "4. Fix dependencies if needed: sudo apt-get install -f"
}

# 运行主函数
main "$@"