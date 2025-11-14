#!/bin/bash
# Site Manager Module
# Quản lý WordPress sites trên VPS

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Database file for sites
SITES_DB="${CONFIG_DIR}/sites.db"

# Initialize sites database
init_sites_db() {
    if [[ ! -f "$SITES_DB" ]]; then
        touch "$SITES_DB"
        chmod 600 "$SITES_DB"
        log_message "INFO" "Initialized sites database: $SITES_DB"
    fi
}

# Add site to database
add_site_to_db() {
    local domain=$1
    local site_name=$2
    local site_user=$3
    local db_name=$4
    local db_user=$5
    local site_root=$6

    init_sites_db

    # Format: domain|site_name|site_user|db_name|db_user|site_root|created_at
    echo "${domain}|${site_name}|${site_user}|${db_name}|${db_user}|${site_root}|$(date '+%Y-%m-%d %H:%M:%S')" >> "$SITES_DB"
    log_message "INFO" "Added site to database: $domain"
}

# Remove site from database
remove_site_from_db() {
    local domain=$1

    if [[ -f "$SITES_DB" ]]; then
        sed -i "/^${domain}|/d" "$SITES_DB"
        log_message "INFO" "Removed site from database: $domain"
    fi
}

# Check if site exists in database
site_exists() {
    local domain=$1

    if [[ -f "$SITES_DB" ]] && grep -q "^${domain}|" "$SITES_DB"; then
        return 0
    fi
    return 1
}

# Get site info from database
get_site_info() {
    local domain=$1

    if [[ -f "$SITES_DB" ]]; then
        grep "^${domain}|" "$SITES_DB"
    fi
}

# List all sites
list_sites() {
    show_header
    echo -e "${CYAN}DANH SÁCH WORDPRESS SITES${NC}"
    echo ""

    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào được tạo"
        show_footer
        return
    fi

    printf "%-5s %-30s %-20s %-20s %-20s\n" "STT" "DOMAIN" "SITE USER" "DATABASE" "CREATED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local count=1
    while IFS='|' read -r domain site_name site_user db_name db_user site_root created_at; do
        printf "%-5s %-30s %-20s %-20s %-20s\n" "$count" "$domain" "$site_user" "$db_name" "$created_at"
        ((count++))
    done < "$SITES_DB"

    echo ""
    print_info "Tổng số sites: $((count - 1))"
    show_footer
}

# Generate site name from domain
generate_site_name() {
    local domain=$1
    # Remove .com, .vn, .net, etc and replace . with _
    echo "$domain" | sed 's/\.[^.]*$//' | tr '.' '_' | tr '-' '_'
}

# Add new site
add_site() {
    show_header
    echo -e "${CYAN}THÊM WORDPRESS SITE MỚI${NC}"
    echo ""

    # Get domain
    read -p "Nhập tên miền (vd: example.com): " domain
    domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]' | sed 's/^www\.//')

    if [[ -z "$domain" ]]; then
        print_error "Tên miền không được để trống"
        pause
        return 1
    fi

    if ! validate_domain "$domain"; then
        print_error "Tên miền không hợp lệ"
        pause
        return 1
    fi

    if site_exists "$domain"; then
        print_error "Site này đã tồn tại"
        pause
        return 1
    fi

    # Generate site variables
    local site_name=$(generate_site_name "$domain")
    local site_user="${site_name}"
    local db_name="${site_name}_db"
    local db_user="${site_name}_user"
    local db_pass=$(generate_password 20)
    local site_root="${WEB_ROOT}/${domain}"

    echo ""
    print_info "Thông tin site:"
    echo "  Domain: $domain"
    echo "  Site name: $site_name"
    echo "  Site user: $site_user"
    echo "  Database: $db_name"
    echo "  DB user: $db_user"
    echo "  Site root: $site_root"
    echo ""

    if ! confirm_action "Bạn có muốn tiếp tục tạo site này?" "y"; then
        print_warning "Đã hủy"
        pause
        return 1
    fi

    print_info "Đang tạo site..."

    # Step 1: Create system user
    print_info "Bước 1: Tạo system user..."
    if ! id "$site_user" &>/dev/null; then
        useradd -m -s /bin/bash -d "/home/${site_user}" "$site_user"
        if [[ $? -eq 0 ]]; then
            print_success "Đã tạo user: $site_user"
            log_message "INFO" "Created system user: $site_user"
        else
            print_error "Không thể tạo user: $site_user"
            return 1
        fi
    else
        print_warning "User đã tồn tại: $site_user"
    fi

    # Add web server user to site user group (for reading static files)
    if id "$WEB_USER" >/dev/null 2>&1; then
        usermod -a -G "$site_user" "$WEB_USER"
    fi

    # Step 2: Create site directory
    print_info "Bước 2: Tạo thư mục site..."
    mkdir -p "$site_root"
    chown -R "${site_user}:${site_user}" "$site_root"
    chmod 755 "$site_root"
    print_success "Đã tạo thư mục: $site_root"

    # Step 3: Create database
    print_info "Bước 3: Tạo database..."
    source "${MODULES_DIR}/database/database-manager.sh"
    create_database "$db_name" "$db_user" "$db_pass"

    # Step 4: Create PHP-FPM pool
    print_info "Bước 4: Tạo PHP-FPM pool..."
    source "${MODULES_DIR}/phpfpm/phpfpm-manager.sh"
    create_phpfpm_pool "$site_name" "$site_user" "$site_root"

    # Step 5: Create Nginx vhost
    print_info "Bước 5: Tạo Nginx vhost..."
    source "${MODULES_DIR}/nginx/nginx-manager.sh"
    create_nginx_vhost "$domain" "$site_name" "$site_root"

    # Step 6: Install WordPress
    print_info "Bước 6: Cài đặt WordPress..."
    install_wordpress "$site_root" "$site_user" "$db_name" "$db_user" "$db_pass" "$domain"

    # Step 7: Add to database
    add_site_to_db "$domain" "$site_name" "$site_user" "$db_name" "$db_user" "$site_root"

    # Save credentials
    local creds_file="${CONFIG_DIR}/${site_name}_credentials.txt"
    cat > "$creds_file" <<EOF
WordPress Site Credentials
===========================
Domain: $domain
Site Root: $site_root
Site User: $site_user

Database Information:
- DB Name: $db_name
- DB User: $db_user
- DB Password: $db_pass
- DB Host: localhost

Created: $(date '+%Y-%m-%d %H:%M:%S')
EOF
    chmod 600 "$creds_file"

    echo ""
    print_success "Đã tạo site thành công!"
    echo ""
    print_info "Thông tin đăng nhập đã được lưu tại: $creds_file"
    echo ""
    print_info "Bạn có thể truy cập site tại: http://$domain"
    print_info "Để cài SSL, chạy: wpminhminhscript ssl $domain"

    log_message "INFO" "Site created successfully: $domain"
    show_footer
    pause
}

# Install WordPress
install_wordpress() {
    local site_root=$1
    local site_user=$2
    local db_name=$3
    local db_user=$4
    local db_pass=$5
    local domain=$6

    # Download WordPress
    cd /tmp
    if [[ ! -f "latest.tar.gz" ]]; then
        wget -q https://wordpress.org/latest.tar.gz
    fi

    # Extract
    tar -xzf latest.tar.gz

    # Move files
    cp -r wordpress/* "$site_root/"
    rm -rf wordpress

    # Create wp-config.php
    cp "${site_root}/wp-config-sample.php" "${site_root}/wp-config.php"

    # Configure database
    sed -i "s/database_name_here/${db_name}/" "${site_root}/wp-config.php"
    sed -i "s/username_here/${db_user}/" "${site_root}/wp-config.php"
    sed -i "s/password_here/${db_pass}/" "${site_root}/wp-config.php"
    sed -i "s/localhost/localhost/" "${site_root}/wp-config.php"

    # Generate salts
    local salts=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    # Remove old salts
    sed -i "/AUTH_KEY/,/NONCE_SALT/d" "${site_root}/wp-config.php"
    # Add new salts
    sed -i "/DB_COLLATE/a\\${salts}" "${site_root}/wp-config.php"

    # Set permissions
    chown -R "${site_user}:${site_user}" "$site_root"
    find "$site_root" -type d -exec chmod 755 {} \;
    find "$site_root" -type f -exec chmod 644 {} \;

    print_success "Đã cài đặt WordPress"
}

# Remove site
remove_site() {
    show_header
    echo -e "${CYAN}XÓA WORDPRESS SITE${NC}"
    echo ""

    # List sites
    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào được tạo"
        show_footer
        pause
        return
    fi

    echo "Danh sách sites:"
    echo ""

    # Build array of domains
    declare -a domains=()
    local count=1
    while IFS='|' read -r domain site_name site_user db_name db_user site_root created_at; do
        domains+=("$domain")
        echo "  $count. $domain ($site_name)"
        ((count++))
    done < "$SITES_DB"

    echo ""
    read -p "Nhập số thứ tự hoặc tên miền cần xóa: " input
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/^www\.//')

    if [[ -z "$input" ]]; then
        print_error "Không được để trống"
        pause
        return 1
    fi

    # Check if input is a number
    local domain
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        # Input is a number - get domain from array
        local index=$((input - 1))
        if [[ $index -ge 0 ]] && [[ $index -lt ${#domains[@]} ]]; then
            domain="${domains[$index]}"
        else
            print_error "Số thứ tự không hợp lệ"
            pause
            return 1
        fi
    else
        # Input is domain name
        domain="$input"
    fi

    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        pause
        return 1
    fi

    # Get site info
    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name site_user db_name db_user site_root _ <<< "$site_info"

    echo ""
    print_warning "Cảnh báo: Hành động này sẽ xóa:"
    echo "  - Tất cả files của site"
    echo "  - Database"
    echo "  - System user"
    echo "  - PHP-FPM pool"
    echo "  - Nginx vhost"
    echo ""

    if ! confirm_action "Bạn có chắc chắn muốn xóa site này?" "n"; then
        print_warning "Đã hủy"
        pause
        return 1
    fi

    read -p "Nhập lại tên miền để xác nhận: " confirm_domain
    if [[ "$confirm_domain" != "$domain" ]]; then
        print_error "Tên miền không khớp"
        pause
        return 1
    fi

    print_info "Đang xóa site..."

    # Remove Nginx vhost
    print_info "Xóa Nginx vhost..."
    source "${MODULES_DIR}/nginx/nginx-manager.sh"
    remove_nginx_vhost "$site_name"

    # Remove PHP-FPM pool
    print_info "Xóa PHP-FPM pool..."
    source "${MODULES_DIR}/phpfpm/phpfpm-manager.sh"
    remove_phpfpm_pool "$site_name"

    # Remove database
    print_info "Xóa database..."
    source "${MODULES_DIR}/database/database-manager.sh"
    drop_database "$db_name" "$db_user"

    # Remove site files
    print_info "Xóa files..."
    if [[ -d "$site_root" ]]; then
        rm -rf "$site_root"
        print_success "Đã xóa: $site_root"
    fi

    # Remove system user
    print_info "Xóa system user..."
    if id "$site_user" &>/dev/null; then
        userdel -r "$site_user" 2>/dev/null
        print_success "Đã xóa user: $site_user"
    fi

    # Remove from database
    remove_site_from_db "$domain"

    # Remove credentials file
    local creds_file="${CONFIG_DIR}/${site_name}_credentials.txt"
    if [[ -f "$creds_file" ]]; then
        rm -f "$creds_file"
    fi

    echo ""
    print_success "Đã xóa site thành công!"

    log_message "INFO" "Site removed: $domain"
    show_footer
    pause
}

# Show site info
show_site_info() {
    show_header
    echo -e "${CYAN}THÔNG TIN SITE${NC}"
    echo ""

    # List sites
    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào được tạo"
        show_footer
        pause
        return
    fi

    echo "Danh sách sites:"
    echo ""

    # Build array of domains
    declare -a domains=()
    local count=1
    while IFS='|' read -r domain site_name site_user db_name db_user site_root created_at; do
        domains+=("$domain")
        echo "  $count. $domain ($site_name)"
        ((count++))
    done < "$SITES_DB"

    echo ""
    read -p "Nhập số thứ tự hoặc tên miền: " input
    input=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/^www\.//')

    if [[ -z "$input" ]]; then
        print_error "Không được để trống"
        pause
        return 1
    fi

    # Check if input is a number
    local domain
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        # Input is a number - get domain from array
        local index=$((input - 1))
        if [[ $index -ge 0 ]] && [[ $index -lt ${#domains[@]} ]]; then
            domain="${domains[$index]}"
        else
            print_error "Số thứ tự không hợp lệ"
            pause
            return 1
        fi
    else
        # Input is domain name
        domain="$input"
    fi

    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        pause
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r domain site_name site_user db_name db_user site_root created_at <<< "$site_info"

    show_header
    echo -e "${CYAN}THÔNG TIN SITE: $domain${NC}"
    echo ""
    echo "Domain: $domain"
    echo "Site Name: $site_name"
    echo "Site User: $site_user"
    echo "Database: $db_name"
    echo "DB User: $db_user"
    echo "Site Root: $site_root"
    echo "Created: $created_at"
    echo ""

    # Check services
    print_info "Trạng thái dịch vụ:"

    # Check Nginx
    if [[ -f "${NGINX_SITES_ENABLED}/${site_name}.conf" ]]; then
        print_success "Nginx vhost: Active"
    else
        print_error "Nginx vhost: Inactive"
    fi

    # Check PHP-FPM
    if [[ -f "${PHP_FPM_POOL_DIR}/${site_name}.conf" ]]; then
        print_success "PHP-FPM pool: Active"
    else
        print_error "PHP-FPM pool: Inactive"
    fi

    # Check files
    if [[ -d "$site_root" ]]; then
        local size=$(du -sh "$site_root" | cut -f1)
        print_success "Site files: $size"
    else
        print_error "Site files: Not found"
    fi

    show_footer
    pause
}
