#!/bin/bash
# WordPress Image Optimization Module
# Tối ưu hóa hình ảnh WordPress

source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/config/default.conf"

# Install image optimization tools
install_image_tools() {
    print_info "Đang kiểm tra các công cụ tối ưu hình ảnh..."

    local need_install=false

    if ! command_exists jpegoptim; then
        need_install=true
    fi

    if ! command_exists pngquant; then
        need_install=true
    fi

    if ! command_exists optipng; then
        need_install=true
    fi

    if [[ "$need_install" = false ]]; then
        print_success "Các công cụ đã được cài đặt"
        return 0
    fi

    print_info "Đang cài đặt jpegoptim, pngquant, optipng..."

    # Detect OS and install
    if command_exists apt-get; then
        apt-get update -qq
        apt-get install -y jpegoptim pngquant optipng
    elif command_exists yum; then
        yum -y install jpegoptim pngquant optipng
    else
        print_error "Không hỗ trợ hệ điều hành này"
        return 1
    fi

    print_success "Đã cài đặt các công cụ tối ưu hình ảnh"
    log_message "INFO" "Installed image optimization tools"
    return 0
}

# Optimize images for a site
optimize_images() {
    local domain=$1
    local quality=${2:-76}

    # Install tools if needed
    if ! command_exists jpegoptim || ! command_exists pngquant; then
        print_info "Đang cài đặt công cụ tối ưu hình ảnh..."
        install_image_tools
    fi

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ site_name site_user _ _ site_root _ <<< "$site_info"

    if [[ ! -f "${site_root}/wp-load.php" ]]; then
        print_error "Không tìm thấy WordPress tại: $site_root"
        return 1
    fi

    local uploads_dir="${site_root}/wp-content/uploads"
    if [[ ! -d "$uploads_dir" ]]; then
        print_error "Thư mục uploads không tồn tại: $uploads_dir"
        return 1
    fi

    print_info "Tối ưu hình ảnh cho site: $domain"
    print_info "Thư mục: $uploads_dir"
    print_info "Quality: $quality%"
    echo ""

    # Count images
    local jpg_count=$(find "$uploads_dir" -type f -name "*.jpg" -o -name "*.jpeg" 2>/dev/null | wc -l)
    local png_count=$(find "$uploads_dir" -type f -name "*.png" 2>/dev/null | wc -l)

    print_info "Tìm thấy:"
    echo "  - $jpg_count file JPG/JPEG"
    echo "  - $png_count file PNG"
    echo ""

    if [[ $jpg_count -eq 0 ]] && [[ $png_count -eq 0 ]]; then
        print_warning "Không tìm thấy hình ảnh nào"
        return 0
    fi

    if ! confirm_action "Bạn có muốn tối ưu hình ảnh?" "y"; then
        print_info "Đã hủy"
        return 1
    fi

    echo ""
    print_info "Đang tối ưu hình ảnh... (có thể mất vài phút)"
    echo ""

    # Optimize JPG files
    if [[ $jpg_count -gt 0 ]]; then
        print_info "Đang tối ưu JPG/JPEG files..."
        find "$uploads_dir" -type f \( -name "*.jpg" -o -name "*.jpeg" \) -exec jpegoptim --strip-all -m${quality} {} \; 2>/dev/null
        print_success "✓ Đã tối ưu $jpg_count JPG/JPEG files"
    fi

    # Optimize PNG files
    if [[ $png_count -gt 0 ]]; then
        print_info "Đang tối ưu PNG files..."
        find "$uploads_dir" -type f -name "*.png" -exec pngquant --force --quality=83-100 --skip-if-larger --strip --verbose {} --output {} \; 2>/dev/null
        print_success "✓ Đã tối ưu $png_count PNG files"
    fi

    # Fix permissions
    print_info "Đang sửa permissions..."
    find "$uploads_dir" -type d -exec chmod 755 {} \;
    find "$uploads_dir" -type f -exec chmod 644 {} \;
    chown -R "${site_user}:${site_user}" "$uploads_dir"

    print_success "Đã tối ưu hình ảnh thành công!"
    log_message "INFO" "Optimized images for: $domain (quality: $quality)"

    return 0
}

# Optimize images for all sites
optimize_images_all_sites() {
    print_info "Tối ưu hình ảnh cho TẤT CẢ sites"
    echo ""

    source "${MODULES_DIR}/site/site-manager.sh"

    if [[ ! -f "$SITES_DB" ]] || [[ ! -s "$SITES_DB" ]]; then
        print_warning "Chưa có site nào"
        return 1
    fi

    local quality=${1:-76}
    local total=0
    local success=0

    print_info "Quality: $quality%"
    echo ""

    if ! confirm_action "Bạn có chắc muốn tối ưu hình ảnh cho TẤT CẢ sites?" "n"; then
        print_info "Đã hủy"
        return 1
    fi

    echo ""

    while IFS='|' read -r domain _ _ _ _ _ _; do
        ((total++))
        echo "================================"
        print_info "[$total] $domain"
        echo "================================"

        if optimize_images "$domain" "$quality"; then
            ((success++))
        fi

        echo ""
    done < "$SITES_DB"

    print_info "Kết quả: $success/$total sites"
    log_message "INFO" "Optimized images for all sites: $success/$total"

    return 0
}

# Check image optimization tools status
check_image_tools() {
    print_info "Kiểm tra các công cụ tối ưu hình ảnh:"
    echo ""

    local all_installed=true

    # Check jpegoptim
    if command_exists jpegoptim; then
        local version=$(jpegoptim --version 2>&1 | head -n1)
        print_success "✓ jpegoptim: $version"
    else
        print_error "✗ jpegoptim: Chưa cài đặt"
        all_installed=false
    fi

    # Check pngquant
    if command_exists pngquant; then
        local version=$(pngquant --version 2>&1)
        print_success "✓ pngquant: $version"
    else
        print_error "✗ pngquant: Chưa cài đặt"
        all_installed=false
    fi

    # Check optipng
    if command_exists optipng; then
        local version=$(optipng --version 2>&1 | head -n1)
        print_success "✓ optipng: $version"
    else
        print_error "✗ optipng: Chưa cài đặt"
        all_installed=false
    fi

    echo ""

    if [[ "$all_installed" = false ]]; then
        print_info "Sử dụng 'install_image_tools' để cài đặt"
    fi

    return 0
}

# Get image statistics for a site
get_image_stats() {
    local domain=$1

    source "${MODULES_DIR}/site/site-manager.sh"
    if ! site_exists "$domain"; then
        print_error "Site không tồn tại: $domain"
        return 1
    fi

    local site_info=$(get_site_info "$domain")
    IFS='|' read -r _ _ _ _ _ site_root _ <<< "$site_info"

    local uploads_dir="${site_root}/wp-content/uploads"
    if [[ ! -d "$uploads_dir" ]]; then
        print_error "Thư mục uploads không tồn tại"
        return 1
    fi

    print_info "Thống kê hình ảnh cho: $domain"
    echo ""

    # Count files
    local jpg_count=$(find "$uploads_dir" -type f \( -name "*.jpg" -o -name "*.jpeg" \) 2>/dev/null | wc -l)
    local png_count=$(find "$uploads_dir" -type f -name "*.png" 2>/dev/null | wc -l)
    local gif_count=$(find "$uploads_dir" -type f -name "*.gif" 2>/dev/null | wc -l)
    local webp_count=$(find "$uploads_dir" -type f -name "*.webp" 2>/dev/null | wc -l)

    # Calculate sizes
    local total_size=$(du -sh "$uploads_dir" 2>/dev/null | cut -f1)

    echo "Số lượng:"
    echo "  - JPG/JPEG: $jpg_count files"
    echo "  - PNG: $png_count files"
    echo "  - GIF: $gif_count files"
    echo "  - WebP: $webp_count files"
    echo ""
    echo "Tổng dung lượng: $total_size"
    echo ""

    return 0
}
