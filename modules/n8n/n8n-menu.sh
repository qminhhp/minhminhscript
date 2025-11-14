#!/bin/bash
# n8n Menu Module
# Menu quản lý n8n workflow automation instances

source "${SCRIPT_DIR}/lib/common.sh"
source "${MODULES_DIR}/n8n/n8n-manager.sh"

# n8n management menu
n8n_management_menu() {
    while true; do
        show_header
        echo -e "${CYAN}N8N WORKFLOW AUTOMATION${NC}"
        echo ""
        echo "  ${YELLOW}━━━ Quản lý n8n Instances ━━━${NC}"
        echo "  1. Thêm n8n instance mới"
        echo "  2. Danh sách n8n instances"
        echo "  3. Xóa n8n instance"
        echo ""
        echo "  ${YELLOW}━━━ Điều khiển ━━━${NC}"
        echo "  4. Start instance"
        echo "  5. Stop instance"
        echo "  6. Restart instance"
        echo "  7. Xem logs"
        echo ""
        echo "  ${YELLOW}━━━ Bảo trì ━━━${NC}"
        echo "  8. Backup instance"
        echo "  9. Update n8n version"
        echo ""
        echo "  ${YELLOW}━━━ Hệ thống ━━━${NC}"
        echo " 10. Cài đặt/Cập nhật Docker"
        echo " 11. Hướng dẫn sử dụng"
        echo ""
        echo "  0. Quay lại"
        echo ""
        show_footer

        read -p "Chọn chức năng: " choice

        case $choice in
            1)
                add_n8n_instance
                ;;
            2)
                list_n8n_instances
                ;;
            3)
                remove_n8n_instance
                ;;
            4)
                show_header
                echo -e "${CYAN}START N8N INSTANCE${NC}"
                echo ""

                ensure_n8n_db

                if [[ ! -s "$N8N_DB" ]]; then
                    print_warning "Chưa có n8n instance nào"
                    pause
                    continue
                fi

                echo "Danh sách n8n instances:"
                echo ""
                local count=0
                while IFS='|' read -r domain _ _ _ _ _ _; do
                    ((count++))
                    echo "  $count. $domain"
                done < "$N8N_DB"
                echo ""

                read -p "Nhập tên miền: " domain
                start_n8n_instance "$domain"
                pause
                ;;
            5)
                show_header
                echo -e "${CYAN}STOP N8N INSTANCE${NC}"
                echo ""

                ensure_n8n_db

                if [[ ! -s "$N8N_DB" ]]; then
                    print_warning "Chưa có n8n instance nào"
                    pause
                    continue
                fi

                echo "Danh sách n8n instances:"
                echo ""
                local count=0
                while IFS='|' read -r domain _ _ _ _ _ _; do
                    ((count++))
                    echo "  $count. $domain"
                done < "$N8N_DB"
                echo ""

                read -p "Nhập tên miền: " domain
                stop_n8n_instance "$domain"
                pause
                ;;
            6)
                show_header
                echo -e "${CYAN}RESTART N8N INSTANCE${NC}"
                echo ""

                ensure_n8n_db

                if [[ ! -s "$N8N_DB" ]]; then
                    print_warning "Chưa có n8n instance nào"
                    pause
                    continue
                fi

                echo "Danh sách n8n instances:"
                echo ""
                local count=0
                while IFS='|' read -r domain _ _ _ _ _ _; do
                    ((count++))
                    echo "  $count. $domain"
                done < "$N8N_DB"
                echo ""

                read -p "Nhập tên miền: " domain
                restart_n8n_instance "$domain"
                pause
                ;;
            7)
                show_header
                echo -e "${CYAN}XEM LOGS N8N INSTANCE${NC}"
                echo ""

                ensure_n8n_db

                if [[ ! -s "$N8N_DB" ]]; then
                    print_warning "Chưa có n8n instance nào"
                    pause
                    continue
                fi

                echo "Danh sách n8n instances:"
                echo ""
                local count=0
                while IFS='|' read -r domain _ _ _ _ _ _; do
                    ((count++))
                    echo "  $count. $domain"
                done < "$N8N_DB"
                echo ""

                read -p "Nhập tên miền: " domain
                view_n8n_logs "$domain"
                ;;
            8)
                show_header
                echo -e "${CYAN}BACKUP N8N INSTANCE${NC}"
                echo ""

                ensure_n8n_db

                if [[ ! -s "$N8N_DB" ]]; then
                    print_warning "Chưa có n8n instance nào"
                    pause
                    continue
                fi

                echo "Danh sách n8n instances:"
                echo ""
                local count=0
                while IFS='|' read -r domain _ _ _ _ _ _; do
                    ((count++))
                    echo "  $count. $domain"
                done < "$N8N_DB"
                echo ""

                read -p "Nhập tên miền: " domain
                backup_n8n_instance "$domain"
                pause
                ;;
            9)
                show_header
                echo -e "${CYAN}UPDATE N8N VERSION${NC}"
                echo ""

                ensure_n8n_db

                if [[ ! -s "$N8N_DB" ]]; then
                    print_warning "Chưa có n8n instance nào"
                    pause
                    continue
                fi

                echo "Danh sách n8n instances:"
                echo ""
                local count=0
                while IFS='|' read -r domain _ _ _ _ _ _; do
                    ((count++))
                    echo "  $count. $domain"
                done < "$N8N_DB"
                echo ""

                read -p "Nhập tên miền: " domain
                update_n8n_instance "$domain"
                pause
                ;;
            10)
                show_header
                echo -e "${CYAN}CÀI ĐẶT/CẬP NHẬT DOCKER${NC}"
                echo ""

                if check_docker; then
                    print_info "Docker đã được cài đặt"
                    docker --version
                    echo ""
                    print_info "Docker Compose:"
                    docker compose version
                else
                    print_warning "Docker chưa được cài đặt"
                    if confirm_action "Cài đặt Docker ngay?" "y"; then
                        install_docker
                    fi
                fi
                pause
                ;;
            11)
                show_n8n_guide
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

# Show n8n guide
show_n8n_guide() {
    show_header
    echo -e "${CYAN}HƯỚNG DẪN SỬ DỤNG N8N${NC}"
    echo ""

    echo -e "${YELLOW}━━━ n8n là gì? ━━━${NC}"
    echo "n8n là công cụ workflow automation self-hosted (giống Zapier, Make.com)"
    echo "cho phép bạn tự động hóa các tác vụ giữa các ứng dụng và dịch vụ."
    echo ""

    echo -e "${YELLOW}━━━ Tính năng chính ━━━${NC}"
    echo "  • 400+ tích hợp sẵn (Google, Slack, WordPress, GitHub...)"
    echo "  • Workflow editor trực quan (kéo thả)"
    echo "  • Hỗ trợ JavaScript, Python code trong workflows"
    echo "  • Webhooks & API"
    echo "  • Scheduled triggers (cron)"
    echo "  • Self-hosted (kiểm soát hoàn toàn dữ liệu)"
    echo ""

    echo -e "${YELLOW}━━━ Cài đặt n8n instance ━━━${NC}"
    echo "1. Chọn menu: 1. Thêm n8n instance mới"
    echo "2. Nhập domain (vd: automation.example.com)"
    echo "3. Optional: Tạo Basic Auth để bảo vệ trước khi setup"
    echo "4. Script sẽ tự động:"
    echo "   • Cài Docker (nếu chưa có)"
    echo "   • Tạo Docker container n8n"
    echo "   • Tạo Nginx reverse proxy"
    echo "   • Cấu hình SSL-ready"
    echo ""

    echo -e "${YELLOW}━━━ Sau khi cài đặt ━━━${NC}"
    echo "1. Setup SSL:"
    echo "   wpminhminhscript → 6. Quản lý Domains → Setup SSL"
    echo "   Hoặc: wpminhminhscript setup-ssl automation.example.com"
    echo ""
    echo "2. Truy cập n8n qua HTTPS:"
    echo "   https://automation.example.com"
    echo ""
    echo "3. Tạo tài khoản owner đầu tiên:"
    echo "   • Nhập email"
    echo "   • Đặt password"
    echo "   • Tạo first workflow!"
    echo ""

    echo -e "${YELLOW}━━━ Ví dụ use case ━━━${NC}"
    echo "  • Auto backup WordPress sites daily → Google Drive"
    echo "  • Monitor website uptime → send Telegram alert"
    echo "  • New WordPress post → auto share to social media"
    echo "  • Form submission → save to Google Sheets + send email"
    echo "  • GitHub new issue → create Trello card"
    echo ""

    echo -e "${YELLOW}━━━ Quản lý instance ━━━${NC}"
    echo "  • Start/Stop/Restart: Điều khiển instance"
    echo "  • Logs: Xem logs realtime để debug workflows"
    echo "  • Backup: Backup workflows + credentials + settings"
    echo "  • Update: Cập nhật lên version mới nhất"
    echo ""

    echo -e "${YELLOW}━━━ Lưu ý quan trọng ━━━${NC}"
    echo "  • n8n lưu workflows + credentials trong /var/lib/n8n/<instance>"
    echo "  • Nhớ backup thường xuyên (chứa credentials nhạy cảm!)"
    echo "  • Khuyến nghị: Bật Basic Auth hoặc restrict IP access"
    echo "  • Data được mã hóa với N8N_ENCRYPTION_KEY"
    echo "  • Mỗi instance chạy độc lập trên port riêng"
    echo ""

    echo -e "${YELLOW}━━━ Resources ━━━${NC}"
    echo "  • Official docs: https://docs.n8n.io"
    echo "  • Workflow templates: https://n8n.io/workflows"
    echo "  • Community forum: https://community.n8n.io"
    echo ""

    show_footer
    pause
}
