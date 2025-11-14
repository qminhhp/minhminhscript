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
        OS_ID=$ID
    else
        print_error "Không thể xác định hệ điều hành"
        exit 1
    fi

    print_info "Hệ điều hành: $OS $VER"

    # Determine OS family
    case "$OS_ID" in
        ubuntu|debian)
            OS_FAMILY="debian"
            PKG_MGR="apt-get"
            ;;
        almalinux|rocky|rhel|centos)
            OS_FAMILY="rhel"
            PKG_MGR="dnf"
            print_info "Phát hiện RHEL-based OS"
            ;;
        *)
            print_error "Hệ điều hành không được hỗ trợ: $OS"
            print_info "Script hỗ trợ: Ubuntu, Debian, AlmaLinux, Rocky Linux, RHEL, CentOS"
            exit 1
            ;;
    esac
}

# Install dependencies
install_dependencies() {
    print_info "Đang cài đặt các gói phụ thuộc..."

    if [[ "$OS_FAMILY" == "debian" ]]; then
        apt-get update -qq
        apt-get install -y curl wget git unzip sudo
    elif [[ "$OS_FAMILY" == "rhel" ]]; then
        dnf check-update -q || true
        dnf install -y curl wget git unzip sudo
    fi

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

    # Show next steps based on OS
    if [[ "$OS_FAMILY" == "rhel" ]]; then
        echo -e "${YELLOW}BƯỚC TIẾP THEO (AlmaLinux/RHEL):${NC}"
        echo ""
        echo "1. Cài đặt Nginx:"
        echo "   dnf install -y nginx"
        echo "   systemctl enable --now nginx"
        echo ""
        echo "2. Cài đặt PHP 8.1 (hoặc 8.2, 8.3):"
        echo "   dnf install -y php php-fpm php-mysqlnd php-gd php-mbstring \\"
        echo "                  php-xml php-json php-curl php-zip php-intl"
        echo "   systemctl enable --now php-fpm"
        echo ""
        echo "3. Cài đặt MariaDB:"
        echo "   dnf install -y mariadb-server"
        echo "   systemctl enable --now mariadb"
        echo "   mysql_secure_installation"
        echo ""
        echo "4. Cài đặt Certbot (SSL):"
        echo "   dnf install -y certbot python3-certbot-nginx"
        echo ""
    elif [[ "$OS_FAMILY" == "debian" ]]; then
        echo -e "${YELLOW}BƯỚC TIẾP THEO:${NC}"
        echo ""
        echo "Nếu chưa cài stack, chạy:"
        echo "  apt install -y nginx mariadb-server php-fpm php-mysql \\"
        echo "                 certbot python3-certbot-nginx"
        echo ""
    fi

    echo "5. Chạy script:"
    echo "   wpminhminhscript"
    echo ""
    echo "Hoặc:"
    echo "   cd $INSTALL_DIR && ./wpminhminhscript"
    echo ""
    echo "📖 Documentation: $INSTALL_DIR/README.md"
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
