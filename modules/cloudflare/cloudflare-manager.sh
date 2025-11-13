#!/bin/bash
# Cloudflare Manager Module
# Quản lý DNS và cache thông qua Cloudflare API v4

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Cloudflare config file
CF_CONFIG_FILE="${CONFIG_DIR}/cloudflare.conf"

# Initialize Cloudflare config
init_cloudflare_config() {
    if [[ ! -f "$CF_CONFIG_FILE" ]]; then
        cat > "$CF_CONFIG_FILE" <<EOF
# Cloudflare API Configuration
# Get your API token from: https://dash.cloudflare.com/profile/api-tokens

CF_API_TOKEN=""
CF_ZONE_ID=""
CF_EMAIL=""
EOF
        chmod 600 "$CF_CONFIG_FILE"
        print_success "Đã tạo file cấu hình: $CF_CONFIG_FILE"
        print_info "Vui lòng cấu hình API token và Zone ID"
    fi
}

# Load Cloudflare config
load_cloudflare_config() {
    if [[ ! -f "$CF_CONFIG_FILE" ]]; then
        init_cloudflare_config
        return 1
    fi

    source "$CF_CONFIG_FILE"

    if [[ -z "$CF_API_TOKEN" ]]; then
        print_error "Cloudflare API token chưa được cấu hình"
        print_info "Chỉnh sửa: $CF_CONFIG_FILE"
        return 1
    fi

    return 0
}

# Setup Cloudflare credentials
setup_cloudflare() {
    show_header
    echo -e "${CYAN}CẤU HÌNH CLOUDFLARE API${NC}"
    echo ""

    init_cloudflare_config

    echo "Để sử dụng Cloudflare API, bạn cần:"
    echo "1. API Token từ: https://dash.cloudflare.com/profile/api-tokens"
    echo "2. Zone ID từ dashboard của domain"
    echo ""

    read -p "Nhập Cloudflare API Token: " api_token
    read -p "Nhập Zone ID (để trống nếu chưa có): " zone_id
    read -p "Nhập Cloudflare Email (optional): " cf_email

    # Update config file
    sed -i "s|CF_API_TOKEN=.*|CF_API_TOKEN=\"${api_token}\"|" "$CF_CONFIG_FILE"
    sed -i "s|CF_ZONE_ID=.*|CF_ZONE_ID=\"${zone_id}\"|" "$CF_CONFIG_FILE"
    sed -i "s|CF_EMAIL=.*|CF_EMAIL=\"${cf_email}\"|" "$CF_CONFIG_FILE"

    print_success "Đã cấu hình Cloudflare API"
    log_message "INFO" "Configured Cloudflare API"

    show_footer
    pause
}

# Get Zone ID by domain name
get_zone_id() {
    local domain=$1

    if ! load_cloudflare_config; then
        return 1
    fi

    print_info "Đang lấy Zone ID cho: $domain"

    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")

    local zone_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [[ "$success" == "true" ]] && [[ -n "$zone_id" ]]; then
        echo "$zone_id"
        return 0
    else
        print_error "Không thể lấy Zone ID"
        echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4
        return 1
    fi
}

# Add DNS A record
add_dns_record() {
    local domain=$1
    local record_name=$2
    local ip_address=$3
    local record_type=${4:-A}
    local proxied=${5:-true}

    if ! load_cloudflare_config; then
        return 1
    fi

    # Get zone ID if not set
    if [[ -z "$CF_ZONE_ID" ]]; then
        CF_ZONE_ID=$(get_zone_id "$domain")
        if [[ -z "$CF_ZONE_ID" ]]; then
            return 1
        fi
    fi

    print_info "Đang thêm DNS record: $record_name.$domain -> $ip_address"

    local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${record_type}\",\"name\":\"${record_name}\",\"content\":\"${ip_address}\",\"ttl\":1,\"proxied\":${proxied}}")

    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [[ "$success" == "true" ]]; then
        print_success "Đã thêm DNS record: $record_name.$domain"
        log_message "INFO" "Added Cloudflare DNS record: $record_name.$domain"
        return 0
    else
        print_error "Không thể thêm DNS record"
        echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4
        return 1
    fi
}

# List DNS records
list_dns_records() {
    local domain=$1

    if ! load_cloudflare_config; then
        return 1
    fi

    # Get zone ID if not set
    if [[ -z "$CF_ZONE_ID" ]]; then
        CF_ZONE_ID=$(get_zone_id "$domain")
        if [[ -z "$CF_ZONE_ID" ]]; then
            return 1
        fi
    fi

    print_info "Đang lấy danh sách DNS records cho: $domain"

    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")

    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [[ "$success" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}DNS Records:${NC}"
        echo "----------------------------------------------------------------------"

        # Parse and display records (simplified)
        echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4

        echo ""
        return 0
    else
        print_error "Không thể lấy DNS records"
        return 1
    fi
}

# Delete DNS record
delete_dns_record() {
    local domain=$1
    local record_id=$2

    if ! load_cloudflare_config; then
        return 1
    fi

    # Get zone ID if not set
    if [[ -z "$CF_ZONE_ID" ]]; then
        CF_ZONE_ID=$(get_zone_id "$domain")
        if [[ -z "$CF_ZONE_ID" ]]; then
            return 1
        fi
    fi

    print_info "Đang xóa DNS record ID: $record_id"

    local response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")

    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [[ "$success" == "true" ]]; then
        print_success "Đã xóa DNS record"
        log_message "INFO" "Deleted Cloudflare DNS record: $record_id"
        return 0
    else
        print_error "Không thể xóa DNS record"
        return 1
    fi
}

# Purge Cloudflare cache
purge_cloudflare_cache() {
    local domain=$1
    local purge_type=${2:-all}  # all, files, tags, hosts

    if ! load_cloudflare_config; then
        return 1
    fi

    # Get zone ID if not set
    if [[ -z "$CF_ZONE_ID" ]]; then
        CF_ZONE_ID=$(get_zone_id "$domain")
        if [[ -z "$CF_ZONE_ID" ]]; then
            return 1
        fi
    fi

    print_info "Đang xóa Cloudflare cache cho: $domain ($purge_type)"

    local data
    if [[ "$purge_type" == "all" ]]; then
        data='{"purge_everything":true}'
    else
        print_error "Purge type không hợp lệ. Sử dụng: all"
        return 1
    fi

    local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/purge_cache" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$data")

    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [[ "$success" == "true" ]]; then
        print_success "Đã xóa Cloudflare cache cho: $domain"
        log_message "INFO" "Purged Cloudflare cache for: $domain"
        return 0
    else
        print_error "Không thể xóa Cloudflare cache"
        echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4
        return 1
    fi
}

# Purge cache by URL
purge_cloudflare_urls() {
    local domain=$1
    shift
    local urls=("$@")

    if ! load_cloudflare_config; then
        return 1
    fi

    # Get zone ID if not set
    if [[ -z "$CF_ZONE_ID" ]]; then
        CF_ZONE_ID=$(get_zone_id "$domain")
        if [[ -z "$CF_ZONE_ID" ]]; then
            return 1
        fi
    fi

    print_info "Đang xóa Cloudflare cache cho URLs..."

    # Build JSON array
    local files_json=$(printf '"%s",' "${urls[@]}" | sed 's/,$//')
    local data="{\"files\":[${files_json}]}"

    local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/purge_cache" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "$data")

    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [[ "$success" == "true" ]]; then
        print_success "Đã xóa Cloudflare cache cho ${#urls[@]} URLs"
        log_message "INFO" "Purged Cloudflare cache for URLs"
        return 0
    else
        print_error "Không thể xóa Cloudflare cache"
        return 1
    fi
}

# Get Cloudflare SSL status
get_ssl_status() {
    local domain=$1

    if ! load_cloudflare_config; then
        return 1
    fi

    # Get zone ID if not set
    if [[ -z "$CF_ZONE_ID" ]]; then
        CF_ZONE_ID=$(get_zone_id "$domain")
        if [[ -z "$CF_ZONE_ID" ]]; then
            return 1
        fi
    fi

    print_info "Đang kiểm tra SSL status cho: $domain"

    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/settings/ssl" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json")

    local ssl_mode=$(echo "$response" | grep -o '"value":"[^"]*"' | head -1 | cut -d'"' -f4)
    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [[ "$success" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}SSL Mode:${NC} $ssl_mode"
        echo ""
        print_info "SSL Modes: off, flexible, full, full (strict)"
        return 0
    else
        print_error "Không thể lấy SSL status"
        return 1
    fi
}

# Set Cloudflare SSL mode
set_ssl_mode() {
    local domain=$1
    local ssl_mode=$2  # off, flexible, full, strict

    if ! load_cloudflare_config; then
        return 1
    fi

    # Get zone ID if not set
    if [[ -z "$CF_ZONE_ID" ]]; then
        CF_ZONE_ID=$(get_zone_id "$domain")
        if [[ -z "$CF_ZONE_ID" ]]; then
            return 1
        fi
    fi

    # Validate SSL mode
    case $ssl_mode in
        off|flexible|full|strict)
            ;;
        *)
            print_error "SSL mode không hợp lệ: $ssl_mode"
            print_info "Sử dụng: off, flexible, full, strict"
            return 1
            ;;
    esac

    # Convert strict to full
    [[ "$ssl_mode" == "strict" ]] && ssl_mode="full"

    print_info "Đang cấu hình SSL mode: $ssl_mode"

    local response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/settings/ssl" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"value\":\"${ssl_mode}\"}")

    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [[ "$success" == "true" ]]; then
        print_success "Đã cấu hình SSL mode: $ssl_mode"
        log_message "INFO" "Set Cloudflare SSL mode to: $ssl_mode"
        return 0
    else
        print_error "Không thể cấu hình SSL mode"
        return 1
    fi
}

# Enable development mode
enable_dev_mode() {
    local domain=$1
    local duration=${2:-3}  # hours

    if ! load_cloudflare_config; then
        return 1
    fi

    # Get zone ID if not set
    if [[ -z "$CF_ZONE_ID" ]]; then
        CF_ZONE_ID=$(get_zone_id "$domain")
        if [[ -z "$CF_ZONE_ID" ]]; then
            return 1
        fi
    fi

    print_info "Đang bật Development Mode (${duration}h)"

    local response=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/settings/development_mode" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}')

    local success=$(echo "$response" | grep -o '"success":[^,]*' | cut -d':' -f2)

    if [[ "$success" == "true" ]]; then
        print_success "Đã bật Development Mode"
        print_info "Cache sẽ bị bypass trong ${duration} giờ"
        log_message "INFO" "Enabled Cloudflare Development Mode"
        return 0
    else
        print_error "Không thể bật Development Mode"
        return 1
    fi
}

# Check Cloudflare status
check_cloudflare_status() {
    show_header
    echo -e "${CYAN}CLOUDFLARE STATUS${NC}"
    echo ""

    if ! load_cloudflare_config; then
        print_error "Cloudflare API chưa được cấu hình"
        print_info "Chạy 'setup_cloudflare' để cấu hình"
        show_footer
        pause
        return 1
    fi

    print_success "✓ API Token: Đã cấu hình"

    if [[ -n "$CF_ZONE_ID" ]]; then
        print_success "✓ Zone ID: $CF_ZONE_ID"
    else
        print_warning "! Zone ID: Chưa cấu hình"
    fi

    if [[ -n "$CF_EMAIL" ]]; then
        print_info "Email: $CF_EMAIL"
    fi

    echo ""
    print_info "Config file: $CF_CONFIG_FILE"
    echo ""

    show_footer
    pause
}
