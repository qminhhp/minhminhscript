# WP Minhminh Script - WordPress VPS Management Tool

Công cụ quản lý nhiều WordPress sites trên VPS với kiến trúc bảo mật cao sử dụng PHP-FPM pools riêng biệt.

## ✨ Tính năng

### 🔒 Bảo mật
- **PHP-FPM Pool riêng biệt** cho mỗi site (ngăn chặn lây nhiễm chéo)
- **System user riêng** cho mỗi site
- **Database user riêng** cho mỗi site
- Cô lập tài nguyên ở cấp hệ điều hành
- Security headers tự động
- Rate limiting cho wp-login.php
- SSL/TLS tự động với Let's Encrypt

### 🚀 Quản lý Sites
- Thêm/xóa WordPress site tự động
- Cài đặt WordPress tự động
- Quản lý multiple sites trên một VPS
- Enable/disable sites
- Xem thông tin chi tiết site

### 💾 Database Management
- Backup/restore database
- Optimize database
- Cleanup WordPress database (transients, revisions, spam)
- Xem dung lượng database
- Thay đổi mật khẩu database

### 🗂️ Backup & Restore
- Backup site (files + database)
- Backup tất cả sites
- Restore site từ backup
- Auto backup theo lịch (daily/weekly/monthly)
- Xóa backups cũ tự động
- Nén backup tự động

### ⚡ Cache Management
- Xóa cache site
- Xóa cache tất cả sites
- OPcache management
- Redis support
- Memcached support
- Trạng thái cache
- Hỗ trợ 12+ cache plugins phổ biến (WP Rocket, W3TC, WP Super Cache, v.v.)

### 🎯 WordPress Advanced Features
#### Bảo trì & Bảo mật
- **Magic Login Link** - Tạo link đăng nhập tạm thời (không cần password)
- **Maintenance Mode** - Bật/tắt chế độ bảo trì
- **Disable XML-RPC** - Tắt XML-RPC endpoint (ngăn brute force)
- **Change Salt Keys** - Đổi salt keys và logout tất cả users
- **File Edit Control** - Bật/tắt chỉnh sửa file trong admin
- **Scan Base64 Malware** - Quét mã độc base64 trong code
- **Update Site URL** - Cập nhật home và siteurl (migration)

#### Tối ưu hóa hiệu suất
- **Optimize Heartbeat API** - Giảm tần suất Heartbeat (giảm CPU load)
- **Clean Transients** - Xóa transients cũ và expired
- **Optimize Database** - Tối ưu database tables (OPTIMIZE TABLE)
- **Clean Post Revisions** - Xóa revisions cũ, giữ N revisions mới nhất
- **Disable Emojis** - Tắt emoji scripts (giảm HTTP requests)
- **Disable Embeds** - Tắt oEmbed functionality
- **Limit Post Revisions** - Giới hạn số revisions lưu trữ
- **Unix Socket DB** - Dùng Unix socket thay vì TCP (nhanh hơn)
- **Memory Limit** - Tăng WP_MEMORY_LIMIT
- **Flush Rewrite Rules** - Reset permalinks

#### Quản lý Database
- **Check Autoload** - Kiểm tra autoload data size (tối ưu tốc độ)
- **Search & Replace** - Tìm và thay thế trong database (migration)
- **Change DB Prefix** - Đổi table prefix (bảo mật)
- **Delete Spam Comments** - Xóa spam comments hàng loạt
- **Optimize Database** - Tối ưu và dọn dẹp database

#### Quản lý hình ảnh
- **Optimize Images** - Tối ưu JPG/PNG (jpegoptim, pngquant)
- **Optimize All Sites** - Tối ưu hình ảnh tất cả sites
- **Regenerate Thumbnails** - Tạo lại thumbnails với WP-CLI
- **Image Statistics** - Thống kê số lượng và dung lượng hình ảnh

#### Công cụ phát triển
- **WordPress Health Check** - Kiểm tra sức khỏe WP toàn diện
- **Hook Speed Profiling** - Phân tích hiệu suất hooks và plugins
- **WP Debug** - Bật/tắt WP_DEBUG mode
- **Magic Login Link** - Truy cập admin nhanh

#### Cập nhật hàng loạt
- **Update WordPress Core** - Cập nhật WordPress core
- **Update All Plugins** - Cập nhật tất cả plugins
- **Update All Themes** - Cập nhật tất cả themes
- **Update All Sites** - Cập nhật tất cả sites trên VPS

### 🌐 Domain & DNS Management
#### Domain Aliases
- **Add Domain Alias** - Point nhiều domains đến cùng một site
- **Remove Domain Alias** - Xóa domain alias
- **List Domain Aliases** - Liệt kê tất cả aliases của domain

#### Domain Redirects
- **Create Domain Redirect** - Tạo redirect 301/302 giữa domains
- **Remove Domain Redirect** - Xóa domain redirect
- **Force WWW Redirect** - Redirect non-WWW sang WWW
- **Force non-WWW Redirect** - Redirect WWW sang non-WWW
- **List All Redirects** - Danh sách tất cả redirects đang hoạt động

#### Subdomain Management
- **Create Subdomain Site** - Tạo subdomain như WordPress site độc lập (riêng PHP-FPM pool, database, user)
- **Create Subdomain Alias** - Tạo subdomain dùng chung PHP-FPM pool với parent
- **Create Wildcard Subdomain** - Cấu hình wildcard subdomain (*.domain.com)
- **Remove Subdomain** - Xóa subdomain
- **Remove Wildcard Subdomain** - Xóa wildcard config
- **List Subdomains** - Liệt kê tất cả subdomains của domain

#### Cloudflare Integration
- **Setup Cloudflare API** - Cấu hình API token và Zone ID
- **Get Zone ID** - Lấy Zone ID từ domain name
- **Add DNS Record** - Thêm A record (proxied/DNS only)
- **List DNS Records** - Liệt kê tất cả DNS records
- **Delete DNS Record** - Xóa DNS record theo ID
- **Purge Cache** - Xóa Cloudflare cache (all/URLs)
- **Get SSL Status** - Kiểm tra SSL mode hiện tại
- **Set SSL Mode** - Đặt SSL mode (off/flexible/full/strict)
- **Enable Development Mode** - Bật dev mode (bypass cache 3h)
- **Check Cloudflare Status** - Kiểm tra trạng thái API config

### 🔒 Security & Protection
#### Firewall (UFW)
- **Install UFW** - Cài đặt Uncomplicated Firewall
- **Setup Basic Rules** - HTTP (80), HTTPS (443), SSH (22)
- **Enable/Disable Firewall** - Bật/tắt firewall
- **Allow/Deny Port** - Quản lý port rules
- **Allow/Deny IP** - IP-based access control
- **SSH Rate Limiting** - Giới hạn SSH connections (6/30s)
- **Setup Common Ports** - MySQL, Redis, Memcached (localhost only)
- **Block Attack Ports** - Block common attack ports
- **Backup Rules** - Backup firewall configuration

#### Fail2ban
- **Install Fail2ban** - Cài đặt Fail2ban
- **Setup WordPress Jails** - WordPress-specific protection
  * wordpress-xmlrpc: Block XML-RPC brute force
  * wordpress-wp-login: Block wp-login.php attacks
  * wordpress-404: Block scanning attempts
- **Enable/Disable Jail** - Quản lý jails
- **Ban/Unban IP** - Manual IP management
- **Whitelist IP** - IP whitelist
- **Configure Jail Settings** - maxretry, findtime, bantime
- **List Banned IPs** - Xem danh sách IPs bị ban
- **Test Filter** - Test regex filters với log files

#### Logrotate
- **Setup WordPress Logrotate** - Rotate Nginx và site logs
- **Setup PHP-FPM Logrotate** - Rotate PHP-FPM logs
- **Setup MySQL Logrotate** - Rotate MySQL/MariaDB logs
- **Create Custom Config** - Tạo logrotate config tùy chỉnh
- **Force Rotate** - Force rotate logs ngay lập tức
- **Clean Old Logs** - Xóa logs cũ hơn N ngày
- **Show Disk Usage** - Thống kê dung lượng logs
- **Test Configuration** - Test logrotate config

### 📊 Monitoring
- Giám sát tài nguyên hệ thống (CPU, RAM, Disk)
- Trạng thái dịch vụ (Nginx, PHP-FPM, MySQL)
- Giám sát PHP-FPM pools
- Dung lượng sites
- Dung lượng databases
- Trạng thái websites (online/offline)
- Tạo báo cáo hệ thống
- Giám sát real-time

### 🔄 VPS & Sites Migration
- **Transfer toàn bộ VPS** - Rsync toàn bộ hệ thống sang VPS mới
- **Transfer từng site** - Di chuyển 1 WordPress site sang VPS khác
- **Transfer tất cả sites** - Chuyển tất cả sites cùng lúc
- **Import/Export packages** - Backup site thành package để di chuyển
- **Auto setup on destination** - Tự động tạo user, database, pool, vhost
- **SSH-based transfer** - Rsync qua SSH an toàn và nhanh

### 🤖 n8n Workflow Automation
- **Docker-based deployment** - n8n chạy trong Docker container
- **Multiple instances** - Quản lý nhiều n8n instances trên một VPS
- **Nginx reverse proxy** - Tự động config với WebSocket support
- **SSL-ready** - Tích hợp Let's Encrypt
- **Basic Auth** - Bảo vệ trước khi setup
- **400+ integrations** - Google, Slack, WordPress, GitHub, etc.
- **Backup workflows** - Backup credentials & workflows
- **Auto update** - Cập nhật lên version mới nhất
- **Use cases**: Auto backup → Cloud, Monitor uptime → Alerts, Auto social sharing, Form → Sheets + Email

## 📋 Yêu cầu hệ thống

- **OS**: Ubuntu 20.04/22.04 hoặc Debian 10/11
- **Nginx**: >= 1.18
- **PHP**: >= 8.0 (khuyến nghị 8.3)
- **MySQL/MariaDB**: >= 5.7/10.3
- **RAM**: Tối thiểu 2GB (khuyến nghị 4GB+)
- **Disk**: Tùy thuộc vào số lượng sites
- **Root access**: Bắt buộc

## 🔧 Cài đặt

### Cài đặt nhanh (Khuyến nghị)

Cài đặt tự động với một dòng lệnh:

```bash
curl -sL https://raw.githubusercontent.com/qminhhp/minhminhscript/claude/vps-wordpress-management-script-011CV63HHAiT1yQs5Zo7Lx54/install.sh | bash
```

Hoặc với wget:

```bash
wget -qO- https://raw.githubusercontent.com/qminhhp/minhminhscript/claude/vps-wordpress-management-script-011CV63HHAiT1yQs5Zo7Lx54/install.sh | bash
```

📖 **[Xem hướng dẫn cài đặt chi tiết →](INSTALLATION.md)**

### Cài đặt thủ công

#### 1. Cài đặt các gói cần thiết

```bash
# Update hệ thống
apt update && apt upgrade -y

# Cài đặt Nginx
apt install nginx -y

# Cài đặt PHP 8.3 và các extension
apt install software-properties-common -y
add-apt-repository ppa:ondrej/php -y
apt update
apt install php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring \
            php8.3-xml php8.3-xmlrpc php8.3-soap php8.3-intl php8.3-zip -y

# Cài đặt MySQL/MariaDB
apt install mariadb-server -y

# Bảo mật MySQL
mysql_secure_installation

# Cài đặt các công cụ khác
apt install curl wget git unzip -y
```

### 2. Clone hoặc download script

```bash
# Clone từ repository
git clone https://github.com/yourusername/minhminhscript.git /opt/minhminhscript

# Hoặc download và giải nén
cd /opt
wget https://github.com/yourusername/minhminhscript/archive/main.zip
unzip main.zip
mv minhminhscript-main minhminhscript
```

### 3. Cấp quyền thực thi

```bash
cd /opt/minhminhscript
chmod +x wpminhminhscript
chmod +x lib/common.sh
chmod +x modules/*/*.sh
```

### 4. Tạo symlink để chạy từ bất kỳ đâu

```bash
ln -s /opt/minhminhscript/wpminhminhscript /usr/local/bin/wpminhminhscript
```

### 5. Chạy script

```bash
wpminhminhscript
```

## 📖 Hướng dẫn sử dụng

### Chạy menu tương tác

```bash
wpminhminhscript
```

### Chạy command line

```bash
# Thêm site mới
wpminhminhscript add-site

# Xóa site
wpminhminhscript remove-site

# Danh sách sites
wpminhminhscript list-sites

# Backup tất cả sites (dùng cho cron)
wpminhminhscript backup-all-auto

# Xem trợ giúp
wpminhminhscript help
```

## 🏗️ Kiến trúc

### Cấu trúc thư mục

```
minhminhscript/
├── wpminhminhscript          # Script chính
├── lib/
│   └── common.sh             # Hàm dùng chung
├── config/
│   ├── default.conf          # Cấu hình mặc định
│   ├── sites.db              # Database lưu thông tin sites
│   └── *_credentials.txt     # File lưu thông tin đăng nhập
├── modules/
│   ├── site/                 # Module quản lý sites
│   ├── phpfpm/               # Module PHP-FPM
│   ├── nginx/                # Module Nginx
│   ├── database/             # Module database
│   ├── backup/               # Module backup
│   ├── cache/                # Module cache
│   └── monitor/              # Module monitoring
├── templates/
│   ├── nginx/                # Template Nginx vhost
│   └── phpfpm/               # Template PHP-FPM pool
└── logs/
    └── wpminhminhscript.log  # Log file
```

### Kiến trúc bảo mật

Mỗi site được cô lập hoàn toàn:

```
Site: example.com
├── System User: example_com
├── Site Root: /var/www/example.com
├── PHP-FPM Pool: example_com.conf
│   └── Socket: /run/php/example_com.sock
├── Nginx Vhost: example_com.conf
├── Database: example_com_db
└── DB User: example_com_user
```

**Lợi ích:**
- Site A bị hack không ảnh hưởng đến Site B, C, D...
- Mỗi site có giới hạn tài nguyên riêng
- Dễ dàng quản lý và debug
- Tăng hiệu suất và ổn định

## 📝 Ví dụ sử dụng

### Thêm site mới

1. Chạy script: `wpminhminhscript`
2. Chọn `1. Quản lý Sites`
3. Chọn `1. Thêm site mới`
4. Nhập tên miền: `example.com`
5. Xác nhận thông tin
6. Đợi script tạo tự động:
   - System user
   - Site directory
   - Database & user
   - PHP-FPM pool
   - Nginx vhost
   - WordPress installation

### Backup site

```bash
# Từ menu
wpminhminhscript -> 4. Backup & Restore -> 1. Backup một site

# Hoặc tạo cron job backup tự động
wpminhminhscript -> 4. Backup & Restore -> 6. Cài đặt auto backup
```

### Cài đặt SSL

```bash
# Từ menu
wpminhminhscript -> 1. Quản lý Sites -> 5. Cài đặt SSL

# Nhập domain và site name
# SSL sẽ được cài đặt tự động qua Let's Encrypt
```

### Giám sát hệ thống

```bash
wpminhminhscript -> 5. Giám sát Hệ thống

# Các tùy chọn:
# - Tài nguyên hệ thống
# - Trạng thái dịch vụ
# - PHP-FPM pools
# - Dung lượng sites/databases
# - Trạng thái websites
# - Giám sát real-time
```

## 🔐 Bảo mật

### Các tính năng bảo mật

1. **Cô lập PHP-FPM**: Mỗi site có pool riêng với user riêng
2. **Cô lập filesystem**: open_basedir giới hạn truy cập file
3. **Database riêng**: Mỗi site có database user riêng
4. **Security headers**: X-Frame-Options, X-XSS-Protection, etc.
5. **Disable XML-RPC**: Ngăn chặn brute force attacks
6. **Rate limiting**: Giới hạn login attempts
7. **Disable dangerous functions**: exec, shell_exec, system, etc.

### File permissions

```bash
# Directories: 755
find /var/www/example.com -type d -exec chmod 755 {} \;

# Files: 644
find /var/www/example.com -type f -exec chmod 644 {} \;

# Owner: site user
chown -R example_com:example_com /var/www/example.com
```

## 🚀 Tối ưu hiệu suất

### PHP-FPM tuning

Chỉnh sửa trong `/etc/php/8.3/fpm/pool.d/[site_name].conf`:

```ini
pm = dynamic
pm.max_children = 10          # Tùy thuộc vào RAM
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500
```

### OPcache

```bash
# Enable OPcache từ menu
wpminhminhscript -> 3. Quản lý Cache -> 4. Enable/Disable OPcache
```

### Redis Object Cache

```bash
# Cài đặt Redis
wpminhminhscript -> 3. Quản lý Cache -> 5. Cài đặt Redis

# Sau đó cài plugin Redis Object Cache trong WordPress
```

## 🤝 So sánh với các giải pháp khác

| Tính năng | WP Minhminh Script | WordOps | Trellis |
|-----------|-------------------|---------|---------|
| PHP-FPM pool riêng | ✅ | ❌ | ⚠️ (cần tùy chỉnh) |
| Dễ sử dụng | ✅ | ✅ | ❌ (phức tạp) |
| Bảo mật cao | ✅ | ❌ | ✅ |
| Multiple sites | ✅ | ✅ | ✅ |
| Backup tự động | ✅ | ✅ | ✅ |
| Monitoring | ✅ | ⚠️ | ⚠️ |
| Miễn phí | ✅ | ✅ | ✅ |

## 🐛 Troubleshooting

### Site không thể truy cập

```bash
# Kiểm tra Nginx
nginx -t
systemctl status nginx

# Kiểm tra PHP-FPM
systemctl status php8.3-fpm

# Kiểm tra logs
tail -f /var/log/nginx/[site_name]-error.log
tail -f /var/log/php-fpm/[site_name]-error.log
```

### Database connection error

```bash
# Kiểm tra MySQL
systemctl status mysql

# Kiểm tra wp-config.php
cat /var/www/example.com/wp-config.php | grep DB_

# Test kết nối
mysql -u [db_user] -p -h localhost [db_name]
```

### Permission errors

```bash
# Fix permissions
chown -R [site_user]:[site_user] /var/www/[domain]
find /var/www/[domain] -type d -exec chmod 755 {} \;
find /var/www/[domain] -type f -exec chmod 644 {} \;

# Add www-data to site user group
usermod -a -G [site_user] www-data
```

## 📚 Tài liệu tham khảo

Script này được xây dựng dựa trên nghiên cứu và tham khảo từ:

- [Trellis by Roots.io](https://roots.io/trellis/) - Ansible-based WordPress LEMP stack
- [WP Tang Toc OLS](https://wptangtoc.com/) - WordPress optimization script
- Nghiên cứu về Nginx vs OpenLiteSpeed (research1.txt)
- Nghiên cứu về PHP-FPM isolation (research2.txt)

## 📄 License

MIT License

## 👤 Author

Minhminh

## 🙏 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📮 Support

Nếu bạn gặp vấn đề hoặc có câu hỏi:
- Tạo issue trên GitHub
- Email: your-email@example.com

## 🔄 Changelog

### Version 1.0.0 (2024)
- Initial release
- Site management với PHP-FPM pools riêng biệt
- Database management
- Cache management
- Backup & Restore
- System monitoring
- Auto SSL với Let's Encrypt

## ⚠️ Lưu ý quan trọng

1. **Luôn backup trước khi thực hiện thay đổi**
2. **Test trên môi trường staging trước**
3. **Đọc kỹ thông báo trước khi xác nhận xóa**
4. **Lưu trữ file credentials an toàn**
5. **Cập nhật script thường xuyên**
6. **Giám sát tài nguyên hệ thống**

## 🎯 Roadmap

- [ ] Tích hợp với Cloudflare API
- [ ] Upload backup lên cloud storage (AWS S3, Google Drive, etc.)
- [ ] Website health check và alerts
- [ ] Auto scaling dựa trên load
- [ ] CDN integration
- [ ] WordPress CLI integration
- [ ] GUI web interface
- [ ] Docker support
