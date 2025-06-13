#!/bin/bash

set -e

source ./setup_environment.sh

# 检查必要工具
check_prerequisites() {
    log_section "Checking prerequisites..."

    local missing_tools=()
    
    for tool in arm-ev3-linux-gnueabi-gcc wget tar rsync dpkg-deb; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tool(s): ${missing_tools[*]}"
        log_info "Please install them first."
        log_info "Note that arm-ev3-linux-gnueabi- toolchain can be built using crosstool-ng."
        exit 1
    fi
    
    log_success "All prerequisites satisfied."
}

# 执行各个构建步骤
main() {
    log_section "Build Python 3.13.5 (and some libraries) for Lego EV3"
    log_info "Target: Debian 10 Buster (armel)"
    log_info "For Docker image: growflavor/ev3images:ev3dev10imgv02b"
    log_info "Host: $(uname -n)"
    log_info "Date: $(date)"

    check_prerequisites

    log_section "Step 1: Setting up the environment"
    bash setup_environment.sh

    log_section "Step 2: Building libraries"
    bash build_libraries.sh
    
    log_section "Step 3: Creating DEB packages for libraries"
    bash create_deb_packages.sh
    
    log_section "Step 4: Building Python"
    bash build_python.sh
    
    log_section "Step 5: Creating DEB package for Python"
    bash create_python_deb.sh
    
    log_section "Build completed"
    log_success "All packages have been built successfully."

    log_info "Generated DEB packages:"
    ls -la ~/cross-compile/packages/*.deb
    
    log_section "Installation Instructions"
    log_info "To install the packages, follow these steps:"
    log_info "1. Copy all .deb files to your EV3 device / Docker container."
    log_info "2. Install libraries first: sudo dpkg -i --force-overwrite <...>.deb"
    log_info "3. Install Python: sudo dpkg -i --force-overwrite python3*armel.deb"
}

# 运行主函数
main "$@"