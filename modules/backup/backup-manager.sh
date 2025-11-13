#!/bin/bash
# Backup Manager Module
# Quản lý backup và restore cho WordPress sites

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"
source "${MODULES_DIR}/database/database-manager.sh"

# Backup a site (files + database)
backup_site() {
    local domain=$1
    local backup_name=$2

    if [[ -z "$backup_name" ]]; then
        backup_name="${domain}_$(date +%Y%m%d_%H%M%S)"
    fi

    # Get site info
    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name site_user db_name db_user site_root _ <<< "$site_info"

    local backup_dir="${BACKUP_DIR}/${backup_name}"
    ensure_directory "$backup_dir"

    print_info "Đang backup site: $domain"

    # Backup database
    print_info "Backup database..."
    local db_backup=$(backup_database "$db_name" "${backup_dir}/${db_name}.sql")
    if [[ $? -ne 0 ]]; then
        print_error "Không thể backup database"
        return 1
    fi

    # Backup files
    print_info "Backup files..."
    tar -czf "${backup_dir}/files.tar.gz" -C "$(dirname "$site_root")" "$(basename "$site_root")" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        print_success "Đã backup files"
    else
        print_error "Không thể backup files"
        return 1
    fi

    # Save metadata
    cat > "${backup_dir}/metadata.txt" <<EOF
Backup Information
==================
Domain: $domain
Site Name: $site_name
Site User: $site_user
Database: $db_name
DB User: $db_user
Site Root: $site_root
Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
EOF

    # Calculate backup size
    local backup_size=$(du -sh "$backup_dir" | cut -f1)

    print_success "Backup hoàn tất!"
    print_info "Thư mục backup: $backup_dir"
    print_info "Kích thước: $backup_size"

    log_message "INFO" "Backed up site: $domain to $backup_dir"

    echo "$backup_dir"
    return 0
}

# Restore a site
restore_site() {
    local backup_dir=$1

    if [[ ! -d "$backup_dir" ]]; then
        print_error "Thư mục backup không tồn tại: $backup_dir"
        return 1
    fi

    if [[ ! -f "${backup_dir}/metadata.txt" ]]; then
        print_error "File metadata không tồn tại"
        return 1
    fi

    # Read metadata
    local domain=$(grep "^Domain:" "${backup_dir}/metadata.txt" | cut -d' ' -f2)
    local site_name=$(grep "^Site Name:" "${backup_dir}/metadata.txt" | cut -d' ' -f3)
    local db_name=$(grep "^Database:" "${backup_dir}/metadata.txt" | cut -d' ' -f2)
    local site_root=$(grep "^Site Root:" "${backup_dir}/metadata.txt" | cut -d' ' -f3)

    print_info "Đang restore site: $domain"
    echo ""
    print_warning "Cảnh báo: Hành động này sẽ ghi đè lên dữ liệu hiện tại (nếu có)"
    echo ""

    if ! confirm_action "Bạn có chắc chắn muốn restore?" "n"; then
        print_warning "Đã hủy"
        return 1
    fi

    # Restore database
    print_info "Restore database..."
    local db_backup_file=$(find "$backup_dir" -name "*.sql.gz" -o -name "*.sql" | head -n 1)
    if [[ -f "$db_backup_file" ]]; then
        restore_database "$db_name" "$db_backup_file"
    else
        print_error "Không tìm thấy file backup database"
        return 1
    fi

    # Restore files
    print_info "Restore files..."
    if [[ -f "${backup_dir}/files.tar.gz" ]]; then
        # Backup current files first
        if [[ -d "$site_root" ]]; then
            print_info "Backup dữ liệu hiện tại trước khi restore..."
            mv "$site_root" "${site_root}.old.$(date +%Y%m%d_%H%M%S)"
        fi

        # Extract backup
        tar -xzf "${backup_dir}/files.tar.gz" -C "$(dirname "$site_root")"

        if [[ $? -eq 0 ]]; then
            print_success "Đã restore files"
        else
            print_error "Không thể restore files"
            return 1
        fi
    else
        print_error "Không tìm thấy file backup files"
        return 1
    fi

    print_success "Restore hoàn tất!"
    log_message "INFO" "Restored site: $domain from $backup_dir"

    return 0
}

# List backups
list_backups() {
    show_header
    echo -e "${CYAN}DANH SÁCH BACKUPS${NC}"
    echo ""

    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_warning "Chưa có backup nào"
        show_footer
        pause
        return
    fi

    local count=0
    printf "%-5s %-40s %-20s %-10s\n" "STT" "BACKUP NAME" "DATE" "SIZE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for backup in "${BACKUP_DIR}"/*; do
        if [[ -d "$backup" ]] && [[ -f "${backup}/metadata.txt" ]]; then
            ((count++))
            local backup_name=$(basename "$backup")
            local backup_date=$(grep "^Backup Date:" "${backup}/metadata.txt" | cut -d' ' -f3-)
            local backup_size=$(du -sh "$backup" | cut -f1)
            printf "%-5s %-40s %-20s %-10s\n" "$count" "$backup_name" "$backup_date" "$backup_size"
        fi
    done

    if [[ $count -eq 0 ]]; then
        print_warning "Chưa có backup nào"
    else
        echo ""
        print_info "Tổng số backups: $count"
    fi

    show_footer
    pause
}

# Delete old backups
cleanup_old_backups() {
    local days=${1:-$BACKUP_RETENTION_DAYS}

    print_info "Đang xóa backups cũ hơn $days ngày..."

    local count=0
    find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +$days ! -name "wordpress" | while read -r backup; do
        if [[ -f "${backup}/metadata.txt" ]]; then
            rm -rf "$backup"
            ((count++))
            print_info "Đã xóa: $(basename "$backup")"
        fi
    done

    if [[ $count -eq 0 ]]; then
        print_info "Không có backup nào cần xóa"
    else
        print_success "Đã xóa $count backups"
    fi

    log_message "INFO" "Cleaned up old backups (older than $days days)"
}

# Auto backup all sites
auto_backup_all() {
    show_header
    echo -e "${CYAN}TỰ ĐỘNG BACKUP TẤT CẢ SITES${NC}"
    echo ""

    source "${MODULES_DIR}/site/site-manager.sh"

    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào để backup"
        show_footer
        pause
        return
    fi

    local total=0
    local success=0
    local failed=0

    while IFS='|' read -r domain site_name _ _ _ _ _; do
        ((total++))
        print_info "[$total] Backup site: $domain"

        if backup_site "$domain"; then
            ((success++))
        else
            ((failed++))
        fi

        echo ""
    done < "$SITES_DB"

    echo ""
    print_info "Tổng kết:"
    echo "  - Tổng số sites: $total"
    echo "  - Thành công: $success"
    echo "  - Thất bại: $failed"

    log_message "INFO" "Auto backup all sites: $success/$total successful"

    show_footer
    pause
}

# Setup cron for auto backup
setup_auto_backup_cron() {
    local schedule=$1  # daily, weekly, monthly

    case "$schedule" in
        "daily")
            local cron_time="0 2 * * *"  # 2 AM daily
            ;;
        "weekly")
            local cron_time="0 2 * * 0"  # 2 AM Sunday
            ;;
        "monthly")
            local cron_time="0 2 1 * *"  # 2 AM first day of month
            ;;
        *)
            print_error "Schedule không hợp lệ: $schedule"
            return 1
            ;;
    esac

    local cron_job="${cron_time} ${SCRIPT_DIR}/wpminhminhscript backup-all-auto"

    # Add to crontab
    (crontab -l 2>/dev/null | grep -v "wpminhminhscript backup-all-auto"; echo "$cron_job") | crontab -

    print_success "Đã cài đặt auto backup: $schedule"
    log_message "INFO" "Setup auto backup cron: $schedule"
}

# Remove auto backup cron
remove_auto_backup_cron() {
    crontab -l 2>/dev/null | grep -v "wpminhminhscript backup-all-auto" | crontab -
    print_success "Đã xóa auto backup cron"
    log_message "INFO" "Removed auto backup cron"
}

# Download backup (for remote backup)
download_backup() {
    local backup_name=$1
    local remote_path=$2

    print_info "Chức năng download backup từ remote sẽ được bổ sung sau"
    print_info "Bạn có thể tích hợp với rclone, rsync, hoặc các cloud storage"
}

# Upload backup to remote
upload_backup() {
    local backup_dir=$1
    local remote_path=$2

    print_info "Chức năng upload backup lên remote sẽ được bổ sung sau"
    print_info "Bạn có thể tích hợp với rclone, rsync, hoặc các cloud storage"
}
