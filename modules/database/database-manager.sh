#!/bin/bash
# Database Manager Module
# Quản lý MySQL/MariaDB databases cho WordPress sites

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Get MySQL root password
get_mysql_root_password() {
    if [[ -f "${CONFIG_DIR}/.mysql_root" ]]; then
        cat "${CONFIG_DIR}/.mysql_root"
    else
        echo ""
    fi
}

# Save MySQL root password
save_mysql_root_password() {
    local password=$1
    echo "$password" > "${CONFIG_DIR}/.mysql_root"
    chmod 600 "${CONFIG_DIR}/.mysql_root"
}

# Execute MySQL command
mysql_exec() {
    local command=$1
    local root_pass=$(get_mysql_root_password)

    if [[ -n "$root_pass" ]]; then
        mysql -u root -p"$root_pass" -e "$command" 2>/dev/null
    else
        mysql -u root -e "$command" 2>/dev/null
    fi
}

# Create database and user
create_database() {
    local db_name=$1
    local db_user=$2
    local db_pass=$3

    # Create database
    mysql_exec "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET ${DB_CHARSET} COLLATE ${DB_COLLATE};"
    if [[ $? -eq 0 ]]; then
        print_success "Đã tạo database: $db_name"
        log_message "INFO" "Created database: $db_name"
    else
        print_error "Không thể tạo database: $db_name"
        return 1
    fi

    # Create user
    mysql_exec "CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';"
    if [[ $? -eq 0 ]]; then
        print_success "Đã tạo database user: $db_user"
        log_message "INFO" "Created database user: $db_user"
    else
        print_error "Không thể tạo database user: $db_user"
        return 1
    fi

    # Grant privileges
    mysql_exec "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';"
    mysql_exec "FLUSH PRIVILEGES;"

    if [[ $? -eq 0 ]]; then
        print_success "Đã cấp quyền cho user: $db_user"
        log_message "INFO" "Granted privileges to: $db_user"
        return 0
    else
        print_error "Không thể cấp quyền cho user: $db_user"
        return 1
    fi
}

# Drop database and user
drop_database() {
    local db_name=$1
    local db_user=$2

    # Drop database
    mysql_exec "DROP DATABASE IF EXISTS \`${db_name}\`;"
    if [[ $? -eq 0 ]]; then
        print_success "Đã xóa database: $db_name"
        log_message "INFO" "Dropped database: $db_name"
    else
        print_error "Không thể xóa database: $db_name"
    fi

    # Drop user
    mysql_exec "DROP USER IF EXISTS '${db_user}'@'localhost';"
    if [[ $? -eq 0 ]]; then
        print_success "Đã xóa database user: $db_user"
        log_message "INFO" "Dropped database user: $db_user"
    else
        print_error "Không thể xóa database user: $db_user"
    fi

    mysql_exec "FLUSH PRIVILEGES;"
    return 0
}

# Backup database
backup_database() {
    local db_name=$1
    local backup_file=$2

    if [[ -z "$backup_file" ]]; then
        backup_file="${BACKUP_DIR}/${db_name}_$(date +%Y%m%d_%H%M%S).sql"
    fi

    ensure_directory "$(dirname "$backup_file")"

    local root_pass=$(get_mysql_root_password)

    if [[ -n "$root_pass" ]]; then
        mysqldump -u root -p"$root_pass" "$db_name" > "$backup_file" 2>/dev/null
    else
        mysqldump -u root "$db_name" > "$backup_file" 2>/dev/null
    fi

    if [[ $? -eq 0 ]]; then
        # Compress backup
        gzip "$backup_file"
        backup_file="${backup_file}.gz"
        print_success "Đã backup database: $db_name"
        print_info "File backup: $backup_file"
        log_message "INFO" "Backed up database: $db_name to $backup_file"
        echo "$backup_file"
        return 0
    else
        print_error "Không thể backup database: $db_name"
        log_message "ERROR" "Failed to backup database: $db_name"
        return 1
    fi
}

# Restore database
restore_database() {
    local db_name=$1
    local backup_file=$2

    if [[ ! -f "$backup_file" ]]; then
        print_error "File backup không tồn tại: $backup_file"
        return 1
    fi

    local root_pass=$(get_mysql_root_password)

    # Check if file is compressed
    if [[ "$backup_file" == *.gz ]]; then
        if [[ -n "$root_pass" ]]; then
            gunzip -c "$backup_file" | mysql -u root -p"$root_pass" "$db_name" 2>/dev/null
        else
            gunzip -c "$backup_file" | mysql -u root "$db_name" 2>/dev/null
        fi
    else
        if [[ -n "$root_pass" ]]; then
            mysql -u root -p"$root_pass" "$db_name" < "$backup_file" 2>/dev/null
        else
            mysql -u root "$db_name" < "$backup_file" 2>/dev/null
        fi
    fi

    if [[ $? -eq 0 ]]; then
        print_success "Đã restore database: $db_name"
        log_message "INFO" "Restored database: $db_name from $backup_file"
        return 0
    else
        print_error "Không thể restore database: $db_name"
        log_message "ERROR" "Failed to restore database: $db_name"
        return 1
    fi
}

# Optimize database
optimize_database() {
    local db_name=$1

    mysql_exec "OPTIMIZE TABLE \`${db_name}\`.*;"

    if [[ $? -eq 0 ]]; then
        print_success "Đã optimize database: $db_name"
        log_message "INFO" "Optimized database: $db_name"
        return 0
    else
        print_error "Không thể optimize database: $db_name"
        log_message "ERROR" "Failed to optimize database: $db_name"
        return 1
    fi
}

# Repair database
repair_database() {
    local db_name=$1

    mysql_exec "REPAIR TABLE \`${db_name}\`.*;"

    if [[ $? -eq 0 ]]; then
        print_success "Đã repair database: $db_name"
        log_message "INFO" "Repaired database: $db_name"
        return 0
    else
        print_error "Không thể repair database: $db_name"
        log_message "ERROR" "Failed to repair database: $db_name"
        return 1
    fi
}

# Get database size
get_database_size() {
    local db_name=$1

    local size=$(mysql_exec "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = '${db_name}';" | tail -n 1)

    echo "${size} MB"
}

# List all databases
list_databases() {
    show_header
    echo -e "${CYAN}DANH SÁCH DATABASES${NC}"
    echo ""

    local dbs=$(mysql_exec "SHOW DATABASES;" | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys")

    if [[ -z "$dbs" ]]; then
        print_warning "Chưa có database nào"
    else
        local count=1
        printf "%-5s %-30s %-15s\n" "STT" "DATABASE NAME" "SIZE"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        while read -r db; do
            local size=$(get_database_size "$db")
            printf "%-5s %-30s %-15s\n" "$count" "$db" "$size"
            ((count++))
        done <<< "$dbs"

        echo ""
        print_info "Tổng số databases: $((count - 1))"
    fi

    show_footer
    pause
}

# Clean WordPress transients
clean_transients() {
    local db_name=$1
    local db_prefix=${2:-wp_}

    print_info "Đang xóa transients từ database: $db_name"

    local sql="DELETE FROM \`${db_prefix}options\` WHERE option_name LIKE '_transient_%' OR option_name LIKE '_site_transient_%';"

    mysql_exec "USE \`${db_name}\`; ${sql}"

    if [[ $? -eq 0 ]]; then
        print_success "Đã xóa transients"
        log_message "INFO" "Cleaned transients from: $db_name"
        return 0
    else
        print_error "Không thể xóa transients"
        log_message "ERROR" "Failed to clean transients from: $db_name"
        return 1
    fi
}

# Clean WordPress post revisions
clean_revisions() {
    local db_name=$1
    local db_prefix=${2:-wp_}
    local keep_revisions=${3:-5}

    print_info "Đang xóa post revisions cũ từ database: $db_name"

    local sql="DELETE FROM \`${db_prefix}posts\` WHERE post_type = 'revision' AND ID NOT IN (SELECT ID FROM (SELECT ID FROM \`${db_prefix}posts\` WHERE post_type = 'revision' ORDER BY post_modified DESC LIMIT ${keep_revisions}) AS temp);"

    mysql_exec "USE \`${db_name}\`; ${sql}"

    if [[ $? -eq 0 ]]; then
        print_success "Đã xóa revisions cũ"
        log_message "INFO" "Cleaned revisions from: $db_name"
        return 0
    else
        print_error "Không thể xóa revisions"
        log_message "ERROR" "Failed to clean revisions from: $db_name"
        return 1
    fi
}

# Clean WordPress spam comments
clean_spam_comments() {
    local db_name=$1
    local db_prefix=${2:-wp_}

    print_info "Đang xóa spam comments từ database: $db_name"

    local sql="DELETE FROM \`${db_prefix}comments\` WHERE comment_approved = 'spam';"

    mysql_exec "USE \`${db_name}\`; ${sql}"

    if [[ $? -eq 0 ]]; then
        print_success "Đã xóa spam comments"
        log_message "INFO" "Cleaned spam comments from: $db_name"
        return 0
    else
        print_error "Không thể xóa spam comments"
        log_message "ERROR" "Failed to clean spam comments from: $db_name"
        return 1
    fi
}

# Full WordPress database cleanup
cleanup_wordpress_db() {
    local db_name=$1
    local db_prefix=${2:-wp_}

    print_info "Đang thực hiện cleanup toàn diện cho database: $db_name"

    clean_transients "$db_name" "$db_prefix"
    clean_revisions "$db_name" "$db_prefix"
    clean_spam_comments "$db_name" "$db_prefix"
    optimize_database "$db_name"

    print_success "Đã cleanup database hoàn tất"
    log_message "INFO" "Full cleanup completed for: $db_name"
}

# Change database password
change_db_password() {
    local db_user=$1
    local new_password=$2

    mysql_exec "ALTER USER '${db_user}'@'localhost' IDENTIFIED BY '${new_password}';"
    mysql_exec "FLUSH PRIVILEGES;"

    if [[ $? -eq 0 ]]; then
        print_success "Đã đổi mật khẩu cho user: $db_user"
        log_message "INFO" "Changed password for database user: $db_user"
        return 0
    else
        print_error "Không thể đổi mật khẩu cho user: $db_user"
        log_message "ERROR" "Failed to change password for: $db_user"
        return 1
    fi
}
