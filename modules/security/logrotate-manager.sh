#!/bin/bash
# Logrotate Manager Module
# Quản lý log rotation cho WordPress sites

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Check if logrotate is installed
check_logrotate_installed() {
    if command_exists logrotate; then
        return 0
    else
        return 1
    fi
}

# Install logrotate
install_logrotate() {
    if check_logrotate_installed; then
        print_warning "Logrotate đã được cài đặt"
        return 1
    fi

    print_info "Đang cài đặt logrotate..."

    if command_exists apt-get; then
        apt-get update -qq
        apt-get install -y logrotate
    elif command_exists yum; then
        yum -y install logrotate
    else
        print_error "Không hỗ trợ hệ điều hành này"
        return 1
    fi

    print_success "Đã cài đặt logrotate"
    log_message "INFO" "Installed logrotate"
    return 0
}

# Setup WordPress sites logrotate
setup_wordpress_logrotate() {
    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        print_info "Chạy install_logrotate để cài đặt"
        return 1
    fi

    local config_file="/etc/logrotate.d/wordpress-sites"

    print_info "Đang cấu hình logrotate cho WordPress sites..."

    cat > "$config_file" <<'EOF'
# Logrotate configuration for WordPress sites
# Rotate logs weekly, compress, and keep 8 weeks

/var/log/nginx/*access.log /var/log/nginx/*error.log {
    weekly
    maxsize 50M
    missingok
    rotate 8
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then \
            run-parts /etc/logrotate.d/httpd-prerotate; \
        fi
    endscript
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}

/home/*/logs/*/*.log {
    weekly
    maxsize 50M
    missingok
    rotate 8
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
EOF

    print_success "Đã cấu hình WordPress logrotate"
    print_info ""
    print_info "Cấu hình:"
    print_info "- Rotate: Weekly"
    print_info "- Max size: 50MB"
    print_info "- Keep: 8 rotations"
    print_info "- Compress: Yes"

    log_message "INFO" "Configured WordPress logrotate"
    return 0
}

# Setup PHP-FPM logrotate
setup_phpfpm_logrotate() {
    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        return 1
    fi

    local config_file="/etc/logrotate.d/php-fpm"

    print_info "Đang cấu hình logrotate cho PHP-FPM..."

    cat > "$config_file" <<'EOF'
# Logrotate configuration for PHP-FPM
# Rotate logs weekly, compress, and keep 4 weeks

/var/log/php*.log {
    weekly
    maxsize 20M
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        /usr/lib/php/php-fpm-reopenlogs || true
    endscript
}
EOF

    print_success "Đã cấu hình PHP-FPM logrotate"
    log_message "INFO" "Configured PHP-FPM logrotate"
    return 0
}

# Setup MySQL logrotate
setup_mysql_logrotate() {
    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        return 1
    fi

    local config_file="/etc/logrotate.d/mysql-server"

    print_info "Đang cấu hình logrotate cho MySQL..."

    cat > "$config_file" <<'EOF'
# Logrotate configuration for MySQL/MariaDB
# Rotate logs weekly, compress, and keep 4 weeks

/var/log/mysql/*.log {
    weekly
    maxsize 100M
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    create 0640 mysql adm
    sharedscripts
    postrotate
        test -x /usr/bin/mysqladmin && \
        /usr/bin/mysqladmin flush-logs
    endscript
}
EOF

    print_success "Đã cấu hình MySQL logrotate"
    log_message "INFO" "Configured MySQL logrotate"
    return 0
}

# Test logrotate configuration
test_logrotate_config() {
    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        return 1
    fi

    print_info "Testing logrotate configuration..."
    echo ""

    logrotate -d /etc/logrotate.conf

    echo ""
    pause
    return 0
}

# Force logrotate now
force_logrotate() {
    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        return 1
    fi

    print_info "Đang force rotate logs..."

    logrotate -f /etc/logrotate.conf

    if [[ $? -eq 0 ]]; then
        print_success "Đã rotate logs thành công"
        log_message "INFO" "Forced log rotation"
        return 0
    else
        print_error "Lỗi khi rotate logs"
        return 1
    fi
}

# Show logrotate status
show_logrotate_status() {
    show_header
    echo -e "${CYAN}LOGROTATE STATUS${NC}"
    echo ""

    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        print_info "Chạy 'install_logrotate' để cài đặt"
        show_footer
        pause
        return 1
    fi

    # Check if configs exist
    echo -e "${YELLOW}Configured Services:${NC}"

    if [[ -f /etc/logrotate.d/wordpress-sites ]]; then
        print_success "✓ WordPress sites"
    else
        print_warning "✗ WordPress sites"
    fi

    if [[ -f /etc/logrotate.d/php-fpm ]]; then
        print_success "✓ PHP-FPM"
    else
        print_warning "✗ PHP-FPM"
    fi

    if [[ -f /etc/logrotate.d/mysql-server ]]; then
        print_success "✓ MySQL/MariaDB"
    else
        print_warning "✗ MySQL/MariaDB"
    fi

    echo ""

    # Show last run
    if [[ -f /var/lib/logrotate/status ]]; then
        echo -e "${YELLOW}Last Rotation Status:${NC}"
        tail -10 /var/lib/logrotate/status
        echo ""
    fi

    show_footer
    pause
}

# List all logrotate configs
list_logrotate_configs() {
    show_header
    echo -e "${CYAN}LOGROTATE CONFIGURATIONS${NC}"
    echo ""

    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        show_footer
        pause
        return 1
    fi

    echo -e "${YELLOW}Config Files:${NC}"
    ls -1 /etc/logrotate.d/
    echo ""

    show_footer
    pause
}

# View logrotate config
view_logrotate_config() {
    local config_name=$1

    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        return 1
    fi

    if [[ -z "$config_name" ]]; then
        print_error "Config name không được để trống"
        return 1
    fi

    local config_file="/etc/logrotate.d/${config_name}"

    if [[ ! -f "$config_file" ]]; then
        print_error "Config không tồn tại: $config_name"
        return 1
    fi

    show_header
    echo -e "${CYAN}LOGROTATE CONFIG: $config_name${NC}"
    echo ""

    cat "$config_file"

    echo ""
    show_footer
    pause
}

# Configure custom logrotate
create_custom_logrotate() {
    local config_name=$1
    local log_path=$2
    local rotate_count=${3:-8}
    local rotate_period=${4:-weekly}
    local maxsize=${5:-50M}

    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        return 1
    fi

    if [[ -z "$config_name" ]] || [[ -z "$log_path" ]]; then
        print_error "Config name và log path không được để trống"
        return 1
    fi

    local config_file="/etc/logrotate.d/${config_name}"

    print_info "Đang tạo custom logrotate: $config_name..."

    cat > "$config_file" <<EOF
# Custom logrotate configuration: $config_name
# Created: $(date)

$log_path {
    $rotate_period
    maxsize $maxsize
    missingok
    rotate $rotate_count
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
}
EOF

    print_success "Đã tạo custom logrotate: $config_name"
    print_info ""
    print_info "Path: $log_path"
    print_info "Period: $rotate_period"
    print_info "Keep: $rotate_count rotations"
    print_info "Max size: $maxsize"

    log_message "INFO" "Created custom logrotate: $config_name"
    return 0
}

# Delete logrotate config
delete_logrotate_config() {
    local config_name=$1

    if ! check_logrotate_installed; then
        print_error "Logrotate chưa được cài đặt"
        return 1
    fi

    if [[ -z "$config_name" ]]; then
        print_error "Config name không được để trống"
        return 1
    fi

    local config_file="/etc/logrotate.d/${config_name}"

    if [[ ! -f "$config_file" ]]; then
        print_error "Config không tồn tại: $config_name"
        return 1
    fi

    print_info "Đang xóa logrotate config: $config_name..."

    rm -f "$config_file"

    print_success "Đã xóa logrotate config: $config_name"
    log_message "INFO" "Deleted logrotate config: $config_name"
    return 0
}

# Clean old logs manually
clean_old_logs() {
    local days=${1:-30}

    print_warning "CẢNH BÁO: Sẽ xóa tất cả logs cũ hơn $days ngày!"

    if ! confirm_action "Bạn có chắc muốn xóa logs cũ?" "n"; then
        print_info "Đã hủy"
        return 1
    fi

    print_info "Đang xóa logs cũ hơn $days ngày..."

    # Find and delete old logs
    local count=0

    # Nginx logs
    count=$(find /var/log/nginx -name "*.log.*" -mtime +${days} -type f | wc -l)
    find /var/log/nginx -name "*.log.*" -mtime +${days} -type f -delete

    # Site logs
    count=$((count + $(find /home/*/logs -name "*.log.*" -mtime +${days} -type f 2>/dev/null | wc -l)))
    find /home/*/logs -name "*.log.*" -mtime +${days} -type f -delete 2>/dev/null

    print_success "Đã xóa $count log files"
    log_message "INFO" "Cleaned old logs: $count files deleted"
    return 0
}

# Show disk usage of logs
show_logs_disk_usage() {
    show_header
    echo -e "${CYAN}LOGS DISK USAGE${NC}"
    echo ""

    echo -e "${YELLOW}Nginx Logs:${NC}"
    du -sh /var/log/nginx 2>/dev/null || echo "No data"
    echo ""

    echo -e "${YELLOW}Site Logs:${NC}"
    du -sh /home/*/logs 2>/dev/null || echo "No data"
    echo ""

    echo -e "${YELLOW}PHP-FPM Logs:${NC}"
    du -sh /var/log/php*.log 2>/dev/null || echo "No data"
    echo ""

    echo -e "${YELLOW}MySQL Logs:${NC}"
    du -sh /var/log/mysql 2>/dev/null || echo "No data"
    echo ""

    echo -e "${YELLOW}Total Log Size:${NC}"
    local total=$(du -sh /var/log 2>/dev/null | cut -f1)
    echo "$total"
    echo ""

    show_footer
    pause
}
