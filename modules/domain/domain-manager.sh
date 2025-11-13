#!/bin/bash
# Domain Manager Module
# Quản lý domain aliases, redirects, subdomains

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Add domain alias to existing site
add_domain_alias() {
    local existing_domain=$1
    local new_domain=$2

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$existing_domain"; then
        print_error "Site không tồn tại: $existing_domain"
        return 1
    fi

    local site_info=$(get_site_info "$existing_domain")
    IFS='|' read -r _ site_name _ _ _ site_root _ <<< "$site_info"

    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    # Check if alias already exists
    if grep -q "server_name.*${new_domain}" "$vhost_file"; then
        print_warning "Domain alias đã tồn tại: $new_domain"
        return 1
    fi

    print_info "Đang thêm domain alias: $new_domain -> $existing_domain"

    # Add to server_name directive
    sed -i "/server_name/s/;/ ${new_domain};/" "$vhost_file"

    # Test and reload
    if nginx -t >/dev/null 2>&1; then
        reload_nginx
        print_success "Đã thêm domain alias: $new_domain"
        log_message "INFO" "Added domain alias: $new_domain to $existing_domain"
        return 0
    else
        print_error "Cấu hình Nginx không hợp lệ"
        nginx -t
        return 1
    fi
}

# Remove domain alias
remove_domain_alias() {
    local existing_domain=$1
    local alias_domain=$2

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$existing_domain"; then
        print_error "Site không tồn tại: $existing_domain"
        return 1
    fi

    local site_info=$(get_site_info "$existing_domain")
    IFS='|' read -r _ site_name _ _ _ _ _ <<< "$site_info"

    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    print_info "Đang xóa domain alias: $alias_domain"

    # Remove from server_name
    sed -i "s/ ${alias_domain}//g" "$vhost_file"

    # Test and reload
    if nginx -t >/dev/null 2>&1; then
        reload_nginx
        print_success "Đã xóa domain alias: $alias_domain"
        log_message "INFO" "Removed domain alias: $alias_domain"
        return 0
    else
        print_error "Cấu hình Nginx không hợp lệ"
        nginx -t
        return 1
    fi
}

# Create domain redirect (301/302)
create_domain_redirect() {
    local from_domain=$1
    local to_domain=$2
    local redirect_type=${3:-301}  # 301 permanent, 302 temporary

    local redirect_file="${NGINX_SITES_AVAILABLE}/redirect-${from_domain}.conf"
    local redirect_link="${NGINX_SITES_ENABLED}/redirect-${from_domain}.conf"

    if [[ -f "$redirect_file" ]]; then
        print_warning "Redirect đã tồn tại cho: $from_domain"
        return 1
    fi

    print_info "Đang tạo redirect: $from_domain -> $to_domain ($redirect_type)"

    # Create redirect config
    cat > "$redirect_file" <<EOF
# Domain Redirect: $from_domain -> $to_domain
# Created: $(date)

server {
    listen 80;
    listen [::]:80;
    server_name $from_domain www.$from_domain;

    return $redirect_type https://$to_domain\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $from_domain www.$from_domain;

    # SSL config will be added by Certbot if needed

    return $redirect_type https://$to_domain\$request_uri;
}
EOF

    # Enable redirect
    ln -s "$redirect_file" "$redirect_link"

    # Test and reload
    if nginx -t >/dev/null 2>&1; then
        reload_nginx
        print_success "Đã tạo redirect: $from_domain -> $to_domain"
        log_message "INFO" "Created redirect: $from_domain -> $to_domain ($redirect_type)"

        print_info ""
        print_info "Lưu ý: Để HTTPS redirect hoạt động, cần cài SSL cho $from_domain"
        print_info "Chạy: certbot --nginx -d $from_domain -d www.$from_domain"

        return 0
    else
        print_error "Cấu hình Nginx không hợp lệ"
        nginx -t
        rm -f "$redirect_file" "$redirect_link"
        return 1
    fi
}

# Remove domain redirect
remove_domain_redirect() {
    local from_domain=$1

    local redirect_file="${NGINX_SITES_AVAILABLE}/redirect-${from_domain}.conf"
    local redirect_link="${NGINX_SITES_ENABLED}/redirect-${from_domain}.conf"

    if [[ ! -f "$redirect_file" ]]; then
        print_error "Redirect không tồn tại cho: $from_domain"
        return 1
    fi

    print_info "Đang xóa redirect: $from_domain"

    rm -f "$redirect_link"
    rm -f "$redirect_file"

    reload_nginx
    print_success "Đã xóa redirect: $from_domain"
    log_message "INFO" "Removed redirect: $from_domain"
    return 0
}

# Force WWW redirect
force_www_redirect() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name _ _ _ _ _ <<< "$site_info"

    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    print_info "Đang cấu hình force WWW redirect cho: $domain"

    # Check if already has WWW redirect
    if grep -q "return 301.*www\.$domain" "$vhost_file"; then
        print_warning "WWW redirect đã được cấu hình"
        return 1
    fi

    # Add WWW redirect server block
    cat >> "$vhost_file" <<EOF

# Force WWW redirect
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name $domain;

    return 301 https://www.$domain\$request_uri;
}
EOF

    # Update main server_name to only www
    sed -i "s/server_name $domain www.$domain;/server_name www.$domain;/" "$vhost_file"

    # Test and reload
    if nginx -t >/dev/null 2>&1; then
        reload_nginx
        print_success "Đã cấu hình force WWW redirect"
        log_message "INFO" "Configured force WWW redirect for: $domain"
        return 0
    else
        print_error "Cấu hình Nginx không hợp lệ"
        nginx -t
        return 1
    fi
}

# Force non-WWW redirect
force_non_www_redirect() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name _ _ _ _ _ <<< "$site_info"

    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    print_info "Đang cấu hình force non-WWW redirect cho: $domain"

    # Extract domain without www
    local base_domain=$(echo "$domain" | sed 's/^www\.//')

    # Check if already has non-WWW redirect
    if grep -q "return 301.*https://$base_domain" "$vhost_file"; then
        print_warning "Non-WWW redirect đã được cấu hình"
        return 1
    fi

    # Add non-WWW redirect server block
    cat >> "$vhost_file" <<EOF

# Force non-WWW redirect
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name www.$base_domain;

    return 301 https://$base_domain\$request_uri;
}
EOF

    # Update main server_name to only non-www
    sed -i "s/server_name $base_domain www.$base_domain;/server_name $base_domain;/" "$vhost_file"
    sed -i "s/server_name www.$base_domain $base_domain;/server_name $base_domain;/" "$vhost_file"

    # Test and reload
    if nginx -t >/dev/null 2>&1; then
        reload_nginx
        print_success "Đã cấu hình force non-WWW redirect"
        log_message "INFO" "Configured force non-WWW redirect for: $domain"
        return 0
    else
        print_error "Cấu hình Nginx không hợp lệ"
        nginx -t
        return 1
    fi
}

# Create subdomain as full WordPress site
create_subdomain_site() {
    local subdomain=$1
    local parent_domain=$2

    local full_domain="${subdomain}.${parent_domain}"
    local site_name="${subdomain}_${parent_domain//./_}"

    source "${MODULES_DIR}/site/site-manager.sh"

    print_info "Đang tạo subdomain WordPress site: $full_domain"

    # Check if parent site exists (optional - just for reference)
    if site_exists "$parent_domain"; then
        print_info "Parent domain: $parent_domain (đã tồn tại)"
    fi

    # Check if subdomain already exists
    if site_exists "$full_domain"; then
        print_error "Subdomain đã tồn tại: $full_domain"
        return 1
    fi

    # Create subdomain as a new site with full WordPress installation
    print_info "Tạo subdomain như một WordPress site độc lập..."

    # This will use the same infrastructure as main sites
    # - Separate PHP-FPM pool
    # - Separate database
    # - Separate system user

    add_site

    return $?
}

# Create subdomain with document root pointing to parent site
create_subdomain_alias() {
    local subdomain=$1
    local parent_domain=$2
    local subfolder=${3:-$subdomain}

    local full_domain="${subdomain}.${parent_domain}"

    source "${MODULES_DIR}/site/site-manager.sh"

    if ! site_exists "$parent_domain"; then
        print_error "Parent domain không tồn tại: $parent_domain"
        return 1
    fi

    local site_info=$(get_site_info "$parent_domain")
    IFS='|' read -r _ site_name site_user _ _ site_root _ <<< "$site_info"

    local subdomain_root="${site_root}/${subfolder}"
    local socket_path="${PHP_SOCKET_DIR}/${site_name}.sock"
    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}-${subdomain}.conf"
    local vhost_link="${NGINX_SITES_ENABLED}/${site_name}-${subdomain}.conf"

    print_info "Đang tạo subdomain alias: $full_domain -> $subdomain_root"

    # Create subdomain directory if not exists
    if [[ ! -d "$subdomain_root" ]]; then
        mkdir -p "$subdomain_root"
        chown "${site_user}:${site_user}" "$subdomain_root"
        print_success "Đã tạo thư mục: $subdomain_root"
    fi

    # Create Nginx config for subdomain
    cat > "$vhost_file" <<EOF
# Subdomain: $full_domain
# Parent: $parent_domain
# Created: $(date)

server {
    listen 80;
    listen [::]:80;
    server_name $full_domain;

    root $subdomain_root;
    index index.php index.html index.htm;

    access_log /var/log/nginx/${site_name}-${subdomain}.access.log;
    error_log /var/log/nginx/${site_name}-${subdomain}.error.log;

    # WordPress specific
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${socket_path};
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

    # Enable subdomain
    ln -s "$vhost_file" "$vhost_link"

    # Test and reload
    if nginx -t >/dev/null 2>&1; then
        reload_nginx
        print_success "Đã tạo subdomain alias: $full_domain"
        log_message "INFO" "Created subdomain alias: $full_domain"

        print_info ""
        print_info "Subdomain sử dụng:"
        print_info "- Document root: $subdomain_root"
        print_info "- PHP-FPM pool: ${site_name}"
        print_info "- User: ${site_user}"

        return 0
    else
        print_error "Cấu hình Nginx không hợp lệ"
        nginx -t
        rm -f "$vhost_file" "$vhost_link"
        return 1
    fi
}

# Create wildcard subdomain
create_wildcard_subdomain() {
    local parent_domain=$1
    local document_root=$2

    source "${MODULES_DIR}/site/site-manager.sh"

    if ! site_exists "$parent_domain"; then
        print_error "Parent domain không tồn tại: $parent_domain"
        return 1
    fi

    local site_info=$(get_site_info "$parent_domain")
    IFS='|' read -r _ site_name site_user _ _ site_root _ <<< "$site_info"

    local wildcard_root=${document_root:-$site_root}
    local socket_path="${PHP_SOCKET_DIR}/${site_name}.sock"
    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}-wildcard.conf"
    local vhost_link="${NGINX_SITES_ENABLED}/${site_name}-wildcard.conf"

    print_info "Đang cấu hình wildcard subdomain cho: $parent_domain"

    # Check if wildcard already exists
    if [[ -f "$vhost_file" ]]; then
        print_warning "Wildcard subdomain đã được cấu hình"
        return 1
    fi

    # Create wildcard Nginx config
    cat > "$vhost_file" <<EOF
# Wildcard Subdomain: *.$parent_domain
# Parent: $parent_domain
# Created: $(date)

server {
    listen 80;
    listen [::]:80;
    server_name *.$parent_domain;

    root $wildcard_root;
    index index.php index.html index.htm;

    access_log /var/log/nginx/${site_name}-wildcard.access.log;
    error_log /var/log/nginx/${site_name}-wildcard.error.log;

    # Wildcard subdomain routing
    # Subdomain can be accessed via \$subdomain variable
    set \$subdomain "";
    if (\$host ~* "^([^.]+)\.${parent_domain}$") {
        set \$subdomain \$1;
    }

    # WordPress Multisite subdomain support
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:${socket_path};
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param SUBDOMAIN \$subdomain;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

    # Enable wildcard
    ln -s "$vhost_file" "$vhost_link"

    # Test and reload
    if nginx -t >/dev/null 2>&1; then
        reload_nginx
        print_success "Đã cấu hình wildcard subdomain: *.$parent_domain"
        log_message "INFO" "Created wildcard subdomain for: $parent_domain"

        print_info ""
        print_info "Wildcard subdomain sử dụng:"
        print_info "- Document root: $wildcard_root"
        print_info "- PHP-FPM pool: ${site_name}"
        print_info "- Pattern: *.${parent_domain}"
        print_info ""
        print_warning "Lưu ý: Cần cấu hình DNS wildcard record (*.${parent_domain}) để hoạt động"

        return 0
    else
        print_error "Cấu hình Nginx không hợp lệ"
        nginx -t
        rm -f "$vhost_file" "$vhost_link"
        return 1
    fi
}

# Remove subdomain
remove_subdomain() {
    local subdomain=$1
    local parent_domain=$2

    local full_domain="${subdomain}.${parent_domain}"

    source "${MODULES_DIR}/site/site-manager.sh"

    # Check if it's a full site
    if site_exists "$full_domain"; then
        print_info "Subdomain là một WordPress site độc lập"
        print_info "Sử dụng remove_site để xóa"
        return 1
    fi

    # Check if it's an alias
    if ! site_exists "$parent_domain"; then
        print_error "Parent domain không tồn tại: $parent_domain"
        return 1
    fi

    local site_info=$(get_site_info "$parent_domain")
    IFS='|' read -r _ site_name _ _ _ _ _ <<< "$site_info"

    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}-${subdomain}.conf"
    local vhost_link="${NGINX_SITES_ENABLED}/${site_name}-${subdomain}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Subdomain alias không tồn tại: $full_domain"
        return 1
    fi

    print_info "Đang xóa subdomain alias: $full_domain"

    # Disable and remove
    rm -f "$vhost_link"
    rm -f "$vhost_file"

    reload_nginx
    print_success "Đã xóa subdomain alias: $full_domain"
    log_message "INFO" "Removed subdomain alias: $full_domain"

    print_warning "Lưu ý: Document root không bị xóa, cần xóa thủ công nếu cần"

    return 0
}

# Remove wildcard subdomain
remove_wildcard_subdomain() {
    local parent_domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"

    if ! site_exists "$parent_domain"; then
        print_error "Parent domain không tồn tại: $parent_domain"
        return 1
    fi

    local site_info=$(get_site_info "$parent_domain")
    IFS='|' read -r _ site_name _ _ _ _ _ <<< "$site_info"

    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}-wildcard.conf"
    local vhost_link="${NGINX_SITES_ENABLED}/${site_name}-wildcard.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Wildcard subdomain không tồn tại cho: $parent_domain"
        return 1
    fi

    print_info "Đang xóa wildcard subdomain: *.$parent_domain"

    # Disable and remove
    rm -f "$vhost_link"
    rm -f "$vhost_file"

    reload_nginx
    print_success "Đã xóa wildcard subdomain: *.$parent_domain"
    log_message "INFO" "Removed wildcard subdomain for: $parent_domain"

    return 0
}

# List subdomains for a domain
list_subdomains() {
    local parent_domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"

    if ! site_exists "$parent_domain"; then
        print_error "Parent domain không tồn tại: $parent_domain"
        return 1
    fi

    local site_info=$(get_site_info "$parent_domain")
    IFS='|' read -r _ site_name _ _ _ _ _ <<< "$site_info"

    show_header
    echo -e "${CYAN}SUBDOMAINS CỦA: $parent_domain${NC}"
    echo ""

    # Find subdomain configs
    local subdomain_files=$(find "${NGINX_SITES_AVAILABLE}" -name "${site_name}-*.conf" 2>/dev/null)

    if [[ -z "$subdomain_files" ]]; then
        print_info "Chưa có subdomain nào"
    else
        echo -e "${YELLOW}Subdomain${NC}\t\t\t${YELLOW}Type${NC}\t\t${YELLOW}Status${NC}"
        echo "----------------------------------------------------------------------"

        for file in $subdomain_files; do
            local basename=$(basename "$file" .conf)
            local subdomain_name=$(echo "$basename" | sed "s/${site_name}-//")

            # Check if it's wildcard
            if [[ "$subdomain_name" == "wildcard" ]]; then
                local domain_pattern="*.${parent_domain}"
                local type="Wildcard"
            else
                local domain_pattern="${subdomain_name}.${parent_domain}"
                local type="Alias"
            fi

            # Check if enabled
            local link="${NGINX_SITES_ENABLED}/$(basename "$file")"
            if [[ -L "$link" ]]; then
                local status="Enabled"
            else
                local status="Disabled"
            fi

            printf "%-30s %-20s %s\n" "$domain_pattern" "$type" "$status"
        done
    fi

    echo ""
    show_footer
    pause
}

# List all redirects
list_redirects() {
    show_header
    echo -e "${CYAN}DANH SÁCH REDIRECTS${NC}"
    echo ""

    local redirect_files=$(find "${NGINX_SITES_AVAILABLE}" -name "redirect-*.conf" 2>/dev/null)

    if [[ -z "$redirect_files" ]]; then
        print_info "Chưa có redirect nào"
        show_footer
        pause
        return 0
    fi

    echo -e "${YELLOW}Domain${NC}\t\t\t${YELLOW}Redirect To${NC}\t\t${YELLOW}Type${NC}"
    echo "----------------------------------------------------------------------"

    for file in $redirect_files; do
        local from_domain=$(basename "$file" | sed 's/redirect-//;s/.conf//')
        local to_domain=$(grep "return [0-9]" "$file" | head -1 | awk '{print $3}' | sed 's/https:\/\///;s/\$request_uri;//')
        local redirect_type=$(grep "return [0-9]" "$file" | head -1 | awk '{print $2}')

        printf "%-30s %-30s %s\n" "$from_domain" "$to_domain" "$redirect_type"
    done

    echo ""
    show_footer
    pause
}

# List all domain aliases
list_domain_aliases() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name _ _ _ _ _ <<< "$site_info"

    local vhost_file="${NGINX_SITES_AVAILABLE}/${site_name}.conf"

    if [[ ! -f "$vhost_file" ]]; then
        print_error "Nginx vhost không tồn tại: $site_name"
        return 1
    fi

    print_info "Domain aliases cho: $domain"
    echo ""

    # Extract all domains from server_name
    local domains=$(grep "server_name" "$vhost_file" | head -1 | sed 's/.*server_name //;s/;//' | tr ' ' '\n')

    echo -e "${YELLOW}Domains:${NC}"
    echo "$domains"
    echo ""

    pause
}
