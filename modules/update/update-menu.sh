#!/bin/bash
# Update Menu
# Menu cập nhật và quản lý phiên bản

show_update_menu() {
    while true; do
        clear
        show_header
        echo -e "${CYAN}CẬP NHẬT & PHIÊN BẢN${NC}"
        echo ""

        local current_version=$(get_current_version)
        local latest_version=$(get_latest_version)

        echo -e "  Phiên bản hiện tại: ${YELLOW}v${current_version}${NC}"

        if [[ -n "$latest_version" ]]; then
            if version_gt "$current_version" "$latest_version"; then
                echo -e "  Phiên bản mới nhất:  ${GREEN}v${latest_version}${NC} ${GREEN}(có bản cập nhật!)${NC}"
            else
                echo -e "  Phiên bản mới nhất:  ${GREEN}v${latest_version}${NC} (đã cập nhật)"
            fi
        else
            echo -e "  Phiên bản mới nhất:  ${RED}(không thể kiểm tra)${NC}"
        fi

        echo ""
        echo "─────────────────────────────────────────"
        echo ""
        echo "  1. Kiểm tra cập nhật"
        echo "  2. Cập nhật lên phiên bản mới nhất"
        echo "  3. Xem changelog (lịch sử thay đổi)"
        echo "  4. Khôi phục từ backup"
        echo "  5. Cài đặt từ branch khác"
        echo "  0. Quay lại"
        echo ""
        show_footer

        read -p "Chọn chức năng: " choice

        case $choice in
            1)
                echo ""
                check_for_updates false
                pause
                ;;
            2)
                echo ""
                do_update
                pause
                ;;
            3)
                echo ""
                show_changelog
                pause
                ;;
            4)
                echo ""
                restore_from_backup
                pause
                ;;
            5)
                echo ""
                update_from_branch
                pause
                ;;
            0)
                return
                ;;
            *)
                log_error "Lựa chọn không hợp lệ"
                sleep 1
                ;;
        esac
    done
}

# Show full changelog
show_changelog() {
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}  LỊCH SỬ THAY ĐỔI${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""

    local changelog=$(curl -s "${GITHUB_RAW_URL}/${DEFAULT_BRANCH}/CHANGELOG.md" 2>/dev/null)

    if [[ -n "$changelog" ]]; then
        echo "$changelog" | less
    else
        log_error "Không thể tải changelog từ GitHub"
    fi
}

# Update from specific branch
update_from_branch() {
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}  CÀI ĐẶT TỪ BRANCH${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""

    echo "Các branch phổ biến:"
    echo "  - main (ổn định, khuyên dùng)"
    echo "  - develop (tính năng mới, chưa ổn định)"
    echo "  - beta (thử nghiệm)"
    echo ""

    read -p "Nhập tên branch (hoặc Enter để dùng 'main'): " branch
    branch=${branch:-main}

    log_warning "Cài đặt từ branch '$branch' có thể không ổn định"
    read -p "Bạn có chắc chắn muốn tiếp tục? (yes/no): " confirm

    if [[ "$confirm" == "yes" ]]; then
        do_update "$branch"
    else
        log_info "Đã hủy"
    fi
}
