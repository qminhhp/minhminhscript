#!/bin/bash
# WordPress Advanced Manager Module
# Tính năng nâng cao cho WordPress (tích hợp từ WPTangToc OLS)

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Check if WP-CLI is installed
check_wpcli() {
    if ! command_exists wp; then
        print_error "WP-CLI chưa được cài đặt"
        print_info "Cài đặt bằng: curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp"
        return 1
    fi
    return 0
}

# Install WP-CLI package if not exists
install_wpcli_package() {
    local package=$1
    local package_check=$2

    if ! wp package list --allow-root 2>/dev/null | grep -q "$package_check"; then
        print_info "Đang cài đặt WP-CLI package: $package_check"
        wp package install "$package" --allow-root >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            print_success "Đã cài đặt package: $package_check"
            return 0
        else
            print_error "Không thể cài đặt package: $package_check"
            return 1
        fi
    fi
    return 0
}

# Magic Login Link - Tạo link đăng nhập một lần
magic_login_link() {
    local domain=$1

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name _ _ _ site_root _ <<< "$site_info"

    # Check if WordPress exists
    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang tạo Magic Login Link cho: $domain"

    # Install wp-cli-login-command package
    install_wpcli_package "aaemnnosttv/wp-cli-login-command" "wp-cli-login-command"

    # Install wp-cli-login-server plugin
    local plugin_path="${site_root}/wp-content/plugins/wp-cli-login-server"
    if [[ ! -d "$plugin_path" ]]; then
        print_info "Cài đặt plugin WP CLI Login Server..."
        wp login install --activate --path="$site_root" --allow-root >/dev/null 2>&1

        # Fix permissions
        source "${MODULES_DIR}/site/site-manager.sh"
        local site_info=$(get_site_info "$domain")
        IFS='|' read -r _ site_name site_user _ _ _ _ <<< "$site_info"
        chown -R "${site_user}:${site_user}" "$plugin_path"
        find "$plugin_path" -type d -exec chmod 755 {} \;
        find "$plugin_path" -type f -exec chmod 644 {} \;
    fi

    # Get first admin user
    local admin_user=$(wp user list --role=administrator --fields=user_login --path="$site_root" --allow-root 2>/dev/null | sed '/user_login/d' | head -1)

    if [[ -z "$admin_user" ]]; then
        print_error "Không tìm thấy admin user"
        return 1
    fi

    # Create magic login link
    local magic_link=$(wp login create "$admin_user" --path="$site_root" --allow-root 2>/dev/null | grep 'http')

    if [[ -n "$magic_link" ]]; then
        echo ""
        print_success "Đã tạo Magic Login Link thành công!"
        echo ""
        print_info "User: $admin_user"
        print_info "Link: $magic_link"
        echo ""
        print_warning "Link này chỉ có thể sử dụng MỘT LẦN duy nhất"
        print_warning "Link sẽ tự động hết hạn sau khi sử dụng"
        echo ""
        log_message "INFO" "Created magic login link for: $domain - user: $admin_user"
        return 0
    else
        print_error "Không thể tạo magic login link"
        return 1
    fi
}

# WordPress Health Check - Kiểm tra sức khỏe toàn diện
wordpress_health_check() {
    local domain=$1

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang kiểm tra sức khỏe WordPress: $domain"
    echo ""

    # Install doctor-command package
    install_wpcli_package "git@github.com:wp-cli/doctor-command.git" "wp-cli/doctor-command"

    # Run all health checks
    wp doctor check --all --path="$site_root" --allow-root

    log_message "INFO" "WordPress health check completed for: $domain"
}

# Check Autoload Database - Kiểm tra dữ liệu autoload
check_autoload() {
    local domain=$1

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang kiểm tra Autoload Database: $domain"
    echo ""

    # Install doctor-command package
    install_wpcli_package "git@github.com:wp-cli/doctor-command.git" "wp-cli/doctor-command"

    # Check autoload size
    wp doctor check autoload-options-size --path="$site_root" --allow-root

    log_message "INFO" "Autoload check completed for: $domain"
}

# Hook Speed Profiling - Đo tốc độ hook
hook_speed_profiling() {
    local domain=$1

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang kiểm tra tốc độ Hook: $domain"
    echo ""

    # Install profile-command package
    install_wpcli_package "wp-cli/profile-command" "wp-cli/profile-command"

    # Profile hooks
    wp profile hook --path="$site_root" --allow-root

    log_message "INFO" "Hook speed profiling completed for: $domain"
}

# Scan Base64 Malware - Quét mã độc
scan_base64_malware() {
    local domain=$1

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang quét mã độc Base64: $domain"
    echo ""

    # Install doctor-command package
    install_wpcli_package "git@github.com:wp-cli/doctor-command.git" "wp-cli/doctor-command"

    # Check file-eval (base64_decode, eval)
    local result=$(wp doctor check file-eval --path="$site_root" --allow-root 2>&1)

    echo "$result"
    echo ""

    if echo "$result" | grep -q "success"; then
        print_success "Không phát hiện mã độc Base64"
    else
        print_error "Phát hiện vấn đề bảo mật! Vui lòng kiểm tra kỹ"
    fi

    log_message "INFO" "Base64 malware scan completed for: $domain"
}

# Regenerate Thumbnails - Tái tạo thumbnail
regenerate_thumbnails() {
    local domain=$1
    local mode=${2:-"missing"}  # all or missing

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    if [[ "$mode" == "all" ]]; then
        print_info "Đang tái tạo TẤT CẢ thumbnails: $domain"
        wp media regenerate --yes --path="$site_root" --allow-root
    else
        print_info "Đang tái tạo thumbnails còn thiếu: $domain"
        wp media regenerate --only-missing --yes --path="$site_root" --allow-root
    fi

    if [[ $? -eq 0 ]]; then
        print_success "Đã tái tạo thumbnails thành công"
        log_message "INFO" "Regenerated thumbnails for: $domain (mode: $mode)"
        return 0
    else
        print_error "Không thể tái tạo thumbnails"
        return 1
    fi
}

# Search & Replace Database
search_replace_db() {
    local domain=$1
    local search=$2
    local replace=$3
    local dry_run=${4:-"yes"}

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    if [[ "$dry_run" == "yes" ]]; then
        print_info "Đang tìm kiếm (dry-run): '$search' → '$replace'"
        wp search-replace "$search" "$replace" --dry-run --path="$site_root" --allow-root
    else
        print_warning "CẢNH BÁO: Hành động này sẽ thay đổi database!"
        echo ""
        if ! confirm_action "Bạn có chắc chắn muốn thực hiện thay đổi?" "n"; then
            print_info "Đã hủy"
            return 1
        fi

        print_info "Đang thực hiện: '$search' → '$replace'"
        wp search-replace "$search" "$replace" --path="$site_root" --allow-root

        if [[ $? -eq 0 ]]; then
            print_success "Đã thay đổi thành công"
            log_message "INFO" "Search-replace completed for: $domain - '$search' to '$replace'"
            return 0
        else
            print_error "Không thể thực hiện thay đổi"
            return 1
        fi
    fi
}

# Change Database Prefix
change_db_prefix() {
    local domain=$1
    local new_prefix=$2

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ db_name _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_warning "CẢNH BÁO: Thay đổi table prefix là thao tác nguy hiểm!"
    echo ""
    print_info "Prefix mới: $new_prefix"
    echo ""

    if ! confirm_action "Bạn có chắc chắn muốn thay đổi prefix?" "n"; then
        print_info "Đã hủy"
        return 1
    fi

    # Backup database first
    print_info "Đang backup database trước khi thay đổi..."
    source "${MODULES_DIR}/database/database-manager.sh"
    backup_database "$db_name"

    print_info "Đang thay đổi table prefix..."

    # Install db-prefix-command if available, or do it manually
    # This is a complex operation, using wp-cli's db commands

    # Get current prefix
    local current_prefix=$(grep '$table_prefix' "${site_root}/wp-config.php" | cut -d "'" -f 2)

    print_info "Current prefix: $current_prefix"
    print_info "New prefix: $new_prefix"

    # Update wp-config.php
    sed -i "s/\$table_prefix = '${current_prefix}';/\$table_prefix = '${new_prefix}';/" "${site_root}/wp-config.php"

    # Rename all tables
    local tables=$(wp db query "SHOW TABLES LIKE '${current_prefix}%'" --path="$site_root" --allow-root --skip-column-names)

    for table in $tables; do
        local new_table=$(echo "$table" | sed "s/^${current_prefix}/${new_prefix}/")
        print_info "Renaming: $table → $new_table"
        wp db query "RENAME TABLE \`$table\` TO \`$new_table\`" --path="$site_root" --allow-root
    done

    # Update options table
    wp db query "UPDATE \`${new_prefix}options\` SET option_name = REPLACE(option_name, '${current_prefix}', '${new_prefix}') WHERE option_name LIKE '${current_prefix}%'" --path="$site_root" --allow-root

    # Update usermeta table
    wp db query "UPDATE \`${new_prefix}usermeta\` SET meta_key = REPLACE(meta_key, '${current_prefix}', '${new_prefix}') WHERE meta_key LIKE '${current_prefix}%'" --path="$site_root" --allow-root

    print_success "Đã thay đổi table prefix thành công"
    print_info "Prefix mới: $new_prefix"
    log_message "INFO" "Changed database prefix for: $domain - $current_prefix to $new_prefix"
}

# Disable XML-RPC
disable_xmlrpc() {
    local domain=$1

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang tắt XML-RPC cho: $domain"

    # Add filter to disable XML-RPC
    local functions_file="${site_root}/wp-content/themes/$(wp theme list --status=active --field=name --path="$site_root" --allow-root 2>/dev/null | head -1)/functions.php"

    if [[ -f "$functions_file" ]]; then
        # Check if already disabled
        if grep -q "xmlrpc_enabled" "$functions_file"; then
            print_warning "XML-RPC đã được tắt trước đó"
            return 0
        fi

        # Add code to disable XML-RPC
        cat >> "$functions_file" << 'EOF'

// Disable XML-RPC - Added by WP Minhminh Script
add_filter('xmlrpc_enabled', '__return_false');
EOF

        print_success "Đã tắt XML-RPC thành công"
        log_message "INFO" "Disabled XML-RPC for: $domain"
        return 0
    else
        print_error "Không tìm thấy functions.php của theme"
        return 1
    fi
}

# Update WordPress Core
update_wordpress_core() {
    local domain=$1

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ db_name _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang kiểm tra cập nhật WordPress Core: $domain"

    # Check for updates
    local update_available=$(wp core check-update --path="$site_root" --allow-root --format=count)

    if [[ "$update_available" == "0" ]]; then
        print_success "WordPress đã là phiên bản mới nhất"
        return 0
    fi

    print_info "Có cập nhật mới cho WordPress"

    if ! confirm_action "Bạn có muốn cập nhật WordPress?" "y"; then
        print_info "Đã hủy"
        return 1
    fi

    # Backup database first
    print_info "Đang backup database..."
    source "${MODULES_DIR}/database/database-manager.sh"
    backup_database "$db_name"

    # Update WordPress
    print_info "Đang cập nhật WordPress..."
    wp core update --path="$site_root" --allow-root

    if [[ $? -eq 0 ]]; then
        print_success "Đã cập nhật WordPress thành công"
        log_message "INFO" "Updated WordPress core for: $domain"

        # Update database if needed
        wp core update-db --path="$site_root" --allow-root

        return 0
    else
        print_error "Không thể cập nhật WordPress"
        return 1
    fi
}

# Update All Plugins
update_all_plugins() {
    local domain=$1

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang kiểm tra cập nhật Plugins: $domain"

    # List plugins with updates
    local plugins_to_update=$(wp plugin list --update=available --path="$site_root" --allow-root --format=count)

    if [[ "$plugins_to_update" == "0" ]]; then
        print_success "Tất cả plugins đã là phiên bản mới nhất"
        return 0
    fi

    print_info "Có $plugins_to_update plugin(s) cần cập nhật"
    wp plugin list --update=available --path="$site_root" --allow-root

    echo ""
    if ! confirm_action "Bạn có muốn cập nhật tất cả plugins?" "y"; then
        print_info "Đã hủy"
        return 1
    fi

    # Update all plugins
    print_info "Đang cập nhật plugins..."
    wp plugin update --all --path="$site_root" --allow-root

    if [[ $? -eq 0 ]]; then
        print_success "Đã cập nhật plugins thành công"
        log_message "INFO" "Updated all plugins for: $domain"
        return 0
    else
        print_error "Một số plugins không thể cập nhật"
        return 1
    fi
}

# Update All Themes
update_all_themes() {
    local domain=$1

    if ! check_wpcli; then
        return 1
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang kiểm tra cập nhật Themes: $domain"

    # List themes with updates
    local themes_to_update=$(wp theme list --update=available --path="$site_root" --allow-root --format=count)

    if [[ "$themes_to_update" == "0" ]]; then
        print_success "Tất cả themes đã là phiên bản mới nhất"
        return 0
    fi

    print_info "Có $themes_to_update theme(s) cần cập nhật"
    wp theme list --update=available --path="$site_root" --allow-root

    echo ""
    if ! confirm_action "Bạn có muốn cập nhật tất cả themes?" "y"; then
        print_info "Đã hủy"
        return 1
    fi

    # Update all themes
    print_info "Đang cập nhật themes..."
    wp theme update --all --path="$site_root" --allow-root

    if [[ $? -eq 0 ]]; then
        print_success "Đã cập nhật themes thành công"
        log_message "INFO" "Updated all themes for: $domain"
        return 0
    else
        print_error "Một số themes không thể cập nhật"
        return 1
    fi
}

# Update All Sites on VPS
update_all_sites() {
    show_header
    echo -e "${CYAN}CẬP NHẬT TẤT CẢ SITES${NC}"
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
    local failed=0

    print_info "Các bước sẽ thực hiện:"
    echo "  1. Cập nhật WordPress Core"
    echo "  2. Cập nhật Plugins"
    echo "  3. Cập nhật Themes"
    echo ""

    if ! confirm_action "Bạn có muốn cập nhật TẤT CẢ sites?" "n"; then
        print_warning "Đã hủy"
        pause
        return
    fi

    echo ""
    print_info "Bắt đầu cập nhật..."
    echo ""

    while IFS='|' read -r domain _ _ _ _ _ _; do
        ((total++))
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_info "[$total] Đang cập nhật: $domain"
        echo ""

        # Update core
        update_wordpress_core "$domain"

        # Update plugins
        update_all_plugins "$domain"

        # Update themes
        update_all_themes "$domain"

        if [[ $? -eq 0 ]]; then
            ((success++))
            print_success "Hoàn tất cập nhật: $domain"
        else
            ((failed++))
            print_error "Có lỗi khi cập nhật: $domain"
        fi

        echo ""
    done < "$SITES_DB"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "Tổng kết:"
    echo "  - Tổng số sites: $total"
    echo "  - Thành công: $success"
    echo "  - Thất bại: $failed"

    log_message "INFO" "Update all sites completed: $success/$total successful"

    show_footer
    pause
}
