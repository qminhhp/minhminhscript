#!/bin/bash
# WP Minhminh Script Auto Installer
# Cài đặt tự động WP Minhminh Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/opt/wpminhminhscript"

# Github repository
GITHUB_REPO="https://github.com/qminhhp/minhminhscript.git"
GITHUB_BRANCH="claude/vps-wordpress-management-script-011CV63HHAiT1yQs5Zo7Lx54"

# Print functions
print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script này cần chạy với quyền root"
        echo "Chạy lại với: sudo bash install.sh"
        exit 1
    fi
}

# Check OS
check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "Không thể xác định hệ điều hành"
        exit 1
    fi

    print_info "Hệ điều hành: $OS $VER"

    if [[ "$OS" != "Ubuntu" ]] && [[ "$OS" != "Debian GNU/Linux" ]]; then
        print_error "Script chỉ hỗ trợ Ubuntu và Debian"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    print_info "Đang cài đặt các gói phụ thuộc..."

    apt-get update -qq

    # Basic tools
    apt-get install -y curl wget git unzip sudo

    print_success "Đã cài đặt các gói phụ thuộc"
}

# Clone or download script
install_script() {
    print_info "Đang cài đặt WP Minhminh Script..."

    # Remove old installation if exists
    if [[ -d "$INSTALL_DIR" ]]; then
        print_info "Phát hiện phiên bản cũ, đang xóa..."
        rm -rf "$INSTALL_DIR"
    fi

    # Clone from Github
    if command -v git &> /dev/null; then
        print_info "Đang clone từ Github..."
        git clone -b "$GITHUB_BRANCH" "$GITHUB_REPO" "$INSTALL_DIR"
    else
        print_error "Git chưa được cài đặt"
        exit 1
    fi

    # Make script executable
    chmod +x "$INSTALL_DIR/wpminhminhscript"

    # Create symlink
    if [[ ! -f /usr/local/bin/wpminhminhscript ]]; then
        ln -s "$INSTALL_DIR/wpminhminhscript" /usr/local/bin/wpminhminhscript
    fi

    print_success "Đã cài đặt WP Minhminh Script tại: $INSTALL_DIR"
}

# Setup directories
setup_directories() {
    print_info "Đang tạo các thư mục cần thiết..."

    mkdir -p /var/log/wpminhminhscript
    mkdir -p /var/backups/wpminhminhscript
    mkdir -p /etc/wpminhminhscript

    # Copy default config if not exists
    if [[ -f "$INSTALL_DIR/config/default.conf" ]] && [[ ! -f /etc/wpminhminhscript/default.conf ]]; then
        cp "$INSTALL_DIR/config/default.conf" /etc/wpminhminhscript/
    fi

    print_success "Đã tạo các thư mục"
}

# Install WP-CLI
install_wpcli() {
    if command -v wp &> /dev/null; then
        print_info "WP-CLI đã được cài đặt"
        return 0
    fi

    print_info "Đang cài đặt WP-CLI..."

    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp

    # Test WP-CLI
    if wp --info &> /dev/null; then
        print_success "Đã cài đặt WP-CLI"
    else
        print_error "Lỗi khi cài đặt WP-CLI"
        return 1
    fi
}

# Show completion message
show_completion() {
    echo ""
    echo "============================================"
    print_success "CÀI ĐẶT THÀNH CÔNG!"
    echo "============================================"
    echo ""
    echo "WP Minhminh Script đã được cài đặt tại: $INSTALL_DIR"
    echo ""
    echo "Để bắt đầu sử dụng, chạy lệnh:"
    echo "  wpminhminhscript"
    echo ""
    echo "Hoặc:"
    echo "  cd $INSTALL_DIR && ./wpminhminhscript"
    echo ""
    echo "Documentation: $INSTALL_DIR/README.md"
    echo ""
}

# Main installation
main() {
    echo "============================================"
    echo "  WP Minhminh Script - Auto Installer"
    echo "============================================"
    echo ""

    check_root
    check_os

    print_info "Bắt đầu cài đặt..."
    echo ""

    install_dependencies
    install_script
    setup_directories
    install_wpcli

    show_completion
}

# Run main
main
