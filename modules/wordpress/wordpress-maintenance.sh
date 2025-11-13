#!/bin/bash
# WordPress Maintenance Module
# Các tính năng bảo trì và tối ưu WordPress

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Enable Maintenance Mode
enable_maintenance_mode() {
    local domain=$1

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

    # Create .maintenance file
    cat > "${site_root}/.maintenance" << 'EOF'
<?php
$upgrading = time();
EOF

    print_success "Đã bật chế độ bảo trì cho: $domain"
    log_message "INFO" "Enabled maintenance mode for: $domain"
}

# Disable Maintenance Mode
disable_maintenance_mode() {
    local domain=$1

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

    # Remove .maintenance file
    if [[ -f "${site_root}/.maintenance" ]]; then
        rm -f "${site_root}/.maintenance"
        print_success "Đã tắt chế độ bảo trì cho: $domain"
        log_message "INFO" "Disabled maintenance mode for: $domain"
    else
        print_warning "Site không ở chế độ bảo trì"
    fi
}

# Change Salt Keys
change_salt_keys() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-config.php" ]]; then
        print_error "Không tìm thấy wp-config.php"
        return 1
    fi

    print_warning "CẢNH BÁO: Thay đổi salt keys sẽ đăng xuất TẤT CẢ users"
    echo ""

    if ! confirm_action "Bạn có chắc chắn muốn thay đổi salt keys?" "n"; then
        print_info "Đã hủy"
        return 1
    fi

    print_info "Đang lấy salt keys mới từ WordPress API..."

    # Get new salt keys
    local new_salts=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)

    if [[ -z "$new_salts" ]]; then
        print_error "Không thể lấy salt keys mới"
        return 1
    fi

    # Backup wp-config.php
    cp "${site_root}/wp-config.php" "${site_root}/wp-config.php.bak"

    # Replace salt keys
    local temp_file=$(mktemp)

    # Remove old salt keys
    sed '/AUTH_KEY/,/NONCE_SALT/d' "${site_root}/wp-config.php" > "$temp_file"

    # Add new salt keys before DB_NAME
    awk -v salts="$new_salts" '
        /DB_NAME/ && !inserted {
            print salts
            print ""
            inserted=1
        }
        {print}
    ' "$temp_file" > "${site_root}/wp-config.php"

    rm -f "$temp_file"

    print_success "Đã thay đổi salt keys thành công"
    print_info "Tất cả users sẽ bị đăng xuất và phải đăng nhập lại"
    log_message "INFO" "Changed salt keys for: $domain"
}

# Enable/Disable WP Debug
toggle_wp_debug() {
    local domain=$1
    local enable=${2:-"true"}  # true or false

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-config.php" ]]; then
        print_error "Không tìm thấy wp-config.php"
        return 1
    fi

    if [[ "$enable" == "true" ]]; then
        # Enable debug
        print_info "Đang bật WP Debug..."

        # Check if already set
        if grep -q "define('WP_DEBUG'" "${site_root}/wp-config.php"; then
            sed -i "s/define('WP_DEBUG'.*/define('WP_DEBUG', true);/" "${site_root}/wp-config.php"
        else
            sed -i "/<?php/a define('WP_DEBUG', true);" "${site_root}/wp-config.php"
        fi

        # Add WP_DEBUG_LOG if not exists
        if ! grep -q "define('WP_DEBUG_LOG'" "${site_root}/wp-config.php"; then
            sed -i "/WP_DEBUG/a define('WP_DEBUG_LOG', true);" "${site_root}/wp-config.php"
        fi

        # Add WP_DEBUG_DISPLAY if not exists
        if ! grep -q "define('WP_DEBUG_DISPLAY'" "${site_root}/wp-config.php"; then
            sed -i "/WP_DEBUG_LOG/a define('WP_DEBUG_DISPLAY', false);" "${site_root}/wp-config.php"
        fi

        print_success "Đã bật WP Debug"
        print_info "Logs sẽ được lưu tại: ${site_root}/wp-content/debug.log"
    else
        # Disable debug
        print_info "Đang tắt WP Debug..."

        sed -i "s/define('WP_DEBUG'.*/define('WP_DEBUG', false);/" "${site_root}/wp-config.php"

        print_success "Đã tắt WP Debug"
    fi

    log_message "INFO" "Toggle WP Debug for: $domain (enable: $enable)"
}

# Increase PHP Memory Limit
increase_memory_limit() {
    local domain=$1
    local memory_limit=${2:-"512M"}

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-config.php" ]]; then
        print_error "Không tìm thấy wp-config.php"
        return 1
    fi

    print_info "Đang tăng memory limit lên: $memory_limit"

    # Check if already set
    if grep -q "define('WP_MEMORY_LIMIT'" "${site_root}/wp-config.php"; then
        sed -i "s/define('WP_MEMORY_LIMIT'.*/define('WP_MEMORY_LIMIT', '$memory_limit');/" "${site_root}/wp-config.php"
    else
        sed -i "/<?php/a define('WP_MEMORY_LIMIT', '$memory_limit');" "${site_root}/wp-config.php"
    fi

    # Set max memory limit
    local max_memory=$(echo "$memory_limit" | sed 's/M//' | awk '{print $1*2}')
    if grep -q "define('WP_MAX_MEMORY_LIMIT'" "${site_root}/wp-config.php"; then
        sed -i "s/define('WP_MAX_MEMORY_LIMIT'.*/define('WP_MAX_MEMORY_LIMIT', '${max_memory}M');/" "${site_root}/wp-config.php"
    else
        sed -i "/WP_MEMORY_LIMIT/a define('WP_MAX_MEMORY_LIMIT', '${max_memory}M');" "${site_root}/wp-config.php"
    fi

    print_success "Đã tăng memory limit thành công"
    print_info "WP_MEMORY_LIMIT: $memory_limit"
    print_info "WP_MAX_MEMORY_LIMIT: ${max_memory}M"
    log_message "INFO" "Increased memory limit for: $domain to $memory_limit"
}

# Disable File Editing in Admin
disable_file_edit() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-config.php" ]]; then
        print_error "Không tìm thấy wp-config.php"
        return 1
    fi

    print_info "Đang tắt File Editor trong wp-admin..."

    if grep -q "define('DISALLOW_FILE_EDIT'" "${site_root}/wp-config.php"; then
        print_warning "File Editor đã được tắt trước đó"
        return 0
    fi

    sed -i "/<?php/a define('DISALLOW_FILE_EDIT', true);" "${site_root}/wp-config.php"

    print_success "Đã tắt File Editor thành công"
    print_info "Admin không thể chỉnh sửa code từ wp-admin nữa"
    log_message "INFO" "Disabled file edit for: $domain"
}

# Enable File Editing in Admin
enable_file_edit() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-config.php" ]]; then
        print_error "Không tìm thấy wp-config.php"
        return 1
    fi

    print_info "Đang bật File Editor trong wp-admin..."

    if ! grep -q "define('DISALLOW_FILE_EDIT'" "${site_root}/wp-config.php"; then
        print_warning "File Editor đang được bật"
        return 0
    fi

    sed -i "/define('DISALLOW_FILE_EDIT'/d" "${site_root}/wp-config.php"

    print_success "Đã bật File Editor thành công"
    log_message "INFO" "Enabled file edit for: $domain"
}

# Flush Rewrite Rules
flush_rewrite_rules() {
    local domain=$1

    if ! command_exists wp; then
        print_error "WP-CLI chưa được cài đặt"
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

    print_info "Đang flush rewrite rules cho: $domain"

    wp rewrite flush --hard --path="$site_root" --allow-root

    if [[ $? -eq 0 ]]; then
        print_success "Đã flush rewrite rules thành công"
        log_message "INFO" "Flushed rewrite rules for: $domain"
        return 0
    else
        print_error "Không thể flush rewrite rules"
        return 1
    fi
}

# Delete Spam Comments
delete_spam_comments() {
    local domain=$1

    if ! command_exists wp; then
        print_error "WP-CLI chưa được cài đặt"
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

    print_info "Đang kiểm tra spam comments..."

    local spam_count=$(wp comment list --status=spam --format=count --path="$site_root" --allow-root)

    if [[ "$spam_count" == "0" ]]; then
        print_success "Không có spam comment nào"
        return 0
    fi

    print_info "Tìm thấy $spam_count spam comment(s)"

    if ! confirm_action "Bạn có muốn xóa tất cả spam comments?" "y"; then
        print_info "Đã hủy"
        return 1
    fi

    # Delete spam comments
    wp comment delete $(wp comment list --status=spam --format=ids --path="$site_root" --allow-root) --force --path="$site_root" --allow-root

    if [[ $? -eq 0 ]]; then
        print_success "Đã xóa $spam_count spam comment(s)"
        log_message "INFO" "Deleted $spam_count spam comments for: $domain"
        return 0
    else
        print_error "Không thể xóa spam comments"
        return 1
    fi
}

# Update Site URL
update_site_url() {
    local domain=$1
    local new_url=$2

    if ! command_exists wp; then
        print_error "WP-CLI chưa được cài đặt"
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

    # Get current URL
    local current_url=$(wp option get home --path="$site_root" --allow-root)

    print_info "URL hiện tại: $current_url"
    print_info "URL mới: $new_url"
    echo ""

    if ! confirm_action "Bạn có chắc chắn muốn thay đổi URL?" "n"; then
        print_info "Đã hủy"
        return 1
    fi

    print_info "Đang cập nhật URL..."

    # Update home and siteurl
    wp option update home "$new_url" --path="$site_root" --allow-root
    wp option update siteurl "$new_url" --path="$site_root" --allow-root

    if [[ $? -eq 0 ]]; then
        print_success "Đã cập nhật URL thành công"
        log_message "INFO" "Updated URL for: $domain from $current_url to $new_url"
        return 0
    else
        print_error "Không thể cập nhật URL"
        return 1
    fi
}
