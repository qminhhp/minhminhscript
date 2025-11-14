#!/bin/bash
# Firewall Manager Module
# Quản lý UFW/iptables firewall

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Check if UFW is installed
check_ufw_installed() {
    if command_exists ufw; then
        return 0
    else
        return 1
    fi
}

# Install UFW
install_ufw() {
    if check_ufw_installed; then
        print_warning "UFW đã được cài đặt"
        return 1
    fi

    print_info "Đang cài đặt UFW..."

    if command_exists apt-get; then
        apt-get update -qq
        apt-get install -y ufw
    elif command_exists yum; then
        yum -y install ufw
    else
        print_error "Không hỗ trợ hệ điều hành này"
        return 1
    fi

    print_success "Đã cài đặt UFW"
    log_message "INFO" "Installed UFW firewall"
    return 0
}

# Setup basic firewall rules
setup_firewall() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        print_info "Chạy install_ufw để cài đặt"
        return 1
    fi

    print_info "Đang cấu hình firewall rules..."

    # Reset to defaults
    print_info "Reset firewall rules..."
    ufw --force reset

    # Default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH (very important!)
    print_info "Allow SSH (port 22)..."
    ufw allow 22/tcp comment 'SSH'

    # Allow HTTP
    print_info "Allow HTTP (port 80)..."
    ufw allow 80/tcp comment 'HTTP'

    # Allow HTTPS
    print_info "Allow HTTPS (port 443)..."
    ufw allow 443/tcp comment 'HTTPS'

    # Enable UFW
    print_info "Enabling firewall..."
    ufw --force enable

    print_success "Đã cấu hình firewall"
    log_message "INFO" "Configured basic firewall rules"

    return 0
}

# Enable firewall
enable_firewall() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    ufw --force enable
    print_success "Đã bật firewall"
    log_message "INFO" "Enabled firewall"
    return 0
}

# Disable firewall
disable_firewall() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    print_warning "CẢNH BÁO: Tắt firewall sẽ mở tất cả ports!"

    if ! confirm_action "Bạn có chắc muốn tắt firewall?" "n"; then
        print_info "Đã hủy"
        return 1
    fi

    ufw --force disable
    print_success "Đã tắt firewall"
    log_message "WARNING" "Disabled firewall"
    return 0
}

# Allow a port
allow_port() {
    local port=$1
    local protocol=${2:-tcp}
    local comment=${3:-"Custom rule"}

    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    if [[ -z "$port" ]]; then
        print_error "Port không được để trống"
        return 1
    fi

    print_info "Đang allow port $port/$protocol..."
    ufw allow ${port}/${protocol} comment "${comment}"

    print_success "Đã allow port $port/$protocol"
    log_message "INFO" "Allowed port: $port/$protocol"
    return 0
}

# Deny a port
deny_port() {
    local port=$1
    local protocol=${2:-tcp}

    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    if [[ -z "$port" ]]; then
        print_error "Port không được để trống"
        return 1
    fi

    print_info "Đang deny port $port/$protocol..."
    ufw deny ${port}/${protocol}

    print_success "Đã deny port $port/$protocol"
    log_message "INFO" "Denied port: $port/$protocol"
    return 0
}

# Delete a rule
delete_rule() {
    local rule_number=$1

    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    if [[ -z "$rule_number" ]]; then
        print_error "Rule number không được để trống"
        return 1
    fi

    print_info "Đang xóa rule #$rule_number..."
    ufw --force delete $rule_number

    print_success "Đã xóa rule #$rule_number"
    log_message "INFO" "Deleted firewall rule: #$rule_number"
    return 0
}

# Allow from specific IP
allow_from_ip() {
    local ip_address=$1
    local port=${2:-any}
    local comment=${3:-"IP whitelist"}

    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    if [[ -z "$ip_address" ]]; then
        print_error "IP address không được để trống"
        return 1
    fi

    print_info "Đang allow từ IP: $ip_address..."

    if [[ "$port" == "any" ]]; then
        ufw allow from $ip_address comment "${comment}"
    else
        ufw allow from $ip_address to any port $port comment "${comment}"
    fi

    print_success "Đã allow từ IP: $ip_address"
    log_message "INFO" "Allowed from IP: $ip_address"
    return 0
}

# Deny from specific IP
deny_from_ip() {
    local ip_address=$1

    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    if [[ -z "$ip_address" ]]; then
        print_error "IP address không được để trống"
        return 1
    fi

    print_info "Đang deny từ IP: $ip_address..."
    ufw deny from $ip_address

    print_success "Đã deny từ IP: $ip_address"
    log_message "INFO" "Denied from IP: $ip_address"
    return 0
}

# SSH rate limiting
enable_ssh_rate_limiting() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    print_info "Đang cấu hình SSH rate limiting..."

    # Remove existing SSH rule
    ufw delete allow 22/tcp 2>/dev/null

    # Add rate limited SSH rule
    ufw limit 22/tcp comment 'SSH rate limit'

    print_success "Đã cấu hình SSH rate limiting"
    print_info "Max 6 connections per 30 seconds từ một IP"
    log_message "INFO" "Enabled SSH rate limiting"
    return 0
}

# Show firewall status
show_firewall_status() {
    show_header
    echo -e "${CYAN}FIREWALL STATUS${NC}"
    echo ""

    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        print_info "Chạy 'install_ufw' để cài đặt"
        show_footer
        pause
        return 1
    fi

    # Status
    local status=$(ufw status | head -1)
    echo -e "${YELLOW}Status:${NC} $status"
    echo ""

    # Rules
    echo -e "${YELLOW}Rules:${NC}"
    ufw status numbered
    echo ""

    show_footer
    pause
}

# Show firewall rules in detail
show_firewall_rules() {
    show_header
    echo -e "${CYAN}FIREWALL RULES (DETAILED)${NC}"
    echo ""

    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        show_footer
        pause
        return 1
    fi

    ufw status verbose
    echo ""

    show_footer
    pause
}

# Reset firewall to defaults
reset_firewall() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    print_warning "CẢNH BÁO: Tất cả firewall rules sẽ bị xóa!"

    if ! confirm_action "Bạn có chắc muốn reset firewall?" "n"; then
        print_info "Đã hủy"
        return 1
    fi

    print_info "Đang reset firewall..."
    ufw --force reset

    print_success "Đã reset firewall"
    print_warning "Firewall đã bị disabled. Chạy setup_firewall để cấu hình lại."
    log_message "WARNING" "Reset firewall to defaults"
    return 0
}

# Backup firewall rules
backup_firewall_rules() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    local backup_dir="${BACKUP_DIR}/firewall"
    local backup_file="${backup_dir}/ufw-rules-$(date +%Y%m%d-%H%M%S).txt"

    mkdir -p "$backup_dir"

    print_info "Đang backup firewall rules..."

    # Backup UFW status and rules
    {
        echo "# UFW Backup - $(date)"
        echo "# Status:"
        ufw status numbered
        echo ""
        echo "# Detailed:"
        ufw status verbose
    } > "$backup_file"

    # Also backup UFW config files
    if [[ -d /etc/ufw ]]; then
        tar -czf "${backup_dir}/ufw-config-$(date +%Y%m%d-%H%M%S).tar.gz" /etc/ufw 2>/dev/null
    fi

    print_success "Đã backup firewall rules: $backup_file"
    log_message "INFO" "Backed up firewall rules"
    return 0
}

# Common ports preset
setup_common_ports() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    print_info "Đang cấu hình common ports..."

    # MySQL (only from localhost)
    ufw allow from 127.0.0.1 to any port 3306 comment 'MySQL localhost'

    # Redis (only from localhost)
    ufw allow from 127.0.0.1 to any port 6379 comment 'Redis localhost'

    # Memcached (only from localhost)
    ufw allow from 127.0.0.1 to any port 11211 comment 'Memcached localhost'

    print_success "Đã cấu hình common ports"
    print_info "MySQL, Redis, Memcached: chỉ cho phép localhost"
    log_message "INFO" "Configured common ports"
    return 0
}

# Block common attack ports
block_attack_ports() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    print_info "Đang block common attack ports..."

    # Common ports used in attacks
    local attack_ports=(23 135 137 138 139 445 1433 3389)

    for port in "${attack_ports[@]}"; do
        ufw deny $port/tcp comment "Block attack port"
        ufw deny $port/udp comment "Block attack port"
    done

    print_success "Đã block common attack ports"
    log_message "INFO" "Blocked common attack ports"
    return 0
}

# Enable IPv6
enable_ipv6() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    print_info "Đang enable IPv6..."

    sed -i 's/IPV6=no/IPV6=yes/' /etc/default/ufw

    # Reload UFW
    ufw reload

    print_success "Đã enable IPv6"
    log_message "INFO" "Enabled IPv6 in firewall"
    return 0
}

# Disable IPv6
disable_ipv6() {
    if ! check_ufw_installed; then
        print_error "UFW chưa được cài đặt"
        return 1
    fi

    print_info "Đang disable IPv6..."

    sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw

    # Reload UFW
    ufw reload

    print_success "Đã disable IPv6"
    log_message "INFO" "Disabled IPv6 in firewall"
    return 0
}
