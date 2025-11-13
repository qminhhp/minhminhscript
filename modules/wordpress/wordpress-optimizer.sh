#!/bin/bash
# WordPress Optimizer Module
# Các tính năng tối ưu WordPress

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Optimize Heartbeat API
optimize_heartbeat() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name site_user _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Heartbeat API là gì?"
    echo "  - Auto-save posts"
    echo "  - Post locking (khi nhiều người edit)"
    echo "  - Admin notifications"
    echo "  - Chạy liên tục 15-60 giây/lần"
    echo "  - TỐN TÀI NGUYÊN server rất nhiều"
    echo ""

    print_info "Tối ưu Heartbeat sẽ:"
    echo "  - Tắt Heartbeat ở frontend"
    echo "  - Giảm tần suất check ở backend"
    echo "  - Tắt hoàn toàn ở post editor (optional)"
    echo ""

    if ! confirm_action "Bạn có muốn tối ưu Heartbeat API?" "y"; then
        print_info "Đã hủy"
        return 1
    fi

    # Create plugin directory if not exists
    local plugin_dir="${site_root}/wp-content/mu-plugins"
    ensure_directory "$plugin_dir"

    # Create mu-plugin for heartbeat optimization
    cat > "${plugin_dir}/heartbeat-optimizer.php" << 'EOF'
<?php
/**
 * Plugin Name: Heartbeat Optimizer
 * Description: Optimize WordPress Heartbeat API to reduce server load
 * Version: 1.0
 * Author: WP Minhminh Script
 */

// Disable Heartbeat on frontend
add_action('init', function() {
    if (!is_admin()) {
        wp_deregister_script('heartbeat');
    }
}, 1);

// Slow down Heartbeat in admin
add_filter('heartbeat_settings', function($settings) {
    // Change interval to 60 seconds (default is 15)
    $settings['interval'] = 60;
    return $settings;
});

// Disable Heartbeat in post editor (optional, uncomment if needed)
/*
add_action('admin_enqueue_scripts', function() {
    global $pagenow;
    if ($pagenow == 'post.php' || $pagenow == 'post-new.php') {
        wp_deregister_script('heartbeat');
    }
});
*/
EOF

    # Fix permissions
    chown "${site_user}:${site_user}" "${plugin_dir}/heartbeat-optimizer.php"
    chmod 644 "${plugin_dir}/heartbeat-optimizer.php"

    print_success "Đã tối ưu Heartbeat API thành công"
    print_info "MU-Plugin đã được cài đặt tại: ${plugin_dir}/heartbeat-optimizer.php"
    log_message "INFO" "Optimized Heartbeat API for: $domain"
}

# Clean Transients
clean_transients() {
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

    print_info "Đang xóa transients cũ..."

    # Delete expired transients
    wp transient delete --expired --path="$site_root" --allow-root

    # Get count of all transients
    local transient_count=$(wp transient list --format=count --path="$site_root" --allow-root 2>/dev/null)

    if [[ "$transient_count" -gt 0 ]]; then
        print_info "Còn $transient_count transient(s) chưa expire"

        if confirm_action "Bạn có muốn xóa TẤT CẢ transients?" "n"; then
            wp transient delete --all --path="$site_root" --allow-root
            print_success "Đã xóa tất cả transients"
        fi
    else
        print_success "Đã xóa tất cả transients expired"
    fi

    log_message "INFO" "Cleaned transients for: $domain"
}

# Optimize Database Tables
optimize_database_tables() {
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
    IFS='|' read -r _ _ _ db_name _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    print_info "Đang tối ưu database tables..."

    # Optimize all tables
    wp db optimize --path="$site_root" --allow-root

    if [[ $? -eq 0 ]]; then
        print_success "Đã tối ưu database thành công"
        log_message "INFO" "Optimized database for: $domain"
        return 0
    else
        print_error "Không thể tối ưu database"
        return 1
    fi
}

# Clean Post Revisions
clean_post_revisions() {
    local domain=$1
    local keep_revisions=${2:-5}

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

    print_info "Đang kiểm tra post revisions..."

    # Count revisions
    local revision_count=$(wp post list --post_type=revision --format=count --path="$site_root" --allow-root)

    if [[ "$revision_count" == "0" ]]; then
        print_success "Không có revision nào"
        return 0
    fi

    print_info "Tìm thấy $revision_count revision(s)"
    print_info "Sẽ giữ lại $keep_revisions revision mới nhất cho mỗi post"
    echo ""

    if ! confirm_action "Bạn có muốn xóa revisions cũ?" "y"; then
        print_info "Đã hủy"
        return 1
    fi

    # Delete old revisions (keep last N)
    # WP-CLI doesn't have direct command for this, so we use database query
    local db_prefix=$(wp config get table_prefix --path="$site_root" --allow-root)

    wp db query "
        DELETE FROM ${db_prefix}posts
        WHERE post_type = 'revision'
        AND ID NOT IN (
            SELECT ID FROM (
                SELECT ID
                FROM ${db_prefix}posts
                WHERE post_type = 'revision'
                ORDER BY post_modified DESC
                LIMIT $keep_revisions
            ) AS temp
        )
    " --path="$site_root" --allow-root

    print_success "Đã xóa revisions cũ"
    log_message "INFO" "Cleaned post revisions for: $domain (kept: $keep_revisions)"
}

# Disable Emojis
disable_emojis() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name site_user _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    # Create mu-plugin directory if not exists
    local plugin_dir="${site_root}/wp-content/mu-plugins"
    ensure_directory "$plugin_dir"

    # Create mu-plugin to disable emojis
    cat > "${plugin_dir}/disable-emojis.php" << 'EOF'
<?php
/**
 * Plugin Name: Disable Emojis
 * Description: Disable WordPress emoji scripts and styles
 * Version: 1.0
 * Author: WP Minhminh Script
 */

// Disable emoji
remove_action('wp_head', 'print_emoji_detection_script', 7);
remove_action('admin_print_scripts', 'print_emoji_detection_script');
remove_action('wp_print_styles', 'print_emoji_styles');
remove_action('admin_print_styles', 'print_emoji_styles');
remove_filter('the_content_feed', 'wp_staticize_emoji');
remove_filter('comment_text_rss', 'wp_staticize_emoji');
remove_filter('wp_mail', 'wp_staticize_emoji_for_email');

// Remove emoji DNS prefetch
add_filter('wp_resource_hints', function($urls, $relation_type) {
    if ('dns-prefetch' == $relation_type) {
        $emoji_svg_url = apply_filters('emoji_svg_url', 'https://s.w.org/images/core/emoji/');
        $urls = array_diff($urls, array($emoji_svg_url));
    }
    return $urls;
}, 10, 2);
EOF

    # Fix permissions
    chown "${site_user}:${site_user}" "${plugin_dir}/disable-emojis.php"
    chmod 644 "${plugin_dir}/disable-emojis.php"

    print_success "Đã tắt Emojis thành công"
    print_info "Giảm HTTP requests và tăng tốc độ tải trang"
    log_message "INFO" "Disabled emojis for: $domain"
}

# Disable Embeds
disable_embeds() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name site_user _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    # Create mu-plugin directory if not exists
    local plugin_dir="${site_root}/wp-content/mu-plugins"
    ensure_directory "$plugin_dir"

    # Create mu-plugin to disable embeds
    cat > "${plugin_dir}/disable-embeds.php" << 'EOF'
<?php
/**
 * Plugin Name: Disable Embeds
 * Description: Disable WordPress embed functionality
 * Version: 1.0
 * Author: WP Minhminh Script
 */

// Disable WordPress embed
add_action('init', function() {
    // Remove the REST API endpoint
    remove_action('rest_api_init', 'wp_oembed_register_route');

    // Turn off oEmbed auto discovery
    add_filter('embed_oembed_discover', '__return_false');

    // Don't filter oEmbed results
    remove_filter('oembed_dataparse', 'wp_filter_oembed_result', 10);

    // Remove oEmbed discovery links
    remove_action('wp_head', 'wp_oembed_add_discovery_links');

    // Remove oEmbed-specific JavaScript from the front-end and back-end
    remove_action('wp_head', 'wp_oembed_add_host_js');
}, 9999);
EOF

    # Fix permissions
    chown "${site_user}:${site_user}" "${plugin_dir}/disable-embeds.php"
    chmod 644 "${plugin_dir}/disable-embeds.php"

    print_success "Đã tắt Embeds thành công"
    log_message "INFO" "Disabled embeds for: $domain"
}

# Limit Post Revisions in wp-config.php
limit_post_revisions() {
    local domain=$1
    local limit=${2:-5}

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

    print_info "Đang giới hạn post revisions: $limit"

    # Check if already set
    if grep -q "define('WP_POST_REVISIONS'" "${site_root}/wp-config.php"; then
        sed -i "s/define('WP_POST_REVISIONS'.*/define('WP_POST_REVISIONS', $limit);/" "${site_root}/wp-config.php"
    else
        sed -i "/<?php/a define('WP_POST_REVISIONS', $limit);" "${site_root}/wp-config.php"
    fi

    print_success "Đã giới hạn revisions thành công"
    print_info "Mỗi post chỉ giữ tối đa $limit revisions"
    log_message "INFO" "Limited post revisions for: $domain to $limit"
}

# Use Unix Socket for Database Connection
use_unix_socket_db() {
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

    print_info "Unix Socket nhanh hơn TCP/IP connection"
    print_info "Đang cấu hình..."

    # Find MySQL socket
    local mysql_socket=""
    if [[ -S "/var/run/mysqld/mysqld.sock" ]]; then
        mysql_socket="/var/run/mysqld/mysqld.sock"
    elif [[ -S "/var/lib/mysql/mysql.sock" ]]; then
        mysql_socket="/var/lib/mysql/mysql.sock"
    elif [[ -S "/tmp/mysql.sock" ]]; then
        mysql_socket="/tmp/mysql.sock"
    else
        print_error "Không tìm thấy MySQL socket"
        return 1
    fi

    print_info "MySQL socket: $mysql_socket"

    # Update wp-config.php
    sed -i "s/define('DB_HOST'.*/define('DB_HOST', 'localhost:${mysql_socket}');/" "${site_root}/wp-config.php"

    print_success "Đã cấu hình Unix Socket thành công"
    print_info "Database connection sẽ nhanh hơn và bảo mật hơn"
    log_message "INFO" "Configured Unix socket for: $domain"
}
