#!/bin/bash
# Domain Management Menu
# Menu tổng hợp quản lý domains, redirects, subdomains, Cloudflare

source "${SCRIPT_DIR}/lib/common.sh"
source "${MODULES_DIR}/domain/domain-manager.sh"
source "${MODULES_DIR}/cloudflare/cloudflare-manager.sh"

# Main Domain Management Menu
domain_management_menu() {
    while true; do
        show_header
        echo -e "${CYAN}QUẢN LÝ DOMAINS${NC}"
        echo ""
        echo "1.  Domain Aliases"
        echo "2.  Domain Redirects"
        echo "3.  Subdomain Management"
        echo "4.  Cloudflare Integration"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-4]: " choice

        case $choice in
            1) domain_aliases_menu ;;
            2) domain_redirects_menu ;;
            3) subdomain_menu ;;
            4) cloudflare_menu ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Domain Aliases Menu
domain_aliases_menu() {
    while true; do
        show_header
        echo -e "${CYAN}DOMAIN ALIASES${NC}"
        echo ""
        echo "1.  Add Domain Alias"
        echo "2.  Remove Domain Alias"
        echo "3.  List Domain Aliases"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-3]: " choice

        case $choice in
            1)
                read -p "Nhập domain hiện tại: " existing_domain
                read -p "Nhập domain alias mới: " new_domain
                add_domain_alias "$existing_domain" "$new_domain"
                pause
                ;;
            2)
                read -p "Nhập domain hiện tại: " existing_domain
                read -p "Nhập domain alias cần xóa: " alias_domain
                remove_domain_alias "$existing_domain" "$alias_domain"
                pause
                ;;
            3)
                read -p "Nhập domain: " domain
                list_domain_aliases "$domain"
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Domain Redirects Menu
domain_redirects_menu() {
    while true; do
        show_header
        echo -e "${CYAN}DOMAIN REDIRECTS${NC}"
        echo ""
        echo "1.  Create Domain Redirect (301/302)"
        echo "2.  Remove Domain Redirect"
        echo "3.  Force WWW Redirect"
        echo "4.  Force non-WWW Redirect"
        echo "5.  List All Redirects"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-5]: " choice

        case $choice in
            1)
                read -p "Redirect từ domain: " from_domain
                read -p "Redirect đến domain: " to_domain
                echo "1. 301 Permanent"
                echo "2. 302 Temporary"
                read -p "Chọn loại redirect [1]: " redirect_choice
                redirect_choice=${redirect_choice:-1}
                if [[ "$redirect_choice" == "1" ]]; then
                    redirect_type=301
                else
                    redirect_type=302
                fi
                create_domain_redirect "$from_domain" "$to_domain" "$redirect_type"
                pause
                ;;
            2)
                read -p "Nhập domain redirect cần xóa: " from_domain
                remove_domain_redirect "$from_domain"
                pause
                ;;
            3)
                read -p "Nhập domain: " domain
                force_www_redirect "$domain"
                pause
                ;;
            4)
                read -p "Nhập domain: " domain
                force_non_www_redirect "$domain"
                pause
                ;;
            5)
                list_redirects
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Subdomain Menu
subdomain_menu() {
    while true; do
        show_header
        echo -e "${CYAN}SUBDOMAIN MANAGEMENT${NC}"
        echo ""
        echo "1.  Create Subdomain (Full WordPress Site)"
        echo "2.  Create Subdomain Alias (Share Parent Pool)"
        echo "3.  Create Wildcard Subdomain"
        echo "4.  Remove Subdomain"
        echo "5.  Remove Wildcard Subdomain"
        echo "6.  List Subdomains"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-6]: " choice

        case $choice in
            1)
                read -p "Nhập tên subdomain (vd: blog): " subdomain
                read -p "Nhập parent domain: " parent_domain
                create_subdomain_site "$subdomain" "$parent_domain"
                pause
                ;;
            2)
                read -p "Nhập tên subdomain (vd: blog): " subdomain
                read -p "Nhập parent domain: " parent_domain
                read -p "Nhập subfolder (để trống = tên subdomain): " subfolder
                subfolder=${subfolder:-$subdomain}
                create_subdomain_alias "$subdomain" "$parent_domain" "$subfolder"
                pause
                ;;
            3)
                read -p "Nhập parent domain: " parent_domain
                read -p "Document root (để trống = parent root): " doc_root
                create_wildcard_subdomain "$parent_domain" "$doc_root"
                pause
                ;;
            4)
                read -p "Nhập tên subdomain: " subdomain
                read -p "Nhập parent domain: " parent_domain
                remove_subdomain "$subdomain" "$parent_domain"
                pause
                ;;
            5)
                read -p "Nhập parent domain: " parent_domain
                remove_wildcard_subdomain "$parent_domain"
                pause
                ;;
            6)
                read -p "Nhập parent domain: " parent_domain
                list_subdomains "$parent_domain"
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Cloudflare Menu
cloudflare_menu() {
    while true; do
        show_header
        echo -e "${CYAN}CLOUDFLARE INTEGRATION${NC}"
        echo ""
        echo "1.  Setup Cloudflare API"
        echo "2.  Check Cloudflare Status"
        echo "3.  Get Zone ID"
        echo "4.  Add DNS Record"
        echo "5.  List DNS Records"
        echo "6.  Delete DNS Record"
        echo "7.  Purge Cache (All)"
        echo "8.  Purge Cache (URLs)"
        echo "9.  Get SSL Status"
        echo "10. Set SSL Mode"
        echo "11. Enable Development Mode"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-11]: " choice

        case $choice in
            1)
                setup_cloudflare
                ;;
            2)
                check_cloudflare_status
                ;;
            3)
                read -p "Nhập domain: " domain
                zone_id=$(get_zone_id "$domain")
                if [[ -n "$zone_id" ]]; then
                    print_success "Zone ID: $zone_id"
                fi
                pause
                ;;
            4)
                read -p "Nhập domain: " domain
                read -p "Nhập record name (vd: www): " record_name
                read -p "Nhập IP address: " ip_address
                echo "1. A Record (proxied)"
                echo "2. A Record (DNS only)"
                read -p "Chọn [1]: " record_choice
                record_choice=${record_choice:-1}
                if [[ "$record_choice" == "1" ]]; then
                    proxied="true"
                else
                    proxied="false"
                fi
                add_dns_record "$domain" "$record_name" "$ip_address" "A" "$proxied"
                pause
                ;;
            5)
                read -p "Nhập domain: " domain
                list_dns_records "$domain"
                pause
                ;;
            6)
                read -p "Nhập domain: " domain
                read -p "Nhập DNS record ID: " record_id
                delete_dns_record "$domain" "$record_id"
                pause
                ;;
            7)
                read -p "Nhập domain: " domain
                purge_cloudflare_cache "$domain" "all"
                pause
                ;;
            8)
                read -p "Nhập domain: " domain
                echo "Nhập URLs (mỗi URL một dòng, Enter 2 lần để kết thúc):"
                urls=()
                while IFS= read -r url; do
                    [[ -z "$url" ]] && break
                    urls+=("$url")
                done
                if [[ ${#urls[@]} -gt 0 ]]; then
                    purge_cloudflare_urls "$domain" "${urls[@]}"
                else
                    print_error "Không có URL nào"
                fi
                pause
                ;;
            9)
                read -p "Nhập domain: " domain
                get_ssl_status "$domain"
                pause
                ;;
            10)
                read -p "Nhập domain: " domain
                echo "1. Off"
                echo "2. Flexible"
                echo "3. Full"
                echo "4. Full (strict)"
                read -p "Chọn SSL mode: " ssl_choice
                case $ssl_choice in
                    1) ssl_mode="off" ;;
                    2) ssl_mode="flexible" ;;
                    3) ssl_mode="full" ;;
                    4) ssl_mode="strict" ;;
                    *) print_error "Lựa chọn không hợp lệ"; continue ;;
                esac
                set_ssl_mode "$domain" "$ssl_mode"
                pause
                ;;
            11)
                read -p "Nhập domain: " domain
                enable_dev_mode "$domain"
                pause
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}
