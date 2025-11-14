#!/bin/bash
# Nginx Manager Module
# Quản lý Nginx vhosts cho WordPress sites

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Create Nginx vhost for a site
create_nginx_vhost() {
    local domain=$1
    local site_name=$2
    local site_root=$3

    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"
    local vhost_link="${NGINX_SITES_ENABLED}/${site_name}.conf"
    local socket_path="${PHP_SOCKET_DIR}/${site_name}.sock"
    local template_file="${TEMPLATES_DIR}/nginx/wordpress.conf"

    if [[ -f "$vhost_file" ]]; then
        print_warning "Nginx vhost đã tồn tại: $site_name"
        return 1
    fi

    # Create vhost from template
    cp "$template_file" "$vhost_file"

    # Replace variables
    sed -i "s|{{DOMAIN}}|${domain}|g" "$vhost_file"
    sed -i "s|{{SITE_NAME}}|${site_name}|g" "$vhost_file"
    sed -i "s|{{SITE_ROOT}}|${site_root}|g" "$vhost_file"
    sed -i "s|{{SOCKET_PATH}}|${socket_path}|g" "$vhost_file"
    sed -i "s|{{CLIENT_MAX_BODY_SIZE}}|${NGINX_CLIENT_MAX_BODY_SIZE}|g" "$vhost_file"

    # Enable site
    ln -s "$vhost_file" "$vhost_link"

    # Test Nginx configuration
    if nginx -t >/dev/null 2>&1; then
        reload_nginx
        print_success "Đã tạo Nginx vhost: $site_name"
        log_message "INFO" "Created Nginx vhost: $site_name"
        return 0
    else
        print_error "Cấu hình Nginx không hợp lệ"
        nginx -t
        rm -f "$vhost_file" "$vhost_link"
        return 1
    fi
}

# Remove Nginx vhost
remove_nginx_vhost() {
    local site_name=$1
    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"
    local vhost_link="${NGINX_SITES_ENABLED}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_warning "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    # Disable site
    rm -f "$vhost_link"

    # Remove vhost file
    rm -f "$vhost_file"

    reload_nginx
    print_success "Đã xóa Nginx vhost: $site_name"
    log_message "INFO" "Removed Nginx vhost: $site_name"
    return 0
}

# Enable site
enable_nginx_site() {
    local site_name=$1
    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"
    local vhost_link="${NGINX_SITES_ENABLED}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    if [[ -L "$vhost_link" ]]; then
        print_warning "Site đã được enable: $site_name"
        return 1
    fi

    ln -s "$vhost_file" "$vhost_link"
    reload_nginx
    print_success "Đã enable site: $site_name"
    log_message "INFO" "Enabled Nginx site: $site_name"
    return 0
}

# Disable site
disable_nginx_site() {
    local site_name=$1
    local vhost_link="${NGINX_SITES_ENABLED}/${site_name}.conf"

    if [[ ! -L "$vhost_link" ]]; then
        print_warning "Site chưa được enable: $site_name"
        return 1
    fi

    rm -f "$vhost_link"
    reload_nginx
    print_success "Đã disable site: $site_name"
    log_message "INFO" "Disabled Nginx site: $site_name"
    return 0
}

# List Nginx vhosts
list_nginx_vhosts() {
    show_header
    echo -e "${CYAN}DANH SÁCH NGINX VHOSTS${NC}"
    echo ""

    if [[ ! -d "$NGINX_SITES_AVAILABLE" ]]; then
        print_error "Thư mục Nginx sites không tồn tại"
        show_footer
        pause
        return 1
    fi

    local count=0
    printf "%-5s %-30s %-10s\n" "STT" "SITE NAME" "STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for vhost_file in "${NGINX_SITES_AVAILABLE}"/*.conf; do
        if [[ -f "$vhost_file" ]]; then
            local site_name=$(basename "$vhost_file" .conf)
            if [[ "$site_name" != "default" ]]; then
                ((count++))
                local vhost_link="${NGINX_SITES_ENABLED}/${site_name}.conf"
                if [[ -L "$vhost_link" ]]; then
                    printf "%-5s %-30s ${GREEN}%-10s${NC}\n" "$count" "$site_name" "ENABLED"
                else
                    printf "%-5s %-30s ${RED}%-10s${NC}\n" "$count" "$site_name" "DISABLED"
                fi
            fi
        fi
    done

    if [[ $count -eq 0 ]]; then
        print_warning "Chưa có vhost nào được tạo"
    else
        echo ""
        print_info "Tổng số vhosts: $count"
    fi

    show_footer
    pause
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    local domain=$1
    local site_name=$2

    if ! command_exists certbot; then
        print_error "Certbot chưa được cài đặt"
        print_info "Cài đặt bằng: apt install certbot python3-certbot-nginx"
        return 1
    fi

    print_info "Đang cài đặt SSL cho: $domain"

    certbot --nginx -d "$domain" -d "www.${domain}" --non-interactive --agree-tos --register-unsafely-without-email

    if [[ $? -eq 0 ]]; then
        print_success "Đã cài đặt SSL thành công cho: $domain"
        log_message "INFO" "SSL installed for: $domain"
        return 0
    else
        print_error "Không thể cài đặt SSL cho: $domain"
        log_message "ERROR" "Failed to install SSL for: $domain"
        return 1
    fi
}

# Renew all SSL certificates
renew_ssl() {
    print_info "Đang gia hạn SSL certificates..."

    if ! command_exists certbot; then
        print_error "Certbot chưa được cài đặt"
        return 1
    fi

    certbot renew

    if [[ $? -eq 0 ]]; then
        print_success "Đã gia hạn SSL thành công"
        log_message "INFO" "SSL certificates renewed"
        return 0
    else
        print_error "Không thể gia hạn SSL"
        log_message "ERROR" "Failed to renew SSL certificates"
        return 1
    fi
}

# Show vhost configuration
show_vhost_config() {
    local site_name=$1
    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    show_header
    echo -e "${CYAN}CẤU HÌNH NGINX VHOST: $site_name${NC}"
    echo ""
    cat "$vhost_file"
    show_footer
    pause
}

# Enable FastCGI cache for site
enable_fastcgi_cache() {
    local site_name=$1
    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    # Check if already enabled
    if grep -q "fastcgi_cache WORDPRESS" "$vhost_file"; then
        print_warning "FastCGI cache đã được bật cho site này"
        return 1
    fi

    # Uncomment cache lines
    sed -i 's/# fastcgi_cache/fastcgi_cache/g' "$vhost_file"

    reload_nginx
    print_success "Đã bật FastCGI cache cho: $site_name"
    log_message "INFO" "Enabled FastCGI cache for: $site_name"
    return 0
}

# Disable FastCGI cache for site
disable_fastcgi_cache() {
    local site_name=$1
    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    # Comment cache lines
    sed -i 's/fastcgi_cache/# fastcgi_cache/g' "$vhost_file"

    reload_nginx
    print_success "Đã tắt FastCGI cache cho: $site_name"
    log_message "INFO" "Disabled FastCGI cache for: $site_name"
    return 0
}

# Add rate limiting for login
enable_login_rate_limit() {
    local nginx_conf="/etc/nginx/nginx.conf"

    # Check if rate limit zone already exists
    if grep -q "limit_req_zone.*login" "$nginx_conf"; then
        print_warning "Login rate limit đã được cấu hình"
        return 1
    fi

    # Add rate limit zone to http block
    sed -i '/http {/a \    limit_req_zone $binary_remote_addr zone=login:10m rate=2r/m;' "$nginx_conf"

    reload_nginx
    print_success "Đã bật login rate limiting"
    log_message "INFO" "Enabled login rate limiting"
    return 0
}

# Get Nginx status
get_nginx_status() {
    if systemctl is-active --quiet nginx; then
        echo "ACTIVE"
        return 0
    else
        echo "INACTIVE"
        return 1
    fi
}

# Test Nginx configuration
test_nginx_config() {
    show_header
    echo -e "${CYAN}TEST NGINX CONFIGURATION${NC}"
    echo ""

    nginx -t

    show_footer
    pause
}
