#!/bin/bash
# PHP-FPM Manager Module
# Quản lý PHP-FPM pools riêng biệt cho từng site

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Create PHP-FPM pool for a site
create_phpfpm_pool() {
    local site_name=$1
    local site_user=$2
    local site_root=$3

    local pool_file="${PHP_FPM_POOL_DIR}/${site_name}.conf"
    local socket_path="${PHP_SOCKET_DIR}/${site_name}.sock"
    local template_file="${TEMPLATES_DIR}/phpfpm/pool.conf"

    if [[ -f "$pool_file" ]]; then
        print_warning "PHP-FPM pool đã tồn tại: $site_name"
        return 1
    fi

    # Create pool from template
    cp "$template_file" "$pool_file"

    # Replace variables
    sed -i "s|{{SITE_NAME}}|${site_name}|g" "$pool_file"
    sed -i "s|{{SITE_USER}}|${site_user}|g" "$pool_file"
    sed -i "s|{{SITE_ROOT}}|${site_root}|g" "$pool_file"
    sed -i "s|{{SOCKET_PATH}}|${socket_path}|g" "$pool_file"
    sed -i "s|{{MAX_CHILDREN}}|${PHP_MAX_CHILDREN}|g" "$pool_file"
    sed -i "s|{{START_SERVERS}}|${PHP_START_SERVERS}|g" "$pool_file"
    sed -i "s|{{MIN_SPARE_SERVERS}}|${PHP_MIN_SPARE_SERVERS}|g" "$pool_file"
    sed -i "s|{{MAX_SPARE_SERVERS}}|${PHP_MAX_SPARE_SERVERS}|g" "$pool_file"
    sed -i "s|{{MEMORY_LIMIT}}|${PHP_MEMORY_LIMIT}|g" "$pool_file"
    sed -i "s|{{MAX_EXECUTION_TIME}}|${PHP_MAX_EXECUTION_TIME}|g" "$pool_file"
    sed -i "s|{{UPLOAD_MAX_FILESIZE}}|${PHP_UPLOAD_MAX_FILESIZE}|g" "$pool_file"
    sed -i "s|{{POST_MAX_SIZE}}|${PHP_POST_MAX_SIZE}|g" "$pool_file"

    # Create log directory
    ensure_directory "/var/log/php-fpm"

    # Test PHP-FPM configuration
    if ${PHP_FPM_SERVICE} -t >/dev/null 2>&1; then
        reload_phpfpm
        print_success "Đã tạo PHP-FPM pool: $site_name"
        log_message "INFO" "Created PHP-FPM pool: $site_name"
        return 0
    else
        print_error "Cấu hình PHP-FPM không hợp lệ"
        ${PHP_FPM_SERVICE} -t
        rm -f "$pool_file"
        return 1
    fi
}

# Remove PHP-FPM pool
remove_phpfpm_pool() {
    local site_name=$1
    local pool_file="${PHP_FPM_POOL_DIR}/${site_name}.conf"

    if [[ ! -f "$pool_file" ]]; then
        print_warning "PHP-FPM pool không tồn tại: $site_name"
        return 1
    fi

    rm -f "$pool_file"
    reload_phpfpm
    print_success "Đã xóa PHP-FPM pool: $site_name"
    log_message "INFO" "Removed PHP-FPM pool: $site_name"
    return 0
}

# List PHP-FPM pools
list_phpfpm_pools() {
    show_header
    echo -e "${CYAN}DANH SÁCH PHP-FPM POOLS${NC}"
    echo ""

    if [[ ! -d "$PHP_FPM_POOL_DIR" ]]; then
        print_error "Thư mục PHP-FPM pool không tồn tại"
        show_footer
        pause
        return 1
    fi

    local count=0
    for pool_file in "${PHP_FPM_POOL_DIR}"/*.conf; do
        if [[ -f "$pool_file" ]]; then
            local pool_name=$(basename "$pool_file" .conf)
            if [[ "$pool_name" != "www" ]]; then
                ((count++))
                echo "$count. $pool_name"
            fi
        fi
    done

    if [[ $count -eq 0 ]]; then
        print_warning "Chưa có pool nào được tạo"
    else
        echo ""
        print_info "Tổng số pools: $count"
    fi

    show_footer
    pause
}

# Restart PHP-FPM pool
restart_phpfpm_pool() {
    local site_name=$1
    local pool_file="${PHP_FPM_POOL_DIR}/${site_name}.conf"

    if [[ ! -f "$pool_file" ]]; then
        print_error "PHP-FPM pool không tồn tại: $site_name"
        return 1
    fi

    # Get pool processes
    local pool_pids=$(ps aux | grep "php-fpm: pool ${site_name}" | grep -v grep | awk '{print $2}')

    if [[ -n "$pool_pids" ]]; then
        echo "$pool_pids" | xargs kill -USR2
        print_success "Đã restart PHP-FPM pool: $site_name"
        log_message "INFO" "Restarted PHP-FPM pool: $site_name"
    else
        print_warning "Pool không có process nào đang chạy"
        reload_phpfpm
    fi

    return 0
}

# Get pool status
get_pool_status() {
    local site_name=$1
    local pool_file="${PHP_FPM_POOL_DIR}/${site_name}.conf"

    if [[ ! -f "$pool_file" ]]; then
        echo "NOT_FOUND"
        return 1
    fi

    local pool_pids=$(ps aux | grep "php-fpm: pool ${site_name}" | grep -v grep)

    if [[ -n "$pool_pids" ]]; then
        echo "ACTIVE"
        return 0
    else
        echo "INACTIVE"
        return 1
    fi
}

# Update pool configuration
update_pool_config() {
    local site_name=$1
    local config_key=$2
    local config_value=$3

    local pool_file="${PHP_FPM_POOL_DIR}/${site_name}.conf"

    if [[ ! -f "$pool_file" ]]; then
        print_error "PHP-FPM pool không tồn tại: $site_name"
        return 1
    fi

    # Update configuration
    case "$config_key" in
        "max_children")
            sed -i "s/^pm.max_children = .*/pm.max_children = ${config_value}/" "$pool_file"
            ;;
        "memory_limit")
            sed -i "s/^php_admin_value\[memory_limit\] = .*/php_admin_value[memory_limit] = ${config_value}/" "$pool_file"
            ;;
        "max_execution_time")
            sed -i "s/^php_admin_value\[max_execution_time\] = .*/php_admin_value[max_execution_time] = ${config_value}/" "$pool_file"
            ;;
        *)
            print_error "Config key không hợp lệ: $config_key"
            return 1
            ;;
    esac

    # Test and reload
    if ${PHP_FPM_SERVICE} -t >/dev/null 2>&1; then
        reload_phpfpm
        print_success "Đã cập nhật cấu hình pool: $site_name"
        log_message "INFO" "Updated pool config: $site_name - $config_key=$config_value"
        return 0
    else
        print_error "Cấu hình PHP-FPM không hợp lệ"
        return 1
    fi
}

# Show pool configuration
show_pool_config() {
    local site_name=$1
    local pool_file="${PHP_FPM_POOL_DIR}/${site_name}.conf"

    if [[ ! -f "$pool_file" ]]; then
        print_error "PHP-FPM pool không tồn tại: $site_name"
        return 1
    fi

    show_header
    echo -e "${CYAN}CẤU HÌNH PHP-FPM POOL: $site_name${NC}"
    echo ""
    cat "$pool_file"
    show_footer
    pause
}

# Optimize pool for site
optimize_pool() {
    local site_name=$1
    local optimization_level=$2  # low, medium, high

    case "$optimization_level" in
        "low")
            update_pool_config "$site_name" "max_children" "3"
            update_pool_config "$site_name" "memory_limit" "128M"
            ;;
        "medium")
            update_pool_config "$site_name" "max_children" "5"
            update_pool_config "$site_name" "memory_limit" "256M"
            ;;
        "high")
            update_pool_config "$site_name" "max_children" "10"
            update_pool_config "$site_name" "memory_limit" "512M"
            ;;
        *)
            print_error "Optimization level không hợp lệ: $optimization_level"
            return 1
            ;;
    esac

    print_success "Đã tối ưu pool: $site_name (level: $optimization_level)"
    log_message "INFO" "Optimized pool: $site_name - level: $optimization_level"
}
