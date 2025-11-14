#!/bin/bash
# Migration Menu Module
# Menu quản lý chuyển VPS và WordPress sites

source "${SCRIPT_DIR}/lib/common.sh"
source "${MODULES_DIR}/migration/migration-manager.sh"

# Migration management menu
migration_management_menu() {
    while true; do
        show_header
        echo -e "${CYAN}CHUYỂN VPS & WORDPRESS SITES${NC}"
        echo ""
        echo "  ${YELLOW}━━━ Chuyển VPS ━━━${NC}"
        echo "  1. Chuyển toàn bộ VPS sang server mới"
        echo ""
        echo "  ${YELLOW}━━━ Chuyển WordPress Sites ━━━${NC}"
        echo "  2. Chuyển 1 site sang VPS khác"
        echo "  3. Chuyển tất cả sites sang VPS khác"
        echo "  4. Import site từ migration package"
        echo ""
        echo "  ${YELLOW}━━━ Export để chuyển thủ công ━━━${NC}"
        echo "  5. Export site thành package"
        echo ""
        echo "  ${YELLOW}━━━ Hướng dẫn ━━━${NC}"
        echo "  6. Hướng dẫn sử dụng"
        echo ""
        echo "  0. Quay lại"
        echo ""
        show_footer

        read -p "Chọn chức năng: " choice

        case $choice in
            1)
                transfer_full_vps
                ;;
            2)
                transfer_single_site
                ;;
            3)
                transfer_all_sites
                ;;
            4)
                import_site_from_package
                ;;
            5)
                show_header
                echo -e "${CYAN}EXPORT SITE${NC}"
                echo ""

                # List sites
                if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
                    print_warning "Chưa có site nào"
                    pause
                    continue
                fi

                echo "Danh sách sites:"
                echo ""
                local count=0
                while IFS='|' read -r domain site_name _ _ _ _ _; do
                    ((count++))
                    echo "  $count. $domain"
                done < "$SITES_DB"
                echo ""

                read -p "Nhập tên miền: " domain

                if site_exists "$domain"; then
                    export_dir=$(prepare_site_export "$domain")
                    if [[ $? -eq 0 ]]; then
                        echo ""
                        print_success "Site đã được export!"
                        print_info "Package tại: $export_dir"
                        echo ""
                        print_info "Bạn có thể:"
                        echo "  • Scp/rsync folder này sang VPS khác"
                        echo "  • Import bằng: wpminhminhscript import-site $export_dir"
                        echo ""
                    fi
                else
                    print_error "Site không tồn tại: $domain"
                fi
                pause
                ;;
            6)
                show_migration_guide
                ;;
            0)
                break
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                pause
                ;;
        esac
    done
}

# Show migration guide
show_migration_guide() {
    show_header
    echo -e "${CYAN}HƯỚNG DẪN SỬ DỤNG CHUYỂN VPS & SITES${NC}"
    echo ""

    echo -e "${YELLOW}1. CHUYỂN TOÀN BỘ VPS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Chức năng này rsync toàn bộ hệ thống sang VPS mới."
    echo ""
    echo "Yêu cầu:"
    echo "  • VPS mới phải cùng phân phối (Ubuntu/Debian)"
    echo "  • VPS mới đã cài rsync: apt-get install rsync"
    echo "  • Đã setup SSH key authentication (hoặc sẵn sàng nhập password)"
    echo ""
    echo "Quy trình:"
    echo "  1. Nhập IP, port, user của VPS đích"
    echo "  2. Script sẽ rsync toàn bộ / (trừ /proc, /sys, /dev...)"
    echo "  3. Sau khi xong, restart services trên VPS mới"
    echo "  4. Trỏ DNS về VPS mới"
    echo ""

    echo -e "${YELLOW}2. CHUYỂN 1 SITE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Chuyển 1 WordPress site cụ thể sang VPS khác."
    echo ""
    echo "Quy trình:"
    echo "  1. Chọn site cần chuyển"
    echo "  2. Script tự động backup database + files"
    echo "  3. Rsync package sang VPS đích"
    echo "  4. Trên VPS đích, chạy import để cài đặt site"
    echo ""

    echo -e "${YELLOW}3. CHUYỂN TẤT CẢ SITES${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Chuyển tất cả WordPress sites sang VPS mới."
    echo ""
    echo "Quy trình:"
    echo "  1. Script tự động export tất cả sites"
    echo "  2. Rsync từng site package sang VPS đích"
    echo "  3. Trên VPS đích, import từng site thủ công hoặc script"
    echo ""

    echo -e "${YELLOW}4. IMPORT SITE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Import site từ migration package (dùng trên VPS đích)."
    echo ""
    echo "Quy trình:"
    echo "  1. Nhập đường dẫn migration package"
    echo "  2. Script tự động:"
    echo "     • Tạo database mới"
    echo "     • Import database"
    echo "     • Giải nén files"
    echo "     • Tạo system user"
    echo "     • Tạo PHP-FPM pool"
    echo "     • Tạo Nginx vhost"
    echo "  3. Site sẵn sàng hoạt động!"
    echo ""

    echo -e "${YELLOW}5. EXPORT SITE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Export site thành package để chuyển thủ công."
    echo ""
    echo "Sau khi export:"
    echo "  • Dùng scp/rsync để copy package sang VPS khác"
    echo "  • Hoặc download về máy local"
    echo "  • Import trên VPS đích bằng chức năng Import Site"
    echo ""

    echo -e "${YELLOW}LƯU Ý QUAN TRỌNG${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  • Luôn backup VPS/sites trước khi thực hiện migration"
    echo "  • Test kết nối SSH trước khi transfer"
    echo "  • Migration có thể mất nhiều thời gian tùy dung lượng"
    echo "  • Sau migration, nhớ update DNS trỏ về IP mới"
    echo "  • Kiểm tra tất cả websites hoạt động sau migration"
    echo ""

    echo -e "${YELLOW}VÍ DỤ COMMAND LINE${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  # Import site từ CLI"
    echo "  wpminhminhscript import-site /tmp/site_migration"
    echo ""
    echo "  # Export site từ CLI"
    echo "  wpminhminhscript export-site example.com"
    echo ""

    show_footer
    pause
}
