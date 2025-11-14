#!/bin/bash
# Migration Manager Module
# Quản lý chuyển VPS và WordPress sites giữa các servers

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"
source "${MODULES_DIR}/site/site-manager.sh"
source "${MODULES_DIR}/database/database-manager.sh"
source "${MODULES_DIR}/backup/backup-manager.sh"

# Check if rsync is installed
check_rsync() {
    if ! command -v rsync &> /dev/null; then
        print_warning "rsync chưa được cài đặt"
        read -p "Cài đặt rsync ngay? (y/n): " install_rsync
        if [[ "$install_rsync" == "y" ]]; then
            print_info "Đang cài đặt rsync..."
            apt-get update -qq && apt-get install -y rsync
            if [[ $? -eq 0 ]]; then
                print_success "Đã cài đặt rsync"
                return 0
            else
                print_error "Không thể cài đặt rsync"
                return 1
            fi
        else
            return 1
        fi
    fi
    return 0
}

# Validate IP address
validate_ip() {
    local ip=$1

    # Check IPv4
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi

    # Check IPv6
    if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$ ]]; then
        return 0
    fi

    return 1
}

# Test SSH connection
test_ssh_connection() {
    local host=$1
    local port=$2
    local user=${3:-root}

    print_info "Đang kiểm tra kết nối SSH đến ${user}@${host}:${port}..."

    if ssh -o ConnectTimeout=10 -o BatchMode=yes -p "$port" "${user}@${host}" "echo connected" &>/dev/null; then
        print_success "Kết nối SSH thành công"
        return 0
    else
        print_warning "Không thể kết nối SSH bằng key"
        print_info "Bạn cần thiết lập SSH key authentication hoặc nhập password khi thực hiện transfer"
        return 1
    fi
}

# Transfer full VPS to new server
transfer_full_vps() {
    show_header
    echo -e "${CYAN}CHUYỂN TOÀN BỘ VPS${NC}"
    echo ""

    print_warning "⚠️  CẢNH BÁO QUAN TRỌNG:"
    echo "  • Tính năng này sẽ rsync TOÀN BỘ hệ thống sang VPS mới"
    echo "  • VPS mới phải cùng phân phối Linux (Ubuntu/Debian)"
    echo "  • VPS mới phải đã cài rsync (apt-get install rsync)"
    echo "  • Khuyến nghị backup VPS đích trước khi thực hiện"
    echo "  • Sau khi transfer xong, cần chạy script hoàn tất trên VPS mới"
    echo ""

    if ! confirm_action "Bạn có chắc chắn muốn tiếp tục?" "n"; then
        print_warning "Đã hủy"
        return 1
    fi

    # Check rsync
    if ! check_rsync; then
        print_error "Cần cài đặt rsync để tiếp tục"
        return 1
    fi

    echo ""
    read -p "Nhập IP VPS đích: " target_ip
    if ! validate_ip "$target_ip"; then
        print_error "IP không hợp lệ"
        return 1
    fi

    read -p "Nhập SSH port VPS đích [mặc định: 22]: " target_port
    target_port=${target_port:-22}

    read -p "Nhập SSH user VPS đích [mặc định: root]: " target_user
    target_user=${target_user:-root}

    # Test connection
    test_ssh_connection "$target_ip" "$target_port" "$target_user"

    echo ""
    print_info "Chuẩn bị transfer toàn bộ VPS..."
    print_info "Từ: $(hostname) ($(hostname -I | awk '{print $1}'))"
    print_info "Đến: ${target_user}@${target_ip}:${target_port}"
    echo ""

    if ! confirm_action "Xác nhận bắt đầu transfer?" "n"; then
        print_warning "Đã hủy"
        return 1
    fi

    print_info "Đang transfer hệ thống (có thể mất nhiều thời gian)..."
    echo ""

    # Rsync full system
    rsync -avpogtStlHz \
        -e "ssh -p ${target_port}" \
        --numeric-ids \
        --exclude=/proc/* \
        --exclude=/sys/* \
        --exclude=/dev/* \
        --exclude=/tmp/* \
        --exclude=/mnt/* \
        --exclude=/boot/grub/* \
        --exclude=/etc/fstab \
        --exclude=/etc/network/* \
        --exclude=/etc/netplan/* \
        --exclude=/root/.ssh/authorized_keys \
        --progress \
        --stats \
        / "${target_user}@${target_ip}:/"

    if [[ $? -eq 0 ]]; then
        print_success "Transfer hoàn tất!"
        echo ""
        print_info "BƯỚC TIẾP THEO:"
        echo "  1. Truy cập VPS mới qua SSH"
        echo "  2. Kiểm tra dịch vụ: systemctl status nginx php*-fpm mariadb"
        echo "  3. Restart các dịch vụ nếu cần: systemctl restart nginx"
        echo "  4. Trỏ DNS về IP VPS mới"
        echo "  5. Kiểm tra tất cả websites hoạt động"
        log_message "INFO" "Transferred full VPS to ${target_ip}"
        return 0
    else
        print_error "Transfer thất bại"
        return 1
    fi
}

# Prepare site for export (trên VPS nguồn)
prepare_site_export() {
    local domain=$1

    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name site_user db_name db_user site_root _ <<< "$site_info"

    local export_dir="${BACKUP_DIR}/migration/${domain}_export_$(date +%Y%m%d_%H%M%S)"
    ensure_directory "$export_dir"

    print_info "Đang chuẩn bị export site: $domain"

    # Export database
    print_info "Export database..."
    backup_database "$db_name" "${export_dir}/database.sql" >/dev/null
    if [[ ! -f "${export_dir}/database.sql.gz" ]] && [[ ! -f "${export_dir}/database.sql" ]]; then
        print_error "Không thể export database"
        return 1
    fi

    # Create tarball of site files
    print_info "Đang nén files..."
    tar -czf "${export_dir}/files.tar.gz" -C "$(dirname "$site_root")" "$(basename "$site_root")" 2>/dev/null

    # Save site metadata
    cat > "${export_dir}/site_metadata.conf" <<EOF
DOMAIN=$domain
SITE_NAME=$site_name
SITE_USER=$site_user
DB_NAME=$db_name
DB_USER=$db_user
SITE_ROOT=$site_root
EXPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
SCRIPT_VERSION=minhminhscript-1.0
EOF

    print_success "Đã chuẩn bị export tại: $export_dir"
    echo "$export_dir"
    return 0
}

# Transfer single site to another VPS
transfer_single_site() {
    show_header
    echo -e "${CYAN}CHUYỂN WORDPRESS SITE${NC}"
    echo ""

    # List sites
    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào"
        pause
        return 1
    fi

    echo "Danh sách sites:"
    echo ""
    local count=0
    while IFS='|' read -r domain site_name _ _ _ _ _; do
        ((count++))
        echo "  $count. $domain"
    done < "$SITES_DB"
    echo ""

    read -p "Nhập tên miền cần chuyển: " domain

    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        pause
        return 1
    fi

    # Check rsync
    if ! check_rsync; then
        print_error "Cần cài đặt rsync để tiếp tục"
        pause
        return 1
    fi

    echo ""
    read -p "Nhập IP VPS đích: " target_ip
    if ! validate_ip "$target_ip"; then
        print_error "IP không hợp lệ"
        pause
        return 1
    fi

    read -p "Nhập SSH port VPS đích [mặc định: 22]: " target_port
    target_port=${target_port:-22}

    read -p "Nhập SSH user VPS đích [mặc định: root]: " target_user
    target_user=${target_user:-root}

    read -p "Nhập đường dẫn thư mục đích trên VPS mới [mặc định: /tmp/site_migration]: " target_path
    target_path=${target_path:-/tmp/site_migration}

    # Test connection
    test_ssh_connection "$target_ip" "$target_port" "$target_user"

    echo ""
    print_info "Chuẩn bị chuyển site: $domain"

    # Prepare export
    local export_dir=$(prepare_site_export "$domain")
    if [[ $? -ne 0 ]]; then
        print_error "Không thể chuẩn bị export"
        pause
        return 1
    fi

    echo ""
    print_info "Đang transfer site qua rsync..."

    # Create target directory
    ssh -p "$target_port" "${target_user}@${target_ip}" "mkdir -p ${target_path}" 2>/dev/null

    # Rsync export directory
    rsync -avz \
        -e "ssh -p ${target_port}" \
        --progress \
        "${export_dir}/" \
        "${target_user}@${target_ip}:${target_path}/"

    if [[ $? -eq 0 ]]; then
        print_success "Transfer hoàn tất!"
        echo ""
        print_info "BƯỚC TIẾP THEO trên VPS đích:"
        echo "  1. Cài đặt minhminhscript nếu chưa có"
        echo "  2. Import site bằng lệnh:"
        echo "     wpminhminhscript import-site ${target_path}"
        echo ""
        echo "  Hoặc thủ công:"
        echo "     - Giải nén: tar -xzf ${target_path}/files.tar.gz"
        echo "     - Import DB: zcat ${target_path}/database.sql.gz | mysql -u user -p dbname"
        echo "     - Tạo vhost, pool PHP-FPM"
        echo ""
        log_message "INFO" "Transferred site $domain to ${target_ip}:${target_path}"
        pause
        return 0
    else
        print_error "Transfer thất bại"
        pause
        return 1
    fi
}

# Import site from migration package
import_site_from_package() {
    local package_dir=$1

    show_header
    echo -e "${CYAN}IMPORT WORDPRESS SITE${NC}"
    echo ""

    if [[ -z "$package_dir" ]]; then
        read -p "Nhập đường dẫn thư mục migration package: " package_dir
    fi

    if [[ ! -d "$package_dir" ]]; then
        print_error "Thư mục không tồn tại: $package_dir"
        pause
        return 1
    fi

    if [[ ! -f "${package_dir}/site_metadata.conf" ]]; then
        print_error "Không tìm thấy file metadata"
        pause
        return 1
    fi

    # Load metadata
    source "${package_dir}/site_metadata.conf"

    print_info "Thông tin site:"
    echo "  Domain: $DOMAIN"
    echo "  Site Name: $SITE_NAME"
    echo "  Export Date: $EXPORT_DATE"
    echo ""

    if ! confirm_action "Import site này?" "y"; then
        print_warning "Đã hủy"
        pause
        return 1
    fi

    # Check if site already exists
    if site_exists "$DOMAIN"; then
        print_warning "Site $DOMAIN đã tồn tại"
        if ! confirm_action "Ghi đè site hiện tại?" "n"; then
            print_warning "Đã hủy"
            pause
            return 1
        fi
        # Backup existing site first
        print_info "Backup site hiện tại trước..."
        backup_site "$DOMAIN" >/dev/null
    fi

    echo ""
    read -p "Nhập tên miền mới [Enter = giữ nguyên: $DOMAIN]: " new_domain
    new_domain=${new_domain:-$DOMAIN}

    read -p "Nhập site name mới [Enter = auto từ domain]: " new_site_name
    if [[ -z "$new_site_name" ]]; then
        new_site_name=$(echo "$new_domain" | sed 's/[^a-zA-Z0-9]/_/g')
    fi

    read -p "Nhập database name [Enter = ${new_site_name}_db]: " new_db_name
    new_db_name=${new_db_name:-${new_site_name}_db}

    read -p "Nhập database user [Enter = ${new_site_name}_user]: " new_db_user
    new_db_user=${new_db_user:-${new_site_name}_user}

    # Generate database password
    local new_db_pass=$(generate_password 16)

    local new_site_user=$(echo "$new_site_name" | cut -c1-32)
    local new_site_root="/var/www/${new_site_name}"

    echo ""
    print_info "Bắt đầu import site..."

    # Create database
    print_info "Tạo database..."
    create_database "$new_db_name" "$new_db_user" "$new_db_pass"

    # Import database
    print_info "Import database..."
    local db_file=$(find "$package_dir" -name "*.sql.gz" -o -name "*.sql" | head -n 1)
    if [[ -f "$db_file" ]]; then
        restore_database "$new_db_name" "$db_file"
    else
        print_error "Không tìm thấy file database"
        pause
        return 1
    fi

    # Create system user
    print_info "Tạo system user..."
    if ! id "$new_site_user" &>/dev/null; then
        useradd -m -s /bin/bash -d "/home/${new_site_user}" "$new_site_user"
    fi

    # Add www-data to site user group
    usermod -a -G "$new_site_user" www-data

    # Extract files
    print_info "Giải nén files..."
    ensure_directory "$new_site_root"
    tar -xzf "${package_dir}/files.tar.gz" -C "/tmp/" 2>/dev/null

    # Move files to site root
    local extracted_dir=$(find /tmp -maxdepth 1 -type d -name "$(basename "$SITE_ROOT")" | head -n 1)
    if [[ -d "$extracted_dir" ]]; then
        rsync -a "${extracted_dir}/" "${new_site_root}/"
        rm -rf "$extracted_dir"
    else
        print_error "Không thể giải nén files"
        pause
        return 1
    fi

    # Set ownership
    chown -R "${new_site_user}:${new_site_user}" "$new_site_root"

    # Update wp-config.php
    if [[ -f "${new_site_root}/wp-config.php" ]]; then
        print_info "Cập nhật wp-config.php..."
        sed -i "s/define( *'DB_NAME'.*/define('DB_NAME', '${new_db_name}');/" "${new_site_root}/wp-config.php"
        sed -i "s/define( *'DB_USER'.*/define('DB_USER', '${new_db_user}');/" "${new_site_root}/wp-config.php"
        sed -i "s/define( *'DB_PASSWORD'.*/define('DB_PASSWORD', '${new_db_pass}');/" "${new_site_root}/wp-config.php"
    fi

    # Create PHP-FPM pool
    print_info "Tạo PHP-FPM pool..."
    source "${MODULES_DIR}/phpfpm/phpfpm-manager.sh"
    create_phpfpm_pool "$new_site_name" "$new_site_user" "$new_site_root"

    # Create Nginx vhost
    print_info "Tạo Nginx vhost..."
    source "${MODULES_DIR}/nginx/nginx-manager.sh"
    create_nginx_vhost "$new_domain" "$new_site_name" "$new_site_root"

    # Save site info
    echo "${new_domain}|${new_site_name}|${new_site_user}|${new_db_name}|${new_db_user}|${new_site_root}|$(date '+%Y-%m-%d %H:%M:%S')" >> "$SITES_DB"

    # Reload services
    systemctl reload php*-fpm 2>/dev/null
    systemctl reload nginx 2>/dev/null

    print_success "Import site hoàn tất!"
    echo ""
    print_info "Thông tin site:"
    echo "  Domain: $new_domain"
    echo "  Site Root: $new_site_root"
    echo "  Database: $new_db_name"
    echo "  DB User: $new_db_user"
    echo "  DB Pass: $new_db_pass"
    echo ""
    print_warning "Lưu ý: Hãy lưu lại thông tin database!"
    echo ""

    log_message "INFO" "Imported site $new_domain from $package_dir"
    pause
    return 0
}

# Transfer all sites
transfer_all_sites() {
    show_header
    echo -e "${CYAN}CHUYỂN TẤT CẢ SITES${NC}"
    echo ""

    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào"
        pause
        return 1
    fi

    local total_sites=$(wc -l < "$SITES_DB")
    print_info "Tổng số sites: $total_sites"
    echo ""

    # Check rsync
    if ! check_rsync; then
        print_error "Cần cài đặt rsync để tiếp tục"
        pause
        return 1
    fi

    read -p "Nhập IP VPS đích: " target_ip
    if ! validate_ip "$target_ip"; then
        print_error "IP không hợp lệ"
        pause
        return 1
    fi

    read -p "Nhập SSH port VPS đích [mặc định: 22]: " target_port
    target_port=${target_port:-22}

    read -p "Nhập SSH user VPS đích [mặc định: root]: " target_user
    target_user=${target_user:-root}

    read -p "Nhập thư mục đích [mặc định: /tmp/sites_migration]: " target_base
    target_base=${target_base:-/tmp/sites_migration}

    # Test connection
    test_ssh_connection "$target_ip" "$target_port" "$target_user"

    echo ""
    print_info "Bắt đầu chuyển $total_sites sites..."
    echo ""

    local count=0
    local success=0
    local failed=0

    while IFS='|' read -r domain site_name _ _ _ _ _; do
        ((count++))
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_info "[$count/$total_sites] Chuyển site: $domain"

        # Prepare export
        local export_dir=$(prepare_site_export "$domain")
        if [[ $? -ne 0 ]]; then
            print_error "Không thể export $domain"
            ((failed++))
            continue
        fi

        # Create target directory
        local site_target="${target_base}/${domain}_$(date +%Y%m%d)"
        ssh -p "$target_port" "${target_user}@${target_ip}" "mkdir -p ${site_target}" 2>/dev/null

        # Transfer
        print_info "Đang transfer qua rsync..."
        rsync -avz \
            -e "ssh -p ${target_port}" \
            "${export_dir}/" \
            "${target_user}@${target_ip}:${site_target}/" >/dev/null 2>&1

        if [[ $? -eq 0 ]]; then
            print_success "✓ Đã chuyển $domain"
            ((success++))
        else
            print_error "✗ Lỗi khi chuyển $domain"
            ((failed++))
        fi

        echo ""
    done < "$SITES_DB"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Tổng kết:"
    echo "  - Tổng số sites: $total_sites"
    echo "  - Thành công: $success"
    echo "  - Thất bại: $failed"
    echo ""
    print_info "Tất cả sites đã được chuyển đến: ${target_user}@${target_ip}:${target_base}/"
    echo ""
    print_info "BƯỚC TIẾP THEO trên VPS đích:"
    echo "  • Cài đặt minhminhscript"
    echo "  • Import từng site: wpminhminhscript import-site <path>"
    echo ""

    log_message "INFO" "Transferred all sites to ${target_ip}:${target_base}"
    pause
    return 0
}

# Generate random password
generate_password() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "$length"
}
