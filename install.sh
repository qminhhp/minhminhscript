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

# Auto install stack flag
AUTO_INSTALL_STACK="${AUTO_INSTALL:-no}"

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
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
        # Change to safe directory before removing
        cd /root || cd /tmp
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

    # Check if PHP is installed first
    if ! command -v php &> /dev/null; then
        print_warning "PHP chưa được cài đặt - bỏ qua cài WP-CLI"
        print_info "WP-CLI sẽ được cài tự động khi bạn chạy wpminhminhscript lần đầu"
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

# Install Nginx
install_nginx() {
    if command -v nginx &> /dev/null; then
        print_info "Nginx đã được cài đặt"
        return 0
    fi

    print_info "Đang cài đặt Nginx..."

    if [[ "$OS_FAMILY" == "rhel" ]]; then
        dnf install -y nginx
    elif [[ "$OS_FAMILY" == "debian" ]]; then
        apt-get install -y nginx
    fi

    # Enable and start Nginx
    systemctl enable nginx
    systemctl start nginx

    if systemctl is-active --quiet nginx; then
        print_success "Nginx đã được cài đặt và khởi động"
    else
        print_error "Lỗi khi khởi động Nginx"
        return 1
    fi
}

# Install PHP and extensions
install_php() {
    if command -v php &> /dev/null; then
        print_info "PHP đã được cài đặt ($(php -v | head -n1))"
        return 0
    fi

    print_info "Đang cài đặt PHP và các extensions..."

    if [[ "$OS_FAMILY" == "rhel" ]]; then
        # Install PHP with common extensions
        # Note: php-xmlrpc is deprecated on RHEL 9, excluded
        dnf install -y php php-fpm php-mysqlnd php-gd php-mbstring \
                       php-xml php-json php-curl php-zip php-intl \
                       php-opcache php-soap php-bcmath
    elif [[ "$OS_FAMILY" == "debian" ]]; then
        apt-get install -y php php-fpm php-mysql php-gd php-mbstring \
                           php-xml php-curl php-zip php-intl \
                           php-opcache php-soap php-xmlrpc php-bcmath
    fi

    # Enable and start PHP-FPM
    systemctl enable php-fpm
    systemctl start php-fpm

    if command -v php &> /dev/null; then
        print_success "PHP đã được cài đặt: $(php -v | head -n1)"

        # Now install WP-CLI since PHP is available
        install_wpcli
    else
        print_error "Lỗi khi cài đặt PHP"
        return 1
    fi
}

# Install MariaDB
install_mariadb() {
    if command -v mysql &> /dev/null || command -v mariadb &> /dev/null; then
        print_info "MariaDB/MySQL đã được cài đặt"
        return 0
    fi

    print_info "Đang cài đặt MariaDB..."

    if [[ "$OS_FAMILY" == "rhel" ]]; then
        dnf install -y mariadb-server
    elif [[ "$OS_FAMILY" == "debian" ]]; then
        apt-get install -y mariadb-server
    fi

    # Enable and start MariaDB
    systemctl enable mariadb
    systemctl start mariadb

    if systemctl is-active --quiet mariadb; then
        print_success "MariaDB đã được cài đặt và khởi động"
        echo ""
        print_warning "QUAN TRỌNG: Chạy lệnh sau để bảo mật MariaDB:"
        echo "  mysql_secure_installation"
        echo ""
    else
        print_error "Lỗi khi khởi động MariaDB"
        return 1
    fi
}

# Install Certbot for SSL
install_certbot() {
    if command -v certbot &> /dev/null; then
        print_info "Certbot đã được cài đặt"
        return 0
    fi

    print_info "Đang cài đặt Certbot (Let's Encrypt SSL)..."

    if [[ "$OS_FAMILY" == "rhel" ]]; then
        dnf install -y certbot python3-certbot-nginx
    elif [[ "$OS_FAMILY" == "debian" ]]; then
        apt-get install -y certbot python3-certbot-nginx
    fi

    if command -v certbot &> /dev/null; then
        print_success "Certbot đã được cài đặt"
    else
        print_error "Lỗi khi cài đặt Certbot"
        return 1
    fi
}

# Install Docker for n8n
install_docker() {
    if command -v docker &> /dev/null; then
        print_info "Docker đã được cài đặt"
        return 0
    fi

    print_info "Đang cài đặt Docker..."

    if [[ "$OS_FAMILY" == "rhel" ]]; then
        # Remove old versions
        dnf remove -y docker docker-client docker-client-latest \
                      docker-common docker-latest docker-latest-logrotate \
                      docker-logrotate docker-engine podman runc

        # Install Docker CE
        dnf install -y dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    elif [[ "$OS_FAMILY" == "debian" ]]; then
        # Remove old versions
        apt-get remove -y docker docker-engine docker.io containerd runc

        # Install Docker CE
        apt-get update
        apt-get install -y ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker

    if systemctl is-active --quiet docker; then
        print_success "Docker đã được cài đặt và khởi động"
    else
        print_error "Lỗi khi khởi động Docker"
        return 1
    fi
}

# Install full LEMP stack
install_full_stack() {
    echo ""
    echo "============================================"
    echo "  Đang cài đặt LEMP Stack + Docker..."
    echo "============================================"
    echo ""

    install_nginx
    install_php
    install_mariadb
    install_certbot
    install_docker

    echo ""
    print_success "Hoàn thành cài đặt stack!"
    echo ""
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

# Ask user if they want to install stack
ask_install_stack() {
    # Check if auto install is enabled
    if [[ "$AUTO_INSTALL_STACK" == "yes" ]] || [[ "$AUTO_INSTALL_STACK" == "y" ]] || [[ "$AUTO_INSTALL_STACK" == "1" ]]; then
        print_info "Chế độ tự động: Đang cài đặt LEMP Stack + Docker..."
        install_full_stack

        echo ""
        print_success "Hoàn tất! Bạn có thể chạy script ngay:"
        echo "  wpminhminhscript"
        echo ""
        print_warning "Đừng quên chạy để bảo mật MariaDB:"
        echo "  mysql_secure_installation"
        echo ""
        return 0
    fi

    # Check if running in pipe (cannot read from terminal)
    if ! [ -t 0 ]; then
        print_warning "Phát hiện chạy qua pipe - bỏ qua cài stack tự động"
        echo ""
        print_info "Để tự động cài LEMP stack, sử dụng:"
        echo "  curl -sL ... | AUTO_INSTALL=yes bash"
        echo ""
        echo "Hoặc download và chạy trực tiếp:"
        echo "  curl -O https://raw.githubusercontent.com/.../install.sh"
        echo "  bash install.sh"
        echo ""
        show_completion
        return 0
    fi

    # Interactive mode
    echo ""
    echo "============================================"
    echo -e "${YELLOW}Cài đặt LEMP Stack + Docker?${NC}"
    echo "============================================"
    echo ""
    echo "Script sẽ cài đặt:"
    echo "  • Nginx - Web server"
    echo "  • PHP 8.x + PHP-FPM + Extensions"
    echo "  • MariaDB - Database server"
    echo "  • Certbot - Let's Encrypt SSL"
    echo "  • Docker + Docker Compose - Cho n8n"
    echo ""
    echo -e "${YELLOW}Bạn có muốn cài đặt stack ngay bây giờ? (y/n)${NC}"
    read -p "Lựa chọn [y/n]: " choice

    case "$choice" in
        y|Y|yes|Yes|YES)
            install_full_stack

            echo ""
            print_success "Hoàn tất! Bạn có thể chạy script ngay:"
            echo "  wpminhminhscript"
            echo ""
            print_warning "Đừng quên chạy để bảo mật MariaDB:"
            echo "  mysql_secure_installation"
            echo ""
            ;;
        *)
            show_completion
            ;;
    esac
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--full)
                AUTO_INSTALL_STACK="yes"
                shift
                ;;
            -h|--help)
                echo "WP Minhminh Script - Auto Installer"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -f, --full    Tự động cài đặt LEMP stack + Docker"
                echo "  -h, --help    Hiển thị trợ giúp này"
                echo ""
                echo "Examples:"
                echo "  $0              # Chỉ cài script (interactive)"
                echo "  $0 --full       # Cài script + LEMP stack tự động"
                echo ""
                echo "  # Qua pipe:"
                echo "  curl -sL ... | bash               # Chỉ cài script"
                echo "  curl -sL ... | AUTO_INSTALL=yes bash  # Cài script + stack"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done
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

    ask_install_stack
}

# Parse arguments and run
parse_args "$@"
main
