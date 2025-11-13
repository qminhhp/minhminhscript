#!/bin/bash
# Security Management Menu
# Menu tổng hợp Firewall, Fail2ban, Logrotate

source "${SCRIPT_DIR}/lib/common.sh"
source "${MODULES_DIR}/security/firewall-manager.sh"
source "${MODULES_DIR}/security/fail2ban-manager.sh"
source "${MODULES_DIR}/security/logrotate-manager.sh"

# Main Security Menu
security_management_menu() {
    while true; do
        show_header
        echo -e "${CYAN}QUẢN LÝ BẢO MẬT${NC}"
        echo ""
        echo "1.  Firewall (UFW)"
        echo "2.  Fail2ban"
        echo "3.  Logrotate"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-3]: " choice

        case $choice in
            1) firewall_menu ;;
            2) fail2ban_menu ;;
            3) logrotate_menu ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Firewall Menu
firewall_menu() {
    while true; do
        show_header
        echo -e "${CYAN}FIREWALL (UFW) MANAGEMENT${NC}"
        echo ""
        echo "1.  Install UFW"
        echo "2.  Setup Basic Rules"
        echo "3.  Enable Firewall"
        echo "4.  Disable Firewall"
        echo "5.  Show Status"
        echo "6.  Show Rules (Detailed)"
        echo "7.  Allow Port"
        echo "8.  Deny Port"
        echo "9.  Delete Rule"
        echo "10. Allow from IP"
        echo "11. Deny from IP"
        echo "12. SSH Rate Limiting"
        echo "13. Setup Common Ports"
        echo "14. Block Attack Ports"
        echo "15. Reset Firewall"
        echo "16. Backup Rules"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-16]: " choice

        case $choice in
            1)
                install_ufw
                pause
                ;;
            2)
                setup_firewall
                pause
                ;;
            3)
                enable_firewall
                pause
                ;;
            4)
                disable_firewall
                pause
                ;;
            5)
                show_firewall_status
                ;;
            6)
                show_firewall_rules
                ;;
            7)
                read -p "Nhập port: " port
                read -p "Protocol (tcp/udp) [tcp]: " protocol
                protocol=${protocol:-tcp}
                read -p "Comment: " comment
                allow_port "$port" "$protocol" "$comment"
                pause
                ;;
            8)
                read -p "Nhập port: " port
                read -p "Protocol (tcp/udp) [tcp]: " protocol
                protocol=${protocol:-tcp}
                deny_port "$port" "$protocol"
                pause
                ;;
            9)
                show_firewall_status
                read -p "Nhập rule number để xóa: " rule_num
                delete_rule "$rule_num"
                pause
                ;;
            10)
                read -p "Nhập IP address: " ip
                read -p "Port (any hoặc số port) [any]: " port
                port=${port:-any}
                read -p "Comment: " comment
                allow_from_ip "$ip" "$port" "$comment"
                pause
                ;;
            11)
                read -p "Nhập IP address: " ip
                deny_from_ip "$ip"
                pause
                ;;
            12)
                enable_ssh_rate_limiting
                pause
                ;;
            13)
                setup_common_ports
                pause
                ;;
            14)
                block_attack_ports
                pause
                ;;
            15)
                reset_firewall
                pause
                ;;
            16)
                backup_firewall_rules
                pause
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Fail2ban Menu
fail2ban_menu() {
    while true; do
        show_header
        echo -e "${CYAN}FAIL2BAN MANAGEMENT${NC}"
        echo ""
        echo "1.  Install Fail2ban"
        echo "2.  Setup WordPress Jails"
        echo "3.  Show Status"
        echo "4.  Show Jail Status"
        echo "5.  Enable Jail"
        echo "6.  Disable Jail"
        echo "7.  List Banned IPs"
        echo "8.  Unban IP"
        echo "9.  Ban IP Manually"
        echo "10. Whitelist IP"
        echo "11. Configure Jail Settings"
        echo "12. Test Filter"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-12]: " choice

        case $choice in
            1)
                install_fail2ban
                pause
                ;;
            2)
                setup_wordpress_jails
                pause
                ;;
            3)
                show_fail2ban_status
                ;;
            4)
                read -p "Nhập jail name (để trống = all): " jail
                show_jail_status "$jail"
                ;;
            5)
                echo "WordPress jails:"
                echo "- wordpress-xmlrpc"
                echo "- wordpress-wp-login"
                echo "- wordpress-404"
                read -p "Nhập jail name: " jail
                enable_jail "$jail"
                pause
                ;;
            6)
                read -p "Nhập jail name: " jail
                disable_jail "$jail"
                pause
                ;;
            7)
                read -p "Nhập jail name (để trống = all): " jail
                list_banned_ips "$jail"
                ;;
            8)
                read -p "Nhập IP address: " ip
                read -p "Nhập jail name (all = tất cả jails) [all]: " jail
                jail=${jail:-all}
                unban_ip "$ip" "$jail"
                pause
                ;;
            9)
                read -p "Nhập IP address: " ip
                read -p "Nhập jail name [wordpress-wp-login]: " jail
                jail=${jail:-wordpress-wp-login}
                ban_ip "$ip" "$jail"
                pause
                ;;
            10)
                read -p "Nhập IP address để whitelist: " ip
                whitelist_ip "$ip"
                pause
                ;;
            11)
                read -p "Nhập jail name: " jail
                read -p "Max retry [5]: " maxretry
                read -p "Find time (seconds) [300]: " findtime
                read -p "Ban time (seconds) [3600]: " bantime
                maxretry=${maxretry:-5}
                findtime=${findtime:-300}
                bantime=${bantime:-3600}
                configure_jail_settings "$jail" "$maxretry" "$findtime" "$bantime"
                pause
                ;;
            12)
                echo "Filters:"
                echo "- wordpress-xmlrpc"
                echo "- wordpress-wp-login"
                echo "- wordpress-404"
                read -p "Nhập filter name: " filter
                read -p "Log file [/var/log/nginx/access.log]: " logfile
                logfile=${logfile:-/var/log/nginx/access.log}
                test_filter "$filter" "$logfile"
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}

# Logrotate Menu
logrotate_menu() {
    while true; do
        show_header
        echo -e "${CYAN}LOGROTATE MANAGEMENT${NC}"
        echo ""
        echo "1.  Install Logrotate"
        echo "2.  Setup WordPress Logrotate"
        echo "3.  Setup PHP-FPM Logrotate"
        echo "4.  Setup MySQL Logrotate"
        echo "5.  Show Status"
        echo "6.  List Configs"
        echo "7.  View Config"
        echo "8.  Create Custom Config"
        echo "9.  Delete Config"
        echo "10. Test Configuration"
        echo "11. Force Rotate Now"
        echo "12. Clean Old Logs"
        echo "13. Show Disk Usage"
        echo ""
        echo "0.  Quay lại"
        show_footer

        read -p "Nhập lựa chọn của bạn [0-13]: " choice

        case $choice in
            1)
                install_logrotate
                pause
                ;;
            2)
                setup_wordpress_logrotate
                pause
                ;;
            3)
                setup_phpfpm_logrotate
                pause
                ;;
            4)
                setup_mysql_logrotate
                pause
                ;;
            5)
                show_logrotate_status
                ;;
            6)
                list_logrotate_configs
                ;;
            7)
                read -p "Nhập config name: " config
                view_logrotate_config "$config"
                ;;
            8)
                read -p "Config name: " config_name
                read -p "Log path: " log_path
                read -p "Rotate count [8]: " rotate_count
                read -p "Period (daily/weekly/monthly) [weekly]: " period
                read -p "Max size [50M]: " maxsize
                rotate_count=${rotate_count:-8}
                period=${period:-weekly}
                maxsize=${maxsize:-50M}
                create_custom_logrotate "$config_name" "$log_path" "$rotate_count" "$period" "$maxsize"
                pause
                ;;
            9)
                read -p "Nhập config name để xóa: " config
                delete_logrotate_config "$config"
                pause
                ;;
            10)
                test_logrotate_config
                ;;
            11)
                force_logrotate
                pause
                ;;
            12)
                read -p "Xóa logs cũ hơn bao nhiêu ngày? [30]: " days
                days=${days:-30}
                clean_old_logs "$days"
                pause
                ;;
            13)
                show_logs_disk_usage
                ;;
            0) return ;;
            *) print_error "Lựa chọn không hợp lệ" ;;
        esac
    done
}
