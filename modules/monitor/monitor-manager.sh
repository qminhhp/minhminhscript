#!/bin/bash
# Monitor Manager Module
# Giám sát tài nguyên hệ thống và WordPress sites

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Check system resources
check_system_resources() {
    show_header
    echo -e "${CYAN}THÔNG TIN TÀI NGUYÊN HỆ THỐNG${NC}"
    echo ""

    # CPU Usage
    echo -e "${YELLOW}CPU:${NC}"
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    echo "  Usage: $cpu_usage"
    echo "  Cores: $(nproc)"
    echo ""

    # Memory Usage
    echo -e "${YELLOW}RAM:${NC}"
    free -h | grep -E "^Mem|^Swap"
    echo ""

    # Disk Usage
    echo -e "${YELLOW}DISK:${NC}"
    df -h | grep -E "^/dev"
    echo ""

    # Load Average
    echo -e "${YELLOW}LOAD AVERAGE:${NC}"
    uptime
    echo ""

    show_footer
    pause
}

# Check service status
check_services() {
    show_header
    echo -e "${CYAN}TRẠNG THÁI DỊCH VỤ${NC}"
    echo ""

    # Nginx
    echo -e "${YELLOW}Nginx:${NC}"
    if systemctl is-active --quiet nginx; then
        print_success "Running"
    else
        print_error "Stopped"
    fi

    # PHP-FPM
    echo -e "${YELLOW}PHP-FPM ${PHP_VERSION}:${NC}"
    if systemctl is-active --quiet "php${PHP_VERSION}-fpm"; then
        print_success "Running"
    else
        print_error "Stopped"
    fi

    # MySQL/MariaDB
    echo -e "${YELLOW}MySQL/MariaDB:${NC}"
    if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
        print_success "Running"
    else
        print_error "Stopped"
    fi

    # Redis (if installed)
    if command_exists redis-server; then
        echo -e "${YELLOW}Redis:${NC}"
        if systemctl is-active --quiet redis-server; then
            print_success "Running"
        else
            print_error "Stopped"
        fi
    fi

    # Memcached (if installed)
    if command_exists memcached; then
        echo -e "${YELLOW}Memcached:${NC}"
        if systemctl is-active --quiet memcached; then
            print_success "Running"
        else
            print_error "Stopped"
        fi
    fi

    echo ""
    show_footer
    pause
}

# Monitor PHP-FPM pools
monitor_phpfpm_pools() {
    show_header
    echo -e "${CYAN}GIÁM SÁT PHP-FPM POOLS${NC}"
    echo ""

    if [[ ! -d "$PHP_FPM_POOL_DIR" ]]; then
        print_error "Thư mục PHP-FPM pool không tồn tại"
        show_footer
        pause
        return
    fi

    printf "%-30s %-10s %-10s\n" "POOL NAME" "STATUS" "PROCESSES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for pool_file in "${PHP_FPM_POOL_DIR}"/*.conf; do
        if [[ -f "$pool_file" ]]; then
            local pool_name=$(basename "$pool_file" .conf)
            if [[ "$pool_name" != "www" ]]; then
                local pool_pids=$(ps aux | grep "php-fpm: pool ${pool_name}" | grep -v grep | wc -l)
                if [[ $pool_pids -gt 0 ]]; then
                    printf "%-30s ${GREEN}%-10s${NC} %-10s\n" "$pool_name" "ACTIVE" "$pool_pids"
                else
                    printf "%-30s ${RED}%-10s${NC} %-10s\n" "$pool_name" "INACTIVE" "0"
                fi
            fi
        fi
    done

    echo ""
    show_footer
    pause
}

# Monitor disk usage for sites
monitor_disk_usage() {
    show_header
    echo -e "${CYAN}DUNG LƯỢNG SITES${NC}"
    echo ""

    source "${MODULES_DIR}/site/site-manager.sh"

    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào"
        show_footer
        pause
        return
    fi

    printf "%-5s %-30s %-15s\n" "STT" "DOMAIN" "SIZE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local count=1
    local total_size=0

    while IFS='|' read -r domain _ _ _ _ site_root _; do
        if [[ -d "$site_root" ]]; then
            local size=$(du -sh "$site_root" 2>/dev/null | cut -f1)
            local size_bytes=$(du -sb "$site_root" 2>/dev/null | cut -f1)
            printf "%-5s %-30s %-15s\n" "$count" "$domain" "$size"
            total_size=$((total_size + size_bytes))
        else
            printf "%-5s %-30s %-15s\n" "$count" "$domain" "N/A"
        fi
        ((count++))
    done < "$SITES_DB"

    echo ""
    local total_human=$(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "$total_size bytes")
    print_info "Tổng dung lượng: $total_human"

    show_footer
    pause
}

# Monitor database sizes
monitor_database_sizes() {
    show_header
    echo -e "${CYAN}DUNG LƯỢNG DATABASES${NC}"
    echo ""

    source "${MODULES_DIR}/site/site-manager.sh"
    source "${MODULES_DIR}/database/database-manager.sh"

    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào"
        show_footer
        pause
        return
    fi

    printf "%-5s %-30s %-20s %-15s\n" "STT" "DOMAIN" "DATABASE" "SIZE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local count=1

    while IFS='|' read -r domain _ _ db_name _ _ _; do
        local size=$(get_database_size "$db_name")
        printf "%-5s %-30s %-20s %-15s\n" "$count" "$domain" "$db_name" "$size"
        ((count++))
    done < "$SITES_DB"

    echo ""
    show_footer
    pause
}

# Check website accessibility
check_website_status() {
    local domain=$1

    if command_exists curl; then
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://${domain}" --max-time 10)

        if [[ "$http_code" == "200" ]]; then
            print_success "Website accessible (HTTP $http_code)"
            return 0
        else
            print_error "Website not accessible (HTTP $http_code)"
            return 1
        fi
    else
        print_warning "curl chưa được cài đặt"
        return 1
    fi
}

# Monitor all websites
monitor_all_websites() {
    show_header
    echo -e "${CYAN}GIÁM SÁT TRẠNG THÁI WEBSITES${NC}"
    echo ""

    source "${MODULES_DIR}/site/site-manager.sh"

    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào"
        show_footer
        pause
        return
    fi

    printf "%-5s %-30s %-15s\n" "STT" "DOMAIN" "STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local count=1
    local online=0
    local offline=0

    while IFS='|' read -r domain _ _ _ _ _ _; do
        printf "%-5s %-30s " "$count" "$domain"

        if check_website_status "$domain" >/dev/null 2>&1; then
            echo -e "${GREEN}ONLINE${NC}"
            ((online++))
        else
            echo -e "${RED}OFFLINE${NC}"
            ((offline++))
        fi

        ((count++))
    done < "$SITES_DB"

    echo ""
    print_info "Online: $online | Offline: $offline"

    show_footer
    pause
}

# Get system info
get_system_info() {
    show_header
    echo -e "${CYAN}THÔNG TIN HỆ THỐNG${NC}"
    echo ""

    echo -e "${YELLOW}Operating System:${NC}"
    cat /etc/os-release | grep -E "^PRETTY_NAME" | cut -d'"' -f2
    echo ""

    echo -e "${YELLOW}Kernel:${NC}"
    uname -r
    echo ""

    echo -e "${YELLOW}Hostname:${NC}"
    hostname
    echo ""

    echo -e "${YELLOW}IP Address:${NC}"
    hostname -I | awk '{print $1}'
    echo ""

    echo -e "${YELLOW}Uptime:${NC}"
    uptime -p
    echo ""

    echo -e "${YELLOW}Nginx Version:${NC}"
    nginx -v 2>&1 | cut -d'/' -f2
    echo ""

    echo -e "${YELLOW}PHP Version:${NC}"
    php -v | head -n 1 | cut -d' ' -f2
    echo ""

    echo -e "${YELLOW}MySQL Version:${NC}"
    mysql --version | awk '{print $5}' | cut -d',' -f1
    echo ""

    show_footer
    pause
}

# Generate status report
generate_status_report() {
    local report_file="${LOGS_DIR}/status_report_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "=========================================="
        echo "VPS STATUS REPORT"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=========================================="
        echo ""

        echo "SYSTEM INFO:"
        echo "------------"
        uname -a
        echo ""

        echo "CPU INFO:"
        echo "---------"
        lscpu | grep -E "Model name|CPU\(s\):"
        echo ""

        echo "MEMORY INFO:"
        echo "------------"
        free -h
        echo ""

        echo "DISK INFO:"
        echo "----------"
        df -h
        echo ""

        echo "SERVICE STATUS:"
        echo "---------------"
        systemctl status nginx --no-pager | head -n 5
        systemctl status "php${PHP_VERSION}-fpm" --no-pager | head -n 5
        systemctl status mysql --no-pager | head -n 5 || systemctl status mariadb --no-pager | head -n 5
        echo ""

        echo "SITES INFO:"
        echo "-----------"
        if [[ -f "$SITES_DB" ]]; then
            wc -l < "$SITES_DB"
            echo "sites registered"
        else
            echo "No sites"
        fi
        echo ""

    } > "$report_file"

    print_success "Đã tạo báo cáo: $report_file"
    log_message "INFO" "Generated status report: $report_file"

    echo "$report_file"
}

# Real-time monitoring
realtime_monitor() {
    show_header
    echo -e "${CYAN}GIÁM SÁT REAL-TIME${NC}"
    echo ""
    echo "Nhấn Ctrl+C để thoát"
    echo ""

    while true; do
        clear
        echo -e "${CYAN}=== REAL-TIME MONITORING ===${NC}"
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""

        # CPU & Memory
        echo -e "${YELLOW}CPU & Memory:${NC}"
        top -bn1 | head -n 5 | tail -n 2
        echo ""

        # Services
        echo -e "${YELLOW}Services:${NC}"
        systemctl is-active nginx && echo "Nginx: OK" || echo "Nginx: FAILED"
        systemctl is-active "php${PHP_VERSION}-fpm" && echo "PHP-FPM: OK" || echo "PHP-FPM: FAILED"
        systemctl is-active mysql mariadb && echo "Database: OK" || echo "Database: FAILED"
        echo ""

        # Wait 5 seconds
        sleep 5
    done
}
