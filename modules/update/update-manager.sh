#!/bin/bash
# Update Manager Module
# Quản lý cập nhật tự động cho WP Minhminh Script

# GitHub configuration
GITHUB_RAW_URL="https://raw.githubusercontent.com/qminhhp/minhminhscript"
GITHUB_API_URL="https://api.github.com/repos/qminhhp/minhminhscript"
DEFAULT_BRANCH="main"
UPDATE_CHECK_FILE="/var/log/wpminhminhscript/last_update_check"

# Get current version
get_current_version() {
    if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
        cat "${SCRIPT_DIR}/VERSION"
    else
        echo "0.0.0"
    fi
}

# Get latest version from GitHub
get_latest_version() {
    local branch="${1:-$DEFAULT_BRANCH}"
    local version

    version=$(curl -s "${GITHUB_RAW_URL}/${branch}/VERSION" 2>/dev/null)

    if [[ -n "$version" ]] && [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$version"
    else
        echo ""
    fi
}

# Compare versions (return 0 if v2 > v1, 1 otherwise)
version_gt() {
    local v1=$1
    local v2=$2

    # Convert versions to comparable numbers
    local v1_major=$(echo $v1 | cut -d. -f1)
    local v1_minor=$(echo $v1 | cut -d. -f2)
    local v1_patch=$(echo $v1 | cut -d. -f3)

    local v2_major=$(echo $v2 | cut -d. -f1)
    local v2_minor=$(echo $v2 | cut -d. -f2)
    local v2_patch=$(echo $v2 | cut -d. -f3)

    if [[ $v2_major -gt $v1_major ]]; then
        return 0
    elif [[ $v2_major -eq $v1_major ]]; then
        if [[ $v2_minor -gt $v1_minor ]]; then
            return 0
        elif [[ $v2_minor -eq $v1_minor ]]; then
            if [[ $v2_patch -gt $v1_patch ]]; then
                return 0
            fi
        fi
    fi

    return 1
}

# Check for updates
check_for_updates() {
    local current_version=$(get_current_version)
    local latest_version=$(get_latest_version)
    local quiet_mode=${1:-false}

    if [[ -z "$latest_version" ]]; then
        if [[ "$quiet_mode" == "false" ]]; then
            log_error "Không thể kiểm tra phiên bản mới (lỗi kết nối GitHub)"
        fi
        return 1
    fi

    # Save last check time
    date +%s > "$UPDATE_CHECK_FILE"

    if version_gt "$current_version" "$latest_version"; then
        if [[ "$quiet_mode" == "false" ]]; then
            echo -e "${GREEN}┌─────────────────────────────────────────────┐${NC}"
            echo -e "${GREEN}│  🎉 CÓ PHIÊN BẢN MỚI!                       │${NC}"
            echo -e "${GREEN}├─────────────────────────────────────────────┤${NC}"
            echo -e "${GREEN}│${NC}  Phiên bản hiện tại: ${YELLOW}v${current_version}${NC}"
            echo -e "${GREEN}│${NC}  Phiên bản mới nhất: ${GREEN}v${latest_version}${NC}"
            echo -e "${GREEN}└─────────────────────────────────────────────┘${NC}"
            echo ""
        fi
        return 0
    else
        if [[ "$quiet_mode" == "false" ]]; then
            log_success "Bạn đang sử dụng phiên bản mới nhất (v${current_version})"
        fi
        return 1
    fi
}

# Get changelog
get_changelog() {
    local current_version=$(get_current_version)
    local changelog

    changelog=$(curl -s "${GITHUB_RAW_URL}/${DEFAULT_BRANCH}/CHANGELOG.md" 2>/dev/null)

    if [[ -n "$changelog" ]]; then
        # Extract changes since current version
        echo "$changelog" | awk "/## \[${current_version}\]/,/## \[/" | head -n -1
    else
        echo "Không có thông tin changelog"
    fi
}

# Perform update
do_update() {
    local branch="${1:-$DEFAULT_BRANCH}"
    local backup_dir="/var/backups/wpminhminhscript/script_backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}  CẬP NHẬT WP MINHMINH SCRIPT${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""

    # Check for updates first
    local current_version=$(get_current_version)
    local latest_version=$(get_latest_version "$branch")

    if [[ -z "$latest_version" ]]; then
        log_error "Không thể kết nối đến GitHub để kiểm tra phiên bản"
        return 1
    fi

    log_info "Phiên bản hiện tại: v${current_version}"
    log_info "Phiên bản mới nhất: v${latest_version}"
    echo ""

    if ! version_gt "$current_version" "$latest_version"; then
        log_info "Bạn đang sử dụng phiên bản mới nhất"
        read -p "Bạn có muốn cài đặt lại? (y/n): " reinstall
        if [[ "$reinstall" != "y" ]] && [[ "$reinstall" != "Y" ]]; then
            return 0
        fi
    fi

    # Show changelog
    echo -e "${YELLOW}Thay đổi trong phiên bản mới:${NC}"
    echo "─────────────────────────────────────────"
    get_changelog | head -20
    echo "─────────────────────────────────────────"
    echo ""

    # Confirm update
    read -p "Bạn có muốn cập nhật? (y/n): " confirm
    if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
        log_info "Đã hủy cập nhật"
        return 0
    fi

    # Create backup
    log_info "Đang tạo backup..."
    mkdir -p "$backup_dir"

    local backup_file="${backup_dir}/wpminhminhscript_v${current_version}_${timestamp}.tar.gz"
    tar -czf "$backup_file" -C "$(dirname "$SCRIPT_DIR")" "$(basename "$SCRIPT_DIR")" 2>/dev/null

    if [[ -f "$backup_file" ]]; then
        log_success "Đã backup tại: $backup_file"
    else
        log_warning "Không thể tạo backup, nhưng tiếp tục cập nhật..."
    fi

    # Change to script directory
    cd "$SCRIPT_DIR" || {
        log_error "Không thể truy cập thư mục script"
        return 1
    }

    # Check if it's a git repository
    if [[ -d .git ]]; then
        log_info "Đang cập nhật qua Git..."

        # Stash any local changes
        git stash push -m "Auto-stash before update ${timestamp}" 2>/dev/null

        # Fetch latest changes
        if ! git fetch origin "$branch" 2>/dev/null; then
            log_error "Lỗi khi fetch từ GitHub"
            return 1
        fi

        # Checkout and pull
        if ! git checkout "$branch" 2>/dev/null; then
            log_error "Lỗi khi checkout branch $branch"
            return 1
        fi

        if ! git pull origin "$branch" 2>/dev/null; then
            log_error "Lỗi khi pull từ GitHub"
            return 1
        fi

    else
        log_info "Đang tải phiên bản mới..."

        # Download new version as tarball
        local temp_dir=$(mktemp -d)

        if ! curl -sL "${GITHUB_API_URL}/tarball/${branch}" -o "${temp_dir}/update.tar.gz"; then
            log_error "Lỗi khi tải bản cập nhật"
            rm -rf "$temp_dir"
            return 1
        fi

        # Extract
        tar -xzf "${temp_dir}/update.tar.gz" -C "$temp_dir"

        # Find extracted directory
        local extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "qminhhp-minhminhscript-*" | head -1)

        if [[ -z "$extracted_dir" ]]; then
            log_error "Lỗi khi giải nén bản cập nhật"
            rm -rf "$temp_dir"
            return 1
        fi

        # Copy files
        log_info "Đang cài đặt phiên bản mới..."
        cp -rf "${extracted_dir}"/* "$SCRIPT_DIR/"

        # Cleanup
        rm -rf "$temp_dir"
    fi

    # Set permissions
    chmod +x "${SCRIPT_DIR}/wpminhminhscript"

    # Verify update
    local new_version=$(get_current_version)

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ CẬP NHẬT THÀNH CÔNG!                   ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  Phiên bản cũ: ${YELLOW}v${current_version}${NC}"
    echo -e "${GREEN}║${NC}  Phiên bản mới: ${GREEN}v${new_version}${NC}"
    echo -e "${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  Backup: ${backup_file}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""

    log_info "Vui lòng khởi động lại script để áp dụng thay đổi"

    read -p "Khởi động lại ngay? (y/n): " restart
    if [[ "$restart" == "y" ]] || [[ "$restart" == "Y" ]]; then
        exec "$SCRIPT_DIR/wpminhminhscript"
    fi

    return 0
}

# Restore from backup
restore_from_backup() {
    local backup_dir="/var/backups/wpminhminhscript/script_backups"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Không tìm thấy thư mục backup"
        return 1
    fi

    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}  KHÔI PHỤC TỪ BACKUP${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""

    # List backups
    local backups=($(ls -t "$backup_dir"/*.tar.gz 2>/dev/null))

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_error "Không tìm thấy backup nào"
        return 1
    fi

    echo "Các bản backup có sẵn:"
    echo ""

    local i=1
    for backup in "${backups[@]}"; do
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d. -f1)
        echo "  $i. $(basename "$backup")"
        echo "     Kích thước: $size | Ngày tạo: $date"
        echo ""
        ((i++))
    done

    read -p "Chọn backup để khôi phục (1-${#backups[@]}) hoặc 0 để hủy: " choice

    if [[ "$choice" == "0" ]] || [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#backups[@]} ]]; then
        log_info "Đã hủy khôi phục"
        return 0
    fi

    local selected_backup="${backups[$((choice-1))]}"

    log_warning "CẢNH BÁO: Hành động này sẽ ghi đè lên phiên bản hiện tại!"
    read -p "Bạn có chắc chắn muốn khôi phục? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Đã hủy khôi phục"
        return 0
    fi

    # Create backup of current version first
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local current_version=$(get_current_version)
    local current_backup="${backup_dir}/before_restore_v${current_version}_${timestamp}.tar.gz"

    log_info "Đang backup phiên bản hiện tại..."
    tar -czf "$current_backup" -C "$(dirname "$SCRIPT_DIR")" "$(basename "$SCRIPT_DIR")" 2>/dev/null

    # Extract backup
    log_info "Đang khôi phục từ backup..."

    local temp_dir=$(mktemp -d)
    tar -xzf "$selected_backup" -C "$temp_dir"

    # Copy files
    cp -rf "${temp_dir}/wpminhminhscript"/* "$SCRIPT_DIR/"

    # Cleanup
    rm -rf "$temp_dir"

    # Set permissions
    chmod +x "${SCRIPT_DIR}/wpminhminhscript"

    local restored_version=$(get_current_version)

    echo ""
    log_success "Đã khôi phục thành công về phiên bản v${restored_version}"
    log_info "Backup phiên bản cũ tại: $current_backup"
    echo ""

    read -p "Khởi động lại script? (y/n): " restart
    if [[ "$restart" == "y" ]] || [[ "$restart" == "Y" ]]; then
        exec "$SCRIPT_DIR/wpminhminhscript"
    fi

    return 0
}

# Check if update check is needed (once per day)
should_check_update() {
    if [[ ! -f "$UPDATE_CHECK_FILE" ]]; then
        return 0
    fi

    local last_check=$(cat "$UPDATE_CHECK_FILE")
    local now=$(date +%s)
    local diff=$((now - last_check))

    # Check once per day (86400 seconds)
    if [[ $diff -gt 86400 ]]; then
        return 0
    fi

    return 1
}

# Auto check for updates on startup (silent)
auto_check_updates() {
    if should_check_update; then
        check_for_updates true >/dev/null 2>&1
    fi
}
