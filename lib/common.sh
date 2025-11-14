#!/bin/bash
# Common functions and variables for WP Minhminh Script
# Version: 1.0.0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
LIB_DIR="${SCRIPT_DIR}/lib"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
LOGS_DIR="${SCRIPT_DIR}/logs"

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID=$ID
        OS_VERSION=$VERSION_ID
    else
        OS_ID="unknown"
    fi

    case "$OS_ID" in
        ubuntu|debian)
            OS_FAMILY="debian"
            ;;
        almalinux|rocky|rhel|centos)
            OS_FAMILY="rhel"
            ;;
        *)
            OS_FAMILY="unknown"
            ;;
    esac
}

# Detect PHP version
detect_php_version() {
    if command -v php >/dev/null 2>&1; then
        PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
    else
        PHP_VERSION="8.1"
    fi
}

# Detect web server user
detect_web_user() {
    if id www-data >/dev/null 2>&1; then
        WEB_USER="www-data"
        WEB_GROUP="www-data"
    elif id nginx >/dev/null 2>&1; then
        WEB_USER="nginx"
        WEB_GROUP="nginx"
    elif id apache >/dev/null 2>&1; then
        WEB_USER="apache"
        WEB_GROUP="apache"
    else
        WEB_USER="nginx"
        WEB_GROUP="nginx"
    fi
}

# Initialize OS-specific paths
init_os_paths() {
    detect_os
    detect_php_version
    detect_web_user

    # Set paths based on OS family
    if [[ "$OS_FAMILY" == "rhel" ]]; then
        # RHEL/AlmaLinux/Rocky paths
        NGINX_CONF_DIR="/etc/nginx/conf.d"
        NGINX_SITES_AVAILABLE="/etc/nginx/conf.d"
        NGINX_SITES_ENABLED="/etc/nginx/conf.d"
        PHP_FPM_POOL_DIR="/etc/php-fpm.d"
        PHP_SOCKET_DIR="/run/php-fpm"
        PHP_FPM_SERVICE="php-fpm"
        NGINX_SERVICE="nginx"

    elif [[ "$OS_FAMILY" == "debian" ]]; then
        # Debian/Ubuntu paths
        NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
        NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
        PHP_FPM_POOL_DIR="/etc/php/${PHP_VERSION}/fpm/pool.d"
        PHP_SOCKET_DIR="/run/php"
        PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
        NGINX_SERVICE="nginx"
    else
        # Fallback to Debian-like
        NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
        NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
        PHP_FPM_POOL_DIR="/etc/php/fpm/pool.d"
        PHP_SOCKET_DIR="/run/php"
        PHP_FPM_SERVICE="php-fpm"
        NGINX_SERVICE="nginx"
    fi

    # Common paths
    WEB_ROOT="/var/www"
    BACKUP_DIR="/var/backups/wpminhminhscript"
}

# Call init on load
init_os_paths

# Log file
LOG_FILE="${LOGS_DIR}/wpminhminhscript.log"

# Print colored message
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print success message
print_success() {
    print_message "${GREEN}" "✓ $1"
}

# Print error message
print_error() {
    print_message "${RED}" "✗ $1"
}

# Print warning message
print_warning() {
    print_message "${YELLOW}" "⚠ $1"
}

# Print info message
print_info() {
    print_message "${CYAN}" "ℹ $1"
}

# Log message to file
log_message() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script này cần chạy với quyền root"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required packages
check_requirements() {
    local missing_packages=()

    if ! command_exists nginx; then
        missing_packages+=("nginx")
    fi

    if ! command_exists php; then
        missing_packages+=("php php-fpm")
    fi

    if ! command_exists mysql && ! command_exists mariadb; then
        missing_packages+=("mysql-server or mariadb-server")
    fi

    if [ ${#missing_packages[@]} -gt 0 ]; then
        print_error "Thiếu các gói cần thiết: ${missing_packages[*]}"
        print_info "Vui lòng cài đặt các gói trên trước khi sử dụng script"
        exit 1
    fi
}

# Validate domain name
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    return 0
}

# Generate random string
generate_random_string() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# Generate random password
generate_password() {
    local length=${1:-20}
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
}

# Confirm action
confirm_action() {
    local message=$1
    local default=${2:-n}

    if [[ $default == "y" ]]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi

    read -p "$message $prompt: " response
    response=${response:-$default}

    if [[ $response =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Reload nginx
reload_nginx() {
    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx
        if [[ $? -eq 0 ]]; then
            print_success "Đã reload Nginx thành công"
            log_message "INFO" "Nginx reloaded successfully"
            return 0
        else
            print_error "Không thể reload Nginx"
            log_message "ERROR" "Failed to reload Nginx"
            return 1
        fi
    else
        print_error "Cấu hình Nginx không hợp lệ"
        nginx -t
        log_message "ERROR" "Nginx configuration test failed"
        return 1
    fi
}

# Reload PHP-FPM
reload_phpfpm() {
    systemctl reload "${PHP_FPM_SERVICE}"
    if [[ $? -eq 0 ]]; then
        print_success "Đã reload PHP-FPM thành công"
        log_message "INFO" "PHP-FPM reloaded successfully"
        return 0
    else
        print_error "Không thể reload PHP-FPM"
        log_message "ERROR" "Failed to reload PHP-FPM"
        return 1
    fi
}

# Create directory if not exists
ensure_directory() {
    local dir=$1
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_message "INFO" "Created directory: $dir"
    fi
}

# Initialize script
initialize() {
    ensure_directory "$LOGS_DIR"
    ensure_directory "$BACKUP_DIR"
    log_message "INFO" "Script initialized"
}

# Show header
show_header() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║           WP MINHMINH SCRIPT - VPS Manager                 ║"
    echo "║              Quản lý nhiều WordPress sites                 ║"
    echo "║                    Version 1.0.0                           ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Show footer
show_footer() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Pause
pause() {
    read -p "Nhấn Enter để tiếp tục..."
}

# Export functions
export -f print_message
export -f print_success
export -f print_error
export -f print_warning
export -f print_info
export -f log_message
export -f check_root
export -f command_exists
export -f validate_domain
export -f generate_random_string
export -f generate_password
export -f confirm_action
export -f reload_nginx
export -f reload_phpfpm
export -f ensure_directory
