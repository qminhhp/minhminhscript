#!/bin/bash
# n8n Manager Module
# Quản lý n8n workflow automation instances

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# n8n database file
N8N_DB="${DATA_DIR}/n8n_instances.db"
N8N_DATA_DIR="/var/lib/n8n"
N8N_COMPOSE_DIR="/opt/n8n-instances"

# Ensure n8n database exists
ensure_n8n_db() {
    if [[ ! -f "$N8N_DB" ]]; then
        ensure_directory "$(dirname "$N8N_DB")"
        touch "$N8N_DB"
    fi
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        return 1
    fi
    return 0
}

# Install Docker
install_docker() {
    print_info "Đang cài đặt Docker..."

    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null

    # Install prerequisites
    apt-get update -qq
    apt-get install -y ca-certificates curl gnupg lsb-release

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    if docker --version &>/dev/null; then
        print_success "Đã cài đặt Docker: $(docker --version)"
        log_message "INFO" "Installed Docker"
        return 0
    else
        print_error "Không thể cài đặt Docker"
        return 1
    fi
}

# Check if n8n instance exists
n8n_instance_exists() {
    local domain=$1
    ensure_n8n_db

    if grep -q "^${domain}|" "$N8N_DB" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Get n8n instance info
get_n8n_instance_info() {
    local domain=$1
    ensure_n8n_db

    grep "^${domain}|" "$N8N_DB" 2>/dev/null
}

# Generate random encryption key
generate_encryption_key() {
    openssl rand -hex 32
}

# Create n8n instance with Docker
add_n8n_instance() {
    show_header
    echo -e "${CYAN}THÊM N8N INSTANCE${NC}"
    echo ""

    print_info "n8n là công cụ workflow automation self-hosted"
    print_info "Sẽ được cài đặt qua Docker với reverse proxy"
    echo ""

    # Check Docker
    if ! check_docker; then
        print_warning "Docker chưa được cài đặt"
        if confirm_action "Cài đặt Docker ngay?" "y"; then
            install_docker
            if [[ $? -ne 0 ]]; then
                print_error "Không thể cài đặt Docker"
                pause
                return 1
            fi
        else
            print_warning "Cần Docker để chạy n8n"
            pause
            return 1
        fi
    fi

    # Input domain
    echo ""
    read -p "Nhập tên miền cho n8n (vd: automation.example.com): " domain

    if [[ -z "$domain" ]]; then
        print_error "Tên miền không được để trống"
        pause
        return 1
    fi

    # Check if already exists
    if n8n_instance_exists "$domain"; then
        print_error "n8n instance cho domain $domain đã tồn tại"
        pause
        return 1
    fi

    # Generate instance name
    local instance_name=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
    local container_name="n8n_${instance_name}"
    local port=$(get_random_port 5678 5778)

    # Generate encryption key
    local encryption_key=$(generate_encryption_key)

    # Create data directory
    local data_dir="${N8N_DATA_DIR}/${instance_name}"
    ensure_directory "$data_dir"

    print_info "Đang tạo n8n instance: $domain"
    echo ""

    # Get basic auth credentials (optional)
    read -p "Tạo Basic Auth để bảo vệ trước khi setup? (y/n): " use_basic_auth
    local basic_auth_user=""
    local basic_auth_pass=""

    if [[ "$use_basic_auth" == "y" ]]; then
        read -p "Nhập username: " basic_auth_user
        read -s -p "Nhập password: " basic_auth_pass
        echo ""
    fi

    # Create Docker Compose file
    local compose_dir="${N8N_COMPOSE_DIR}/${instance_name}"
    ensure_directory "$compose_dir"

    cat > "${compose_dir}/docker-compose.yml" <<EOF
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: ${container_name}
    restart: unless-stopped
    ports:
      - "127.0.0.1:${port}:5678"
    environment:
      - N8N_HOST=${domain}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${domain}/
      - N8N_ENCRYPTION_KEY=${encryption_key}
      - GENERIC_TIMEZONE=Asia/Ho_Chi_Minh
      - TZ=Asia/Ho_Chi_Minh
$(if [[ -n "$basic_auth_user" ]]; then
echo "      - N8N_BASIC_AUTH_ACTIVE=true"
echo "      - N8N_BASIC_AUTH_USER=${basic_auth_user}"
echo "      - N8N_BASIC_AUTH_PASSWORD=${basic_auth_pass}"
fi)
    volumes:
      - ${data_dir}:/home/node/.n8n
    labels:
      - "traefik.enable=false"
    networks:
      - n8n_network

networks:
  n8n_network:
    driver: bridge
EOF

    # Start Docker container
    print_info "Đang khởi động n8n container..."
    cd "$compose_dir"
    docker compose up -d

    if [[ $? -ne 0 ]]; then
        print_error "Không thể khởi động n8n container"
        pause
        return 1
    fi

    # Wait for n8n to be ready
    print_info "Đợi n8n khởi động (30s)..."
    sleep 30

    # Create Nginx reverse proxy
    print_info "Tạo Nginx reverse proxy..."
    source "${MODULES_DIR}/nginx/nginx-manager.sh"
    create_n8n_nginx_vhost "$domain" "$port" "$basic_auth_user" "$basic_auth_pass"

    # Save instance info
    echo "${domain}|${instance_name}|${container_name}|${port}|${data_dir}|${compose_dir}|$(date '+%Y-%m-%d %H:%M:%S')" >> "$N8N_DB"

    print_success "n8n instance đã được tạo!"
    echo ""
    print_info "Thông tin instance:"
    echo "  Domain: $domain"
    echo "  Container: $container_name"
    echo "  Port: 127.0.0.1:$port"
    echo "  Data Directory: $data_dir"
    if [[ -n "$basic_auth_user" ]]; then
        echo "  Basic Auth User: $basic_auth_user"
        print_warning "  Lưu lại password: $basic_auth_pass"
    fi
    echo ""
    print_info "Bước tiếp theo:"
    echo "  1. Setup SSL: wpminhminhscript setup-ssl $domain"
    echo "  2. Truy cập: https://${domain}"
    echo "  3. Tạo tài khoản owner đầu tiên"
    echo ""

    log_message "INFO" "Created n8n instance: $domain"
    pause
    return 0
}

# Get random available port
get_random_port() {
    local start_port=$1
    local end_port=$2
    local port

    for ((port=start_port; port<=end_port; port++)); do
        if ! netstat -tuln 2>/dev/null | grep -q ":${port} " && ! grep -q "|${port}|" "$N8N_DB" 2>/dev/null; then
            echo "$port"
            return 0
        fi
    done

    # If all ports in range are taken, generate random
    echo $((RANDOM % 1000 + 5678))
}

# List n8n instances
list_n8n_instances() {
    show_header
    echo -e "${CYAN}DANH SÁCH N8N INSTANCES${NC}"
    echo ""

    ensure_n8n_db

    if [[ ! -s "$N8N_DB" ]]; then
        print_warning "Chưa có n8n instance nào"
        show_footer
        pause
        return
    fi

    printf "%-5s %-35s %-25s %-10s %-10s\n" "STT" "DOMAIN" "CONTAINER" "PORT" "STATUS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local count=0
    while IFS='|' read -r domain instance_name container_name port data_dir compose_dir created_date; do
        ((count++))

        # Check container status
        local status="STOPPED"
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            status="${GREEN}RUNNING${NC}"
        else
            status="${RED}STOPPED${NC}"
        fi

        printf "%-5s %-35s %-25s %-10s " "$count" "$domain" "$container_name" "$port"
        echo -e "$status"
    done < "$N8N_DB"

    echo ""
    print_info "Tổng số instances: $count"
    show_footer
    pause
}

# Remove n8n instance
remove_n8n_instance() {
    show_header
    echo -e "${CYAN}XÓA N8N INSTANCE${NC}"
    echo ""

    ensure_n8n_db

    if [[ ! -s "$N8N_DB" ]]; then
        print_warning "Chưa có n8n instance nào"
        pause
        return
    fi

    # List instances
    echo "Danh sách n8n instances:"
    echo ""
    local count=0
    while IFS='|' read -r domain _ _ _ _ _ _; do
        ((count++))
        echo "  $count. $domain"
    done < "$N8N_DB"
    echo ""

    read -p "Nhập tên miền cần xóa: " domain

    if ! n8n_instance_exists "$domain"; then
        print_error "n8n instance không tồn tại: $domain"
        pause
        return 1
    fi

    # Get instance info
    local instance_info=$(get_n8n_instance_info "$domain")
    IFS='|' read -r _ instance_name container_name port data_dir compose_dir _ <<< "$instance_info"

    echo ""
    print_warning "⚠️  CẢNH BÁO: Hành động này sẽ xóa:"
    echo "  • Docker container: $container_name"
    echo "  • Nginx vhost: $domain"
    echo "  • Data directory: $data_dir (workflows, credentials, settings)"
    echo ""

    if ! confirm_action "Bạn có chắc chắn muốn xóa?" "n"; then
        print_warning "Đã hủy"
        pause
        return 1
    fi

    print_info "Đang xóa n8n instance: $domain"

    # Stop and remove container
    print_info "Dừng và xóa Docker container..."
    if [[ -d "$compose_dir" ]]; then
        cd "$compose_dir"
        docker compose down -v 2>/dev/null
    else
        docker stop "$container_name" 2>/dev/null
        docker rm "$container_name" 2>/dev/null
    fi

    # Remove Nginx vhost
    print_info "Xóa Nginx vhost..."
    local vhost_file="${NGINX_SITES_AVAILABLE}/${domain}.conf"
    if [[ -f "$vhost_file" ]]; then
        rm -f "$vhost_file"
        rm -f "${NGINX_SITES_ENABLED}/${domain}.conf"
        systemctl reload nginx 2>/dev/null
    fi

    # Remove SSL certificates
    if [[ -d "/etc/letsencrypt/live/${domain}" ]]; then
        print_info "Xóa SSL certificates..."
        certbot delete --cert-name "$domain" --non-interactive 2>/dev/null
    fi

    # Ask about data directory
    echo ""
    if confirm_action "Xóa data directory (workflows, credentials)?" "n"; then
        rm -rf "$data_dir"
        print_info "Đã xóa data directory"
    else
        print_info "Giữ lại data directory: $data_dir"
    fi

    # Remove compose directory
    rm -rf "$compose_dir"

    # Remove from database
    sed -i "/^${domain}|/d" "$N8N_DB"

    print_success "Đã xóa n8n instance: $domain"
    log_message "INFO" "Removed n8n instance: $domain"
    pause
    return 0
}

# Start n8n instance
start_n8n_instance() {
    local domain=$1

    if ! n8n_instance_exists "$domain"; then
        print_error "n8n instance không tồn tại: $domain"
        return 1
    fi

    local instance_info=$(get_n8n_instance_info "$domain")
    IFS='|' read -r _ _ container_name _ _ compose_dir _ <<< "$instance_info"

    print_info "Đang khởi động n8n: $domain"

    if [[ -d "$compose_dir" ]]; then
        cd "$compose_dir"
        docker compose start
    else
        docker start "$container_name"
    fi

    if [[ $? -eq 0 ]]; then
        print_success "Đã khởi động n8n: $domain"
        return 0
    else
        print_error "Không thể khởi động n8n: $domain"
        return 1
    fi
}

# Stop n8n instance
stop_n8n_instance() {
    local domain=$1

    if ! n8n_instance_exists "$domain"; then
        print_error "n8n instance không tồn tại: $domain"
        return 1
    fi

    local instance_info=$(get_n8n_instance_info "$domain")
    IFS='|' read -r _ _ container_name _ _ compose_dir _ <<< "$instance_info"

    print_info "Đang dừng n8n: $domain"

    if [[ -d "$compose_dir" ]]; then
        cd "$compose_dir"
        docker compose stop
    else
        docker stop "$container_name"
    fi

    if [[ $? -eq 0 ]]; then
        print_success "Đã dừng n8n: $domain"
        return 0
    else
        print_error "Không thể dừng n8n: $domain"
        return 1
    fi
}

# Restart n8n instance
restart_n8n_instance() {
    local domain=$1

    if ! n8n_instance_exists "$domain"; then
        print_error "n8n instance không tồn tại: $domain"
        return 1
    fi

    local instance_info=$(get_n8n_instance_info "$domain")
    IFS='|' read -r _ _ container_name _ _ compose_dir _ <<< "$instance_info"

    print_info "Đang restart n8n: $domain"

    if [[ -d "$compose_dir" ]]; then
        cd "$compose_dir"
        docker compose restart
    else
        docker restart "$container_name"
    fi

    if [[ $? -eq 0 ]]; then
        print_success "Đã restart n8n: $domain"
        return 0
    else
        print_error "Không thể restart n8n: $domain"
        return 1
    fi
}

# View n8n logs
view_n8n_logs() {
    local domain=$1

    if ! n8n_instance_exists "$domain"; then
        print_error "n8n instance không tồn tại: $domain"
        return 1
    fi

    local instance_info=$(get_n8n_instance_info "$domain")
    IFS='|' read -r _ _ container_name _ _ compose_dir _ <<< "$instance_info"

    print_info "Logs của n8n: $domain (Ctrl+C để thoát)"
    echo ""

    if [[ -d "$compose_dir" ]]; then
        cd "$compose_dir"
        docker compose logs -f --tail=100
    else
        docker logs -f --tail=100 "$container_name"
    fi
}

# Backup n8n instance
backup_n8n_instance() {
    local domain=$1

    if ! n8n_instance_exists "$domain"; then
        print_error "n8n instance không tồn tại: $domain"
        return 1
    fi

    local instance_info=$(get_n8n_instance_info "$domain")
    IFS='|' read -r _ instance_name _ _ data_dir _ _ <<< "$instance_info"

    local backup_dir="${BACKUP_DIR}/n8n/${instance_name}_$(date +%Y%m%d_%H%M%S)"
    ensure_directory "$backup_dir"

    print_info "Đang backup n8n: $domain"

    # Backup data directory
    tar -czf "${backup_dir}/n8n_data.tar.gz" -C "$(dirname "$data_dir")" "$(basename "$data_dir")" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        local backup_size=$(du -sh "$backup_dir" | cut -f1)
        print_success "Backup hoàn tất!"
        print_info "Thư mục backup: $backup_dir"
        print_info "Kích thước: $backup_size"
        log_message "INFO" "Backed up n8n instance: $domain"
        echo "$backup_dir"
        return 0
    else
        print_error "Backup thất bại"
        return 1
    fi
}

# Update n8n instance
update_n8n_instance() {
    local domain=$1

    if ! n8n_instance_exists "$domain"; then
        print_error "n8n instance không tồn tại: $domain"
        return 1
    fi

    local instance_info=$(get_n8n_instance_info "$domain")
    IFS='|' read -r _ _ container_name _ _ compose_dir _ <<< "$instance_info"

    print_info "Đang update n8n: $domain"
    echo ""
    print_warning "Sẽ pull image mới nhất và restart container"

    if ! confirm_action "Tiếp tục?" "y"; then
        return 1
    fi

    # Backup first
    print_info "Backup trước khi update..."
    backup_n8n_instance "$domain" >/dev/null

    # Pull latest image and restart
    if [[ -d "$compose_dir" ]]; then
        cd "$compose_dir"
        docker compose pull
        docker compose up -d
    else
        docker pull n8nio/n8n:latest
        docker stop "$container_name"
        docker rm "$container_name"
        # Recreate container (would need saved config)
    fi

    if [[ $? -eq 0 ]]; then
        print_success "Đã update n8n: $domain"
        log_message "INFO" "Updated n8n instance: $domain"
        return 0
    else
        print_error "Không thể update n8n: $domain"
        return 1
    fi
}
