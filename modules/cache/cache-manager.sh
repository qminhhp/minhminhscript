#!/bin/bash
# Cache Manager Module
# Quản lý cache cho WordPress sites

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Clear all cache for a site
clear_site_cache() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name site_user _ _ site_root _ <<< "$site_info"

    print_info "Đang xóa cache cho site: $domain"

    # Clear WordPress object cache
    if [[ -f "${site_root}/wp-content/object-cache.php" ]]; then
        print_info "Xóa object cache..."
        rm -f "${site_root}/wp-content/object-cache.php"
        print_success "Đã xóa object cache"
    fi

    # Clear WordPress cache directory
    if [[ -d "${site_root}/wp-content/cache" ]]; then
        print_info "Xóa cache directory..."
        rm -rf "${site_root}/wp-content/cache"/*
        print_success "Đã xóa cache directory"
    fi

    # Clear OPcache
    if command_exists php; then
        print_info "Xóa OPcache..."
        echo "<?php opcache_reset(); echo 'OPcache cleared'; ?>" | php
        print_success "Đã xóa OPcache"
    fi

    # Restart PHP-FPM pool
    source "${MODULES_DIR}/phpfpm/phpfpm-manager.sh"
    restart_phpfpm_pool "$site_name"

    print_success "Đã xóa tất cả cache cho site: $domain"
    log_message "INFO" "Cleared all cache for site: $domain"

    return 0
}

# Clear cache for all sites
clear_all_cache() {
    show_header
    echo -e "${CYAN}XÓA CACHE TẤT CẢ SITES${NC}"
    echo ""

    source "${MODULES_DIR}/site/site-manager.sh"

    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào"
        show_footer
        pause
        return
    fi

    local total=0
    local success=0

    while IFS='|' read -r domain _ _ _ _ _ _; do
        ((total++))
        print_info "[$total] Xóa cache: $domain"

        if clear_site_cache "$domain"; then
            ((success++))
        fi

        echo ""
    done < "$SITES_DB"

    echo ""
    print_info "Đã xóa cache: $success/$total sites"

    log_message "INFO" "Cleared cache for all sites: $success/$total"

    show_footer
    pause
}

# Enable OPcache
enable_opcache() {
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"

    if [[ ! -f "$php_ini" ]]; then
        print_error "File php.ini không tồn tại"
        return 1
    fi

    # Check if OPcache is already enabled
    if grep -q "^opcache.enable=1" "$php_ini"; then
        print_warning "OPcache đã được bật"
        return 1
    fi

    # Enable OPcache
    sed -i 's/;opcache.enable=1/opcache.enable=1/' "$php_ini"
    sed -i 's/opcache.enable=0/opcache.enable=1/' "$php_ini"

    # Configure OPcache
    cat >> "$php_ini" <<EOF

; OPcache Configuration
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
EOF

    reload_phpfpm "$PHP_VERSION"

    print_success "Đã bật OPcache"
    log_message "INFO" "Enabled OPcache"

    return 0
}

# Disable OPcache
disable_opcache() {
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"

    if [[ ! -f "$php_ini" ]]; then
        print_error "File php.ini không tồn tại"
        return 1
    fi

    sed -i 's/opcache.enable=1/opcache.enable=0/' "$php_ini"

    reload_phpfpm "$PHP_VERSION"

    print_success "Đã tắt OPcache"
    log_message "INFO" "Disabled OPcache"

    return 0
}

# Install Redis
install_redis() {
    if command_exists redis-server; then
        print_warning "Redis đã được cài đặt"
        return 1
    fi

    print_info "Đang cài đặt Redis..."

    apt-get update -qq
    apt-get install -y redis-server php-redis

    # Enable Redis
    systemctl enable redis-server
    systemctl start redis-server

    # Configure Redis
    sed -i 's/^# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf
    sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf

    systemctl restart redis-server
    reload_phpfpm "$PHP_VERSION"

    print_success "Đã cài đặt Redis"
    log_message "INFO" "Installed Redis"

    return 0
}

# Uninstall Redis
uninstall_redis() {
    if ! command_exists redis-server; then
        print_warning "Redis chưa được cài đặt"
        return 1
    fi

    print_info "Đang gỡ cài đặt Redis..."

    systemctl stop redis-server
    systemctl disable redis-server

    apt-get remove -y redis-server php-redis
    apt-get autoremove -y

    print_success "Đã gỡ cài đặt Redis"
    log_message "INFO" "Uninstalled Redis"

    return 0
}

# Install Memcached
install_memcached() {
    if command_exists memcached; then
        print_warning "Memcached đã được cài đặt"
        return 1
    fi

    print_info "Đang cài đặt Memcached..."

    apt-get update -qq
    apt-get install -y memcached php-memcached

    # Enable Memcached
    systemctl enable memcached
    systemctl start memcached

    reload_phpfpm "$PHP_VERSION"

    print_success "Đã cài đặt Memcached"
    log_message "INFO" "Installed Memcached"

    return 0
}

# Uninstall Memcached
uninstall_memcached() {
    if ! command_exists memcached; then
        print_warning "Memcached chưa được cài đặt"
        return 1
    fi

    print_info "Đang gỡ cài đặt Memcached..."

    systemctl stop memcached
    systemctl disable memcached

    apt-get remove -y memcached php-memcached
    apt-get autoremove -y

    print_success "Đã gỡ cài đặt Memcached"
    log_message "INFO" "Uninstalled Memcached"

    return 0
}

# Get cache status
get_cache_status() {
    show_header
    echo -e "${CYAN}TRẠNG THÁI CACHE${NC}"
    echo ""

    # OPcache status
    echo -e "${YELLOW}OPcache:${NC}"
    if php -r "echo opcache_get_status() ? 'Enabled' : 'Disabled';" 2>/dev/null; then
        echo ""
    else
        echo "Disabled"
    fi
    echo ""

    # Redis status
    echo -e "${YELLOW}Redis:${NC}"
    if command_exists redis-server; then
        if systemctl is-active --quiet redis-server; then
            echo "Installed and Running"
        else
            echo "Installed but Not Running"
        fi
    else
        echo "Not Installed"
    fi
    echo ""

    # Memcached status
    echo -e "${YELLOW}Memcached:${NC}"
    if command_exists memcached; then
        if systemctl is-active --quiet memcached; then
            echo "Installed and Running"
        else
            echo "Installed but Not Running"
        fi
    else
        echo "Not Installed"
    fi
    echo ""

    show_footer
    pause
}

# Preload cache for a site
preload_cache() {
    local domain=$1

    print_info "Chức năng preload cache sẽ được bổ sung sau"
    print_info "Bạn có thể sử dụng plugin LSCache hoặc các công cụ khác để preload"
}
