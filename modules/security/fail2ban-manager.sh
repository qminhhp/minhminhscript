#!/bin/bash
# Fail2ban Manager Module
# Quản lý Fail2ban với WordPress filters

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Check if Fail2ban is installed
check_fail2ban_installed() {
    if command_exists fail2ban-client; then
        return 0
    else
        return 1
    fi
}

# Install Fail2ban
install_fail2ban() {
    if check_fail2ban_installed; then
        print_warning "Fail2ban đã được cài đặt"
        return 1
    fi

    print_info "Đang cài đặt Fail2ban..."

    if command_exists apt-get; then
        apt-get update -qq
        apt-get install -y fail2ban
    elif command_exists yum; then
        yum -y install fail2ban
    else
        print_error "Không hỗ trợ hệ điều hành này"
        return 1
    fi

    # Enable and start service
    systemctl enable fail2ban
    systemctl start fail2ban

    print_success "Đã cài đặt Fail2ban"
    log_message "INFO" "Installed Fail2ban"
    return 0
}

# Create WordPress XML-RPC filter
create_wordpress_xmlrpc_filter() {
    local filter_file="/etc/fail2ban/filter.d/wordpress-xmlrpc.conf"

    print_info "Đang tạo WordPress XML-RPC filter..."

    cat > "$filter_file" <<'EOF'
# Fail2Ban filter for WordPress XML-RPC attacks
# Detects brute force attacks via xmlrpc.php

[Definition]
failregex = ^<HOST> .* "POST .*xmlrpc\.php.*" (403|200)
ignoreregex =

# datepattern = {^LN-BEG}%%b %%d %%H:%%M:%%S(?:\.%%f)? %%ExY
EOF

    print_success "Đã tạo WordPress XML-RPC filter"
    return 0
}

# Create WordPress wp-login filter
create_wordpress_login_filter() {
    local filter_file="/etc/fail2ban/filter.d/wordpress-wp-login.conf"

    print_info "Đang tạo WordPress wp-login filter..."

    cat > "$filter_file" <<'EOF'
# Fail2Ban filter for WordPress login attempts
# Detects brute force attacks on wp-login.php

[Definition]
failregex = ^<HOST> .* "POST .*wp-login\.php.*" (403|200)
            ^<HOST> .* "POST .*wp-admin.*" 403
ignoreregex =

# datepattern = {^LN-BEG}%%b %%d %%H:%%M:%%S(?:\.%%f)? %%ExY
EOF

    print_success "Đã tạo WordPress wp-login filter"
    return 0
}

# Create WordPress 404 filter
create_wordpress_404_filter() {
    local filter_file="/etc/fail2ban/filter.d/wordpress-404.conf"

    print_info "Đang tạo WordPress 404 filter..."

    cat > "$filter_file" <<'EOF'
# Fail2Ban filter for WordPress 404 errors
# Detects scanning/probing attempts

[Definition]
failregex = ^<HOST> .* "(GET|POST) .* 404
ignoreregex = .*(robots\.txt|favicon\.ico)

# datepattern = {^LN-BEG}%%b %%d %%H:%%M:%%S(?:\.%%f)? %%ExY
EOF

    print_success "Đã tạo WordPress 404 filter"
    return 0
}

# Setup WordPress Fail2ban jails
setup_wordpress_jails() {
    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        return 1
    fi

    local jail_file="/etc/fail2ban/jail.d/wordpress.conf"

    print_info "Đang cấu hình WordPress jails..."

    # Create filters first
    create_wordpress_xmlrpc_filter
    create_wordpress_login_filter
    create_wordpress_404_filter

    # Create jail configuration
    cat > "$jail_file" <<EOF
# WordPress Fail2Ban jails
# Protect WordPress sites from brute force attacks

[wordpress-xmlrpc]
enabled = true
filter = wordpress-xmlrpc
port = http,https
logpath = /var/log/nginx/*access.log
          /home/*/logs/*/access.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=wordpress-xmlrpc, port="http,https", protocol=tcp]

[wordpress-wp-login]
enabled = true
filter = wordpress-wp-login
port = http,https
logpath = /var/log/nginx/*access.log
          /home/*/logs/*/access.log
maxretry = 5
findtime = 300
bantime = 3600
action = iptables-multiport[name=wordpress-wp-login, port="http,https", protocol=tcp]

[wordpress-404]
enabled = false
filter = wordpress-404
port = http,https
logpath = /var/log/nginx/*access.log
          /home/*/logs/*/access.log
maxretry = 20
findtime = 300
bantime = 600
action = iptables-multiport[name=wordpress-404, port="http,https", protocol=tcp]
EOF

    # Reload Fail2ban
    systemctl restart fail2ban

    print_success "Đã cấu hình WordPress jails"
    print_info ""
    print_info "Jails đã kích hoạt:"
    print_info "- wordpress-xmlrpc: Ban sau 5 attempts trong 5 phút"
    print_info "- wordpress-wp-login: Ban sau 5 attempts trong 5 phút"
    print_info "- wordpress-404: Disabled (có thể enable sau)"

    log_message "INFO" "Configured WordPress Fail2ban jails"
    return 0
}

# Enable a jail
enable_jail() {
    local jail_name=$1

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        return 1
    fi

    if [[ -z "$jail_name" ]]; then
        print_error "Jail name không được để trống"
        return 1
    fi

    local jail_file="/etc/fail2ban/jail.d/wordpress.conf"

    if [[ ! -f "$jail_file" ]]; then
        print_error "WordPress jails chưa được cấu hình"
        print_info "Chạy setup_wordpress_jails để cấu hình"
        return 1
    fi

    print_info "Đang enable jail: $jail_name..."

    # Enable the jail in config
    sed -i "/\[${jail_name}\]/,/^\[/ s/enabled = false/enabled = true/" "$jail_file"

    # Reload Fail2ban
    systemctl restart fail2ban

    print_success "Đã enable jail: $jail_name"
    log_message "INFO" "Enabled Fail2ban jail: $jail_name"
    return 0
}

# Disable a jail
disable_jail() {
    local jail_name=$1

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        return 1
    fi

    if [[ -z "$jail_name" ]]; then
        print_error "Jail name không được để trống"
        return 1
    fi

    local jail_file="/etc/fail2ban/jail.d/wordpress.conf"

    if [[ ! -f "$jail_file" ]]; then
        print_error "WordPress jails chưa được cấu hình"
        return 1
    fi

    print_info "Đang disable jail: $jail_name..."

    # Disable the jail in config
    sed -i "/\[${jail_name}\]/,/^\[/ s/enabled = true/enabled = false/" "$jail_file"

    # Reload Fail2ban
    systemctl restart fail2ban

    print_success "Đã disable jail: $jail_name"
    log_message "INFO" "Disabled Fail2ban jail: $jail_name"
    return 0
}

# Show Fail2ban status
show_fail2ban_status() {
    show_header
    echo -e "${CYAN}FAIL2BAN STATUS${NC}"
    echo ""

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        print_info "Chạy 'install_fail2ban' để cài đặt"
        show_footer
        pause
        return 1
    fi

    # Service status
    if systemctl is-active --quiet fail2ban; then
        print_success "Service: Running"
    else
        print_error "Service: Stopped"
    fi
    echo ""

    # List all jails
    echo -e "${YELLOW}Active Jails:${NC}"
    fail2ban-client status
    echo ""

    show_footer
    pause
}

# Show jail status
show_jail_status() {
    local jail_name=$1

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        return 1
    fi

    if [[ -z "$jail_name" ]]; then
        # Show all jails
        fail2ban-client status
    else
        # Show specific jail
        show_header
        echo -e "${CYAN}JAIL STATUS: $jail_name${NC}"
        echo ""

        fail2ban-client status "$jail_name"

        echo ""
        show_footer
        pause
    fi

    return 0
}

# Unban an IP
unban_ip() {
    local ip_address=$1
    local jail_name=${2:-all}

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        return 1
    fi

    if [[ -z "$ip_address" ]]; then
        print_error "IP address không được để trống"
        return 1
    fi

    print_info "Đang unban IP: $ip_address"

    if [[ "$jail_name" == "all" ]]; then
        # Unban from all jails
        local jails=$(fail2ban-client status | grep "Jail list" | cut -d: -f2 | tr -d ' ' | tr ',' ' ')

        for jail in $jails; do
            fail2ban-client set "$jail" unbanip "$ip_address" 2>/dev/null
        done

        print_success "Đã unban IP từ tất cả jails"
    else
        # Unban from specific jail
        fail2ban-client set "$jail_name" unbanip "$ip_address"
        print_success "Đã unban IP từ jail: $jail_name"
    fi

    log_message "INFO" "Unbanned IP: $ip_address"
    return 0
}

# Ban an IP manually
ban_ip() {
    local ip_address=$1
    local jail_name=${2:-wordpress-wp-login}

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        return 1
    fi

    if [[ -z "$ip_address" ]]; then
        print_error "IP address không được để trống"
        return 1
    fi

    print_info "Đang ban IP: $ip_address trong jail: $jail_name"

    fail2ban-client set "$jail_name" banip "$ip_address"

    print_success "Đã ban IP: $ip_address"
    log_message "WARNING" "Manually banned IP: $ip_address in $jail_name"
    return 0
}

# List banned IPs
list_banned_ips() {
    local jail_name=$1

    show_header
    echo -e "${CYAN}BANNED IPs${NC}"
    echo ""

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        show_footer
        pause
        return 1
    fi

    if [[ -z "$jail_name" ]]; then
        # List all jails
        local jails=$(fail2ban-client status | grep "Jail list" | cut -d: -f2 | tr -d ' ' | tr ',' ' ')

        for jail in $jails; do
            echo -e "${YELLOW}Jail: $jail${NC}"
            fail2ban-client status "$jail" | grep "Banned IP"
            echo ""
        done
    else
        # List specific jail
        echo -e "${YELLOW}Jail: $jail_name${NC}"
        fail2ban-client status "$jail_name" | grep "Banned IP"
        echo ""
    fi

    show_footer
    pause
}

# Configure jail settings
configure_jail_settings() {
    local jail_name=$1
    local maxretry=$2
    local findtime=$3
    local bantime=$4

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        return 1
    fi

    local jail_file="/etc/fail2ban/jail.d/wordpress.conf"

    if [[ ! -f "$jail_file" ]]; then
        print_error "WordPress jails chưa được cấu hình"
        return 1
    fi

    print_info "Đang cấu hình jail: $jail_name"

    # Update settings
    sed -i "/\[${jail_name}\]/,/^\[/ {
        s/maxretry = .*/maxretry = $maxretry/
        s/findtime = .*/findtime = $findtime/
        s/bantime = .*/bantime = $bantime/
    }" "$jail_file"

    # Reload Fail2ban
    systemctl restart fail2ban

    print_success "Đã cấu hình jail: $jail_name"
    print_info "maxretry: $maxretry, findtime: ${findtime}s, bantime: ${bantime}s"
    log_message "INFO" "Configured Fail2ban jail: $jail_name"
    return 0
}

# Whitelist an IP
whitelist_ip() {
    local ip_address=$1

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        return 1
    fi

    if [[ -z "$ip_address" ]]; then
        print_error "IP address không được để trống"
        return 1
    fi

    local jail_local="/etc/fail2ban/jail.local"

    print_info "Đang whitelist IP: $ip_address"

    # Create jail.local if not exists
    if [[ ! -f "$jail_local" ]]; then
        cat > "$jail_local" <<EOF
[DEFAULT]
# Whitelisted IPs
ignoreip = 127.0.0.1/8 ::1
EOF
    fi

    # Add IP to ignoreip
    if ! grep -q "$ip_address" "$jail_local"; then
        sed -i "/^ignoreip/s/$/ $ip_address/" "$jail_local"

        # Reload Fail2ban
        systemctl restart fail2ban

        print_success "Đã whitelist IP: $ip_address"
        log_message "INFO" "Whitelisted IP: $ip_address"
    else
        print_warning "IP đã được whitelist: $ip_address"
    fi

    return 0
}

# Test Fail2ban filters
test_filter() {
    local filter_name=$1
    local log_file=${2:-/var/log/nginx/access.log}

    if ! check_fail2ban_installed; then
        print_error "Fail2ban chưa được cài đặt"
        return 1
    fi

    if [[ -z "$filter_name" ]]; then
        print_error "Filter name không được để trống"
        return 1
    fi

    print_info "Testing filter: $filter_name với log: $log_file"
    echo ""

    fail2ban-regex "$log_file" "/etc/fail2ban/filter.d/${filter_name}.conf"

    pause
    return 0
}
