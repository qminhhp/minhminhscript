# Hướng dẫn cài đặt WP Minhminh Script

## Chuẩn bị VPS mới

### 1. Cập nhật hệ thống

```bash
apt update && apt upgrade -y
apt install curl wget git unzip software-properties-common -y
```

### 2. Cài đặt Nginx

```bash
apt install nginx -y
systemctl enable nginx
systemctl start nginx
```

### 3. Cài đặt PHP 8.3

```bash
# Thêm repository
add-apt-repository ppa:ondrej/php -y
apt update

# Cài đặt PHP và extensions
apt install php8.3-fpm php8.3-mysql php8.3-curl php8.3-gd php8.3-mbstring \
            php8.3-xml php8.3-xmlrpc php8.3-soap php8.3-intl php8.3-zip \
            php8.3-bcmath php8.3-imagick php8.3-cli -y

# Enable và start PHP-FPM
systemctl enable php8.3-fpm
systemctl start php8.3-fpm
```

### 4. Cài đặt MariaDB

```bash
apt install mariadb-server -y
systemctl enable mariadb
systemctl start mariadb

# Bảo mật MySQL
mysql_secure_installation
```

Trả lời các câu hỏi:
- Enter current password for root: (Nhấn Enter)
- Set root password? [Y/n]: Y
- Nhập mật khẩu mới
- Remove anonymous users? [Y/n]: Y
- Disallow root login remotely? [Y/n]: Y
- Remove test database? [Y/n]: Y
- Reload privilege tables now? [Y/n]: Y

### 5. Cài đặt Certbot (cho SSL)

```bash
apt install certbot python3-certbot-nginx -y
```

## Cài đặt Script

### 1. Download script

```bash
cd /opt
git clone https://github.com/yourusername/minhminhscript.git
# Hoặc upload từ máy local
```

### 2. Cấp quyền

```bash
cd /opt/minhminhscript
chmod +x wpminhminhscript
chmod +x lib/common.sh
find modules -name "*.sh" -exec chmod +x {} \;
```

### 3. Tạo symlink

```bash
ln -s /opt/minhminhscript/wpminhminhscript /usr/local/bin/wpminhminhscript
```

### 4. Tạo thư mục cần thiết

```bash
mkdir -p /var/www
mkdir -p /var/backups/wordpress
mkdir -p /opt/minhminhscript/logs
```

## Cấu hình Nginx

### 1. Xóa site mặc định

```bash
rm /etc/nginx/sites-enabled/default
```

### 2. Tối ưu Nginx

Chỉnh sửa `/etc/nginx/nginx.conf`:

```nginx
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 64M;

    # MIME
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml font/truetype font/opentype
               application/vnd.ms-fontobject image/svg+xml;

    # Rate limiting for wp-login
    limit_req_zone $binary_remote_addr zone=login:10m rate=2r/m;

    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

### 3. Tạo SSL params

Tạo file `/etc/nginx/snippets/ssl-params.conf`:

```nginx
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;

# HSTS
add_header Strict-Transport-Security "max-age=63072000" always;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
```

### 4. Reload Nginx

```bash
nginx -t
systemctl reload nginx
```

## Cấu hình PHP

### 1. Tối ưu php.ini

Chỉnh sửa `/etc/php/8.3/fpm/php.ini`:

```ini
memory_limit = 256M
max_execution_time = 300
max_input_time = 300
upload_max_filesize = 64M
post_max_size = 64M
max_input_vars = 3000

# OPcache
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
```

### 2. Xóa pool mặc định www

```bash
mv /etc/php/8.3/fpm/pool.d/www.conf /etc/php/8.3/fpm/pool.d/www.conf.bak
```

### 3. Reload PHP-FPM

```bash
systemctl reload php8.3-fpm
```

## Cấu hình MariaDB

Chỉnh sửa `/etc/mysql/mariadb.conf.d/50-server.cnf`:

```ini
[mysqld]
# Basic Settings
max_connections = 50
connect_timeout = 5
wait_timeout = 600
max_allowed_packet = 64M
thread_cache_size = 128
sort_buffer_size = 4M
bulk_insert_buffer_size = 16M
tmp_table_size = 32M
max_heap_table_size = 32M

# Query Cache
query_cache_limit = 2M
query_cache_size = 64M
query_cache_type = 1

# InnoDB Settings
innodb_buffer_pool_size = 512M  # 50-70% of RAM
innodb_log_file_size = 64M
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT
innodb_flush_log_at_trx_commit = 2
```

Restart MariaDB:

```bash
systemctl restart mariadb
```

## Cấu hình Firewall (UFW)

```bash
# Cài đặt UFW
apt install ufw -y

# Cho phép SSH, HTTP, HTTPS
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw --force enable

# Kiểm tra status
ufw status
```

## Cấu hình Fail2Ban (Tùy chọn)

```bash
# Cài đặt
apt install fail2ban -y

# Tạo file cấu hình
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
action = iptables-multiport[name=ReqLimit, port="http,https", protocol=tcp]
logpath = /var/log/nginx/*error.log
findtime = 600
bantime = 7200
maxretry = 10
EOF

# Restart Fail2Ban
systemctl restart fail2ban
systemctl enable fail2ban
```

## Lưu mật khẩu MySQL root

```bash
# Tạo file lưu mật khẩu
mkdir -p /opt/minhminhscript/config
echo "YOUR_MYSQL_ROOT_PASSWORD" > /opt/minhminhscript/config/.mysql_root
chmod 600 /opt/minhminhscript/config/.mysql_root
```

## Kiểm tra cài đặt

```bash
# Chạy script
wpminhminhscript

# Chọn: 6. Cài đặt & Cấu hình -> 1. Kiểm tra yêu cầu hệ thống
```

## Thêm site đầu tiên

```bash
wpminhminhscript

# Chọn: 1. Quản lý Sites -> 1. Thêm site mới
# Nhập domain: example.com
```

Script sẽ tự động:
1. Tạo system user
2. Tạo site directory
3. Tạo database và user
4. Tạo PHP-FPM pool riêng
5. Tạo Nginx vhost
6. Cài đặt WordPress

## Cài đặt SSL

```bash
wpminhminhscript

# Chọn: 1. Quản lý Sites -> 5. Cài đặt SSL
# Nhập domain: example.com
# Nhập site name: example_com
```

## Setup Auto Backup

```bash
wpminhminhscript

# Chọn: 4. Backup & Restore -> 6. Cài đặt auto backup
# Chọn lịch: 1. Daily (hàng ngày)
```

## Cài đặt Redis (Tùy chọn)

```bash
wpminhminhscript

# Chọn: 3. Quản lý Cache -> 5. Cài đặt Redis
```

Sau đó cài plugin Redis Object Cache trong WordPress:
1. Vào WordPress Admin
2. Plugins -> Add New
3. Tìm "Redis Object Cache"
4. Install và Activate
5. Settings -> Redis -> Enable Object Cache

## Monitoring

Để giám sát hệ thống:

```bash
wpminhminhscript

# Chọn: 5. Giám sát Hệ thống
```

Các tùy chọn:
- Tài nguyên hệ thống
- Trạng thái dịch vụ
- PHP-FPM pools
- Dung lượng sites/databases
- Giám sát real-time

## Troubleshooting

### Lỗi: "Script này cần chạy với quyền root"

```bash
sudo su
wpminhminhscript
```

### Lỗi: "Thiếu các gói cần thiết"

```bash
# Cài đặt lại các gói
apt install nginx php8.3-fpm mariadb-server -y
```

### Lỗi: Permission denied

```bash
# Cấp lại quyền
chmod +x /opt/minhminhscript/wpminhminhscript
chmod +x /opt/minhminhscript/lib/common.sh
```

### Website không truy cập được

```bash
# Kiểm tra Nginx
nginx -t
systemctl status nginx

# Kiểm tra PHP-FPM
systemctl status php8.3-fpm

# Xem logs
tail -f /var/log/nginx/error.log
```

## Gỡ cài đặt (Uninstall)

**Cảnh báo**: Hành động này sẽ xóa tất cả!

```bash
# Xóa tất cả sites (từng site một)
wpminhminhscript
# Chọn: 1. Quản lý Sites -> 2. Xóa site

# Xóa script
rm -rf /opt/minhminhscript
rm /usr/local/bin/wpminhminhscript

# Xóa backups
rm -rf /var/backups/wordpress
```

## Cập nhật Script

```bash
cd /opt/minhminhscript
git pull origin main

# Hoặc download version mới và ghi đè
```

## Hỗ trợ

Nếu gặp vấn đề trong quá trình cài đặt:
- Đọc kỹ error message
- Kiểm tra logs: `/opt/minhminhscript/logs/wpminhminhscript.log`
- Kiểm tra system logs: `/var/log/nginx/`, `/var/log/php-fpm/`
- Tạo issue trên GitHub

## Bước tiếp theo

Sau khi cài đặt xong:
1. Đọc [README.md](README.md) để biết cách sử dụng
2. Thêm sites của bạn
3. Setup auto backup
4. Cài đặt SSL cho các sites
5. Theo dõi monitoring
