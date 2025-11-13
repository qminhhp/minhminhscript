#!/bin/bash
# WordPress Advanced Features Menu
# Menu tổng hợp các tính năng WordPress nâng cao

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/modules/wordpress/wordpress-advanced.sh"
source "${SCRIPT_DIR}/modules/wordpress/wordpress-maintenance.sh"
source "${SCRIPT_DIR}/modules/wordpress/wordpress-optimizer.sh"
source "${SCRIPT_DIR}/modules/wordpress/wordpress-image.sh"

# Main WordPress Advanced Menu
wordpress_advanced_menu() {
    while true; do
        show_header
        echo -e "${CYAN}WORDPRESS - TÍNH NĂNG NÂNG CAO${NC}"
        echo ""
        echo "1.  Quản lý bảo trì & bảo mật"
        echo "2.  Tối ưu hóa hiệu suất"
        echo "3.  Quản lý database"
        echo "4.  Quản lý hình ảnh"
        echo "5.  Công cụ phát triển"
        echo "6.  Cập nhật hàng loạt"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-6]: " choice

        case $choice in
            1) wordpress_maintenance_menu ;;
            2) wordpress_optimization_menu ;;
            3) wordpress_database_menu ;;
            4) wordpress_image_menu ;;
            5) wordpress_tools_menu ;;
            6) wordpress_bulk_update_menu ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Maintenance & Security Menu
wordpress_maintenance_menu() {
    while true; do
        show_header
        echo -e "${CYAN}WORDPRESS - BẢO TRÌ & BẢO MẬT${NC}"
        echo ""
        echo "1.  Magic Login Link - Tạo link đăng nhập tạm thời"
        echo "2.  Maintenance Mode - Bật/tắt chế độ bảo trì"
        echo "3.  Disable XML-RPC - Tắt XML-RPC endpoint"
        echo "4.  Change Salt Keys - Đổi salt keys (logout all users)"
        echo "5.  Disable File Edit - Tắt chỉnh sửa file trong admin"
        echo "6.  Enable File Edit - Bật chỉnh sửa file trong admin"
        echo "7.  Scan Base64 Malware - Quét mã độc base64"
        echo "8.  Update Site URL - Cập nhật home và siteurl"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-8]: " choice

        case $choice in
            1)
                read -p "Nhập domain: " domain
                magic_login_link "$domain"
                pause
                ;;
            2)
                read -p "Nhập domain: " domain
                echo "1. Bật Maintenance Mode"
                echo "2. Tắt Maintenance Mode"
                read -p "Chọn: " mode_choice
                case $mode_choice in
                    1) enable_maintenance_mode "$domain" ;;
                    2) disable_maintenance_mode "$domain" ;;
                esac
                pause
                ;;
            3)
                read -p "Nhập domain: " domain
                disable_xmlrpc "$domain"
                pause
                ;;
            4)
                read -p "Nhập domain: " domain
                change_salt_keys "$domain"
                pause
                ;;
            5)
                read -p "Nhập domain: " domain
                disable_file_edit "$domain"
                pause
                ;;
            6)
                read -p "Nhập domain: " domain
                enable_file_edit "$domain"
                pause
                ;;
            7)
                read -p "Nhập domain: " domain
                scan_base64_malware "$domain"
                pause
                ;;
            8)
                read -p "Nhập domain: " domain
                read -p "Nhập URL mới: " new_url
                update_site_url "$domain" "$new_url"
                pause
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Optimization Menu
wordpress_optimization_menu() {
    while true; do
        show_header
        echo -e "${CYAN}WORDPRESS - TỐI ƯU HÓA${NC}"
        echo ""
        echo "1.  Optimize Heartbeat API - Giảm tần suất Heartbeat"
        echo "2.  Clean Transients - Xóa transients cũ"
        echo "3.  Optimize Database - Tối ưu database tables"
        echo "4.  Clean Post Revisions - Xóa revisions cũ"
        echo "5.  Disable Emojis - Tắt emoji scripts"
        echo "6.  Disable Embeds - Tắt oEmbed"
        echo "7.  Limit Post Revisions - Giới hạn số revisions"
        echo "8.  Use Unix Socket DB - Dùng Unix socket cho DB"
        echo "9.  Increase Memory Limit - Tăng WP_MEMORY_LIMIT"
        echo "10. Flush Rewrite Rules - Reset permalinks"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-10]: " choice

        case $choice in
            1)
                read -p "Nhập domain: " domain
                optimize_heartbeat "$domain"
                pause
                ;;
            2)
                read -p "Nhập domain: " domain
                clean_transients "$domain"
                pause
                ;;
            3)
                read -p "Nhập domain: " domain
                optimize_database_tables "$domain"
                pause
                ;;
            4)
                read -p "Nhập domain: " domain
                read -p "Giữ lại bao nhiêu revisions? [5]: " keep
                keep=${keep:-5}
                clean_post_revisions "$domain" "$keep"
                pause
                ;;
            5)
                read -p "Nhập domain: " domain
                disable_emojis "$domain"
                pause
                ;;
            6)
                read -p "Nhập domain: " domain
                disable_embeds "$domain"
                pause
                ;;
            7)
                read -p "Nhập domain: " domain
                read -p "Giới hạn bao nhiêu revisions? [5]: " limit
                limit=${limit:-5}
                limit_post_revisions "$domain" "$limit"
                pause
                ;;
            8)
                read -p "Nhập domain: " domain
                use_unix_socket_db "$domain"
                pause
                ;;
            9)
                read -p "Nhập domain: " domain
                read -p "Memory limit (MB) [256]: " memory
                memory=${memory:-256}
                increase_memory_limit "$domain" "$memory"
                pause
                ;;
            10)
                read -p "Nhập domain: " domain
                flush_rewrite_rules "$domain"
                pause
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Database Menu
wordpress_database_menu() {
    while true; do
        show_header
        echo -e "${CYAN}WORDPRESS - QUẢN LÝ DATABASE${NC}"
        echo ""
        echo "1.  Check Autoload - Kiểm tra autoload data"
        echo "2.  Search & Replace - Tìm và thay thế trong DB"
        echo "3.  Change DB Prefix - Đổi table prefix"
        echo "4.  Delete Spam Comments - Xóa spam comments"
        echo "5.  Optimize Database - Tối ưu tables"
        echo "6.  Clean Transients - Xóa transients"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-6]: " choice

        case $choice in
            1)
                read -p "Nhập domain: " domain
                check_autoload "$domain"
                pause
                ;;
            2)
                read -p "Nhập domain: " domain
                read -p "Tìm (search): " search
                read -p "Thay (replace): " replace
                search_replace_db "$domain" "$search" "$replace"
                pause
                ;;
            3)
                read -p "Nhập domain: " domain
                read -p "Prefix mới: " new_prefix
                change_db_prefix "$domain" "$new_prefix"
                pause
                ;;
            4)
                read -p "Nhập domain: " domain
                delete_spam_comments "$domain"
                pause
                ;;
            5)
                read -p "Nhập domain: " domain
                optimize_database_tables "$domain"
                pause
                ;;
            6)
                read -p "Nhập domain: " domain
                clean_transients "$domain"
                pause
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Image Menu
wordpress_image_menu() {
    while true; do
        show_header
        echo -e "${CYAN}WORDPRESS - QUẢN LÝ HÌNH ẢNH${NC}"
        echo ""
        echo "1.  Optimize Images - Tối ưu hình ảnh"
        echo "2.  Optimize All Sites - Tối ưu hình ảnh tất cả sites"
        echo "3.  Regenerate Thumbnails - Tạo lại thumbnails"
        echo "4.  Get Image Stats - Thống kê hình ảnh"
        echo "5.  Check Image Tools - Kiểm tra công cụ"
        echo "6.  Install Image Tools - Cài đặt công cụ"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-6]: " choice

        case $choice in
            1)
                read -p "Nhập domain: " domain
                read -p "Quality (1-100) [76]: " quality
                quality=${quality:-76}
                optimize_images "$domain" "$quality"
                pause
                ;;
            2)
                read -p "Quality (1-100) [76]: " quality
                quality=${quality:-76}
                optimize_images_all_sites "$quality"
                pause
                ;;
            3)
                read -p "Nhập domain: " domain
                regenerate_thumbnails "$domain"
                pause
                ;;
            4)
                read -p "Nhập domain: " domain
                get_image_stats "$domain"
                pause
                ;;
            5)
                check_image_tools
                pause
                ;;
            6)
                install_image_tools
                pause
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Development Tools Menu
wordpress_tools_menu() {
    while true; do
        show_header
        echo -e "${CYAN}WORDPRESS - CÔNG CỤ PHÁT TRIỂN${NC}"
        echo ""
        echo "1.  WordPress Health Check - Kiểm tra sức khỏe"
        echo "2.  Hook Speed Profiling - Phân tích hiệu suất hooks"
        echo "3.  WP Debug - Bật/tắt WP_DEBUG"
        echo "4.  Magic Login Link - Tạo link đăng nhập"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-4]: " choice

        case $choice in
            1)
                read -p "Nhập domain: " domain
                wordpress_health_check "$domain"
                pause
                ;;
            2)
                read -p "Nhập domain: " domain
                hook_speed_profiling "$domain"
                pause
                ;;
            3)
                read -p "Nhập domain: " domain
                echo "1. Bật WP_DEBUG"
                echo "2. Tắt WP_DEBUG"
                read -p "Chọn: " debug_choice
                case $debug_choice in
                    1) toggle_wp_debug "$domain" "enable" ;;
                    2) toggle_wp_debug "$domain" "disable" ;;
                esac
                pause
                ;;
            4)
                read -p "Nhập domain: " domain
                magic_login_link "$domain"
                pause
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Bulk Update Menu
wordpress_bulk_update_menu() {
    while true; do
        show_header
        echo -e "${CYAN}WORDPRESS - CẬP NHẬT HÀNG LOẠT${NC}"
        echo ""
        echo "1.  Update WordPress Core - Cập nhật WordPress"
        echo "2.  Update All Plugins - Cập nhật tất cả plugins"
        echo "3.  Update All Themes - Cập nhật tất cả themes"
        echo "4.  Update All Sites - Cập nhật tất cả sites trên VPS"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-4]: " choice

        case $choice in
            1)
                read -p "Nhập domain: " domain
                update_wordpress_core "$domain"
                pause
                ;;
            2)
                read -p "Nhập domain: " domain
                update_all_plugins "$domain"
                pause
                ;;
            3)
                read -p "Nhập domain: " domain
                update_all_themes "$domain"
                pause
                ;;
            4)
                update_all_sites
                pause
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}
