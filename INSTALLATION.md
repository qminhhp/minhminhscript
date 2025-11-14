# Hướng Dẫn Cài Đặt WP Minhminh Script

## 📋 Yêu Cầu Hệ Thống

### VPS Tối Thiểu:
- **OS**: Ubuntu 20.04/22.04 hoặc Debian 11/12
- **RAM**: 2GB (khuyến nghị 4GB+)
- **CPU**: 1 vCore (khuyến nghị 2+ vCores)
- **Disk**: 20GB (khuyến nghị 40GB+)
- **Quyền**: Root access

### Phần mềm cần có:
- Git
- Curl/Wget
- Bash shell

---

## 🚀 Phương Pháp 1: Cài Đặt Tự Động (Khuyến Nghị)

### Bước 1: Kết nối VPS qua SSH

```bash
ssh root@<IP_VPS_CUA_BAN>
```

### Bước 2: Chạy lệnh cài đặt tự động

```bash
curl -sL https://raw.githubusercontent.com/qminhhp/minhminhscript/main/install.sh | bash
```

**Hoặc dùng wget:**
```bash
wget -qO- https://raw.githubusercontent.com/qminhhp/minhminhscript/main/install.sh | bash
```

### Bước 3: Chờ script cài đặt hoàn tất

Script sẽ tự động:
- Cài đặt các gói phụ thuộc
- Clone repository từ GitHub
- Tạo các thư mục cần thiết
- Cài đặt WP-CLI
- Tạo symlink `/usr/local/bin/wpminhminhscript`

### Bước 4: Chạy script

```bash
wpminhminhscript
```

---

## 🛠️ Phương Pháp 2: Cài Đặt Thủ Công

### Bước 1: Cập nhật hệ thống

```bash
apt update && apt upgrade -y
```

### Bước 2: Cài đặt các gói cần thiết

```bash
apt install -y curl wget git unzip sudo nginx mariadb-server \
  php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-mbstring \
  php8.1-xml php8.1-xmlrpc php8.1-soap php8.1-intl php8.1-zip \
  certbot python3-certbot-nginx
```

**Lưu ý**: Thay `php8.1` bằng version PHP bạn muốn (7.4, 8.0, 8.1, 8.2, 8.3)

### Bước 3: Clone repository

```bash
cd /opt
git clone https://github.com/qminhhp/minhminhscript.git wpminhminhscript
cd wpminhminhscript
```

### Bước 4: Phân quyền executable

```bash
chmod +x wpminhminhscript
```

### Bước 5: Tạo symlink

```bash
ln -s /opt/wpminhminhscript/wpminhminhscript /usr/local/bin/wpminhminhscript
```

### Bước 6: Tạo các thư mục cần thiết

```bash
mkdir -p /var/log/wpminhminhscript
mkdir -p /var/backups/wpminhminhscript
mkdir -p /etc/wpminhminhscript
```

### Bước 7: Cài đặt WP-CLI

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp
```

### Bước 8: Cấu hình MariaDB

```bash
mysql_secure_installation
```

Trả lời các câu hỏi:
- Set root password: **Y** (đặt password mạnh)
- Remove anonymous users: **Y**
- Disallow root login remotely: **Y**
- Remove test database: **Y**
- Reload privilege tables: **Y**

### Bước 9: Khởi động các dịch vụ

```bash
systemctl enable nginx mariadb php8.1-fpm
systemctl start nginx mariadb php8.1-fpm
```

### Bước 10: Chạy script

```bash
wpminhminhscript
```

---

## 🎯 Cài Đặt Từ Development Branch

Nếu bạn muốn cài đặt từ branch development:

```bash
cd /opt
git clone -b claude/vps-wordpress-management-script-011CV63HHAiT1yQs5Zo7Lx54 \
  https://github.com/qminhhp/minhminhscript.git wpminhminhscript
cd wpminhminhscript
chmod +x wpminhminhscript
ln -s /opt/wpminhminhscript/wpminhminhscript /usr/local/bin/wpminhminhscript
```

---

## ✅ Kiểm Tra Cài Đặt

### 1. Kiểm tra script đã cài đặt chưa:

```bash
which wpminhminhscript
# Output: /usr/local/bin/wpminhminhscript
```

### 2. Kiểm tra version:

```bash
wpminhminhscript help
```

### 3. Kiểm tra các dịch vụ:

```bash
systemctl status nginx
systemctl status mariadb
systemctl status php8.1-fpm
```

Tất cả phải có trạng thái **active (running)**.

---

## 🔧 Cấu Hình Sau Khi Cài Đặt

### 1. Mở menu chính:

```bash
wpminhminhscript
```

### 2. Chọn: `10. Cài đặt & Cấu hình`

### 3. Chọn: `1. Kiểm tra yêu cầu hệ thống`

Script sẽ kiểm tra:
- ✓ Nginx
- ✓ PHP-FPM
- ✓ MariaDB
- ✓ WP-CLI
- ✓ Certbot
- ✓ Các PHP extensions

### 4. Cấu hình Firewall (tùy chọn):

```bash
wpminhminhscript → 7. Bảo Mật → Firewall
```

Mở các ports cần thiết:
- **80** (HTTP)
- **443** (HTTPS)
- **22** (SSH)

---

## 📝 Thêm WordPress Site Đầu Tiên

### 1. Mở menu:

```bash
wpminhminhscript
```

### 2. Chọn: `1. Quản lý Sites`

### 3. Chọn: `1. Thêm site mới`

### 4. Nhập thông tin:

```
Domain: example.com
Site name: example_com
Database name: example_db
Database user: example_user
Database password: <tự động generate>
```

### 5. Cài đặt SSL:

```bash
wpminhminhscript → 1. Quản lý Sites → 5. Cài đặt SSL
Domain: example.com
```

### 6. Truy cập website:

```
https://example.com
```

---

## 🐳 Cài Đặt Docker (Cho n8n)

Nếu bạn muốn sử dụng n8n workflow automation:

### 1. Mở menu:

```bash
wpminhminhscript
```

### 2. Chọn: `11. n8n Workflow Automation`

### 3. Chọn: `10. Cài đặt/Cập nhật Docker`

Script sẽ tự động cài Docker và Docker Compose.

---

## 🔐 Bảo Mật VPS

### 1. Đổi SSH Port (khuyến nghị):

```bash
nano /etc/ssh/sshd_config
# Đổi Port 22 thành Port 2222 (hoặc số khác)
systemctl restart sshd
```

### 2. Cài đặt Fail2ban:

```bash
wpminhminhscript → 7. Bảo Mật → Fail2ban
```

### 3. Cấu hình Firewall:

```bash
wpminhminhscript → 7. Bảo Mật → Firewall
```

---

## 📊 Cấu Trúc Thư Mục

Sau khi cài đặt:

```
/opt/wpminhminhscript/          # Script directory
├── wpminhminhscript            # Main executable
├── modules/                    # Feature modules
├── templates/                  # Config templates
├── lib/                        # Common libraries
└── config/                     # Configuration files

/var/www/                       # WordPress sites
├── site1/                      # Site 1 files
├── site2/                      # Site 2 files
└── ...

/var/lib/n8n/                   # n8n instances data
├── instance1/                  # n8n instance 1
└── instance2/                  # n8n instance 2

/var/backups/wpminhminhscript/  # Backups
├── wordpress/                  # WordPress backups
└── n8n/                        # n8n backups

/var/log/wpminhminhscript/      # Logs

/etc/wpminhminhscript/          # System config
└── default.conf

/opt/n8n-instances/             # n8n Docker Compose files
├── instance1/
│   └── docker-compose.yml
└── instance2/
    └── docker-compose.yml
```

---

## 🔄 Cập Nhật Script

### Cập nhật lên version mới nhất:

```bash
cd /opt/wpminhminhscript
git pull origin main
```

### Cập nhật từ development branch:

```bash
cd /opt/wpminhminhscript
git pull origin claude/vps-wordpress-management-script-011CV63HHAiT1yQs5Zo7Lx54
```

---

## 🆘 Gỡ Lỗi

### Script không chạy được:

```bash
# Kiểm tra quyền
ls -la /opt/wpminhminhscript/wpminhminhscript

# Phân quyền lại nếu cần
chmod +x /opt/wpminhminhscript/wpminhminhscript
```

### Nginx không start:

```bash
# Kiểm tra cấu hình
nginx -t

# Xem logs
tail -f /var/log/nginx/error.log
```

### PHP-FPM không hoạt động:

```bash
# Kiểm tra status
systemctl status php8.1-fpm

# Xem logs
tail -f /var/log/php8.1-fpm.log
```

### MySQL/MariaDB không kết nối:

```bash
# Kiểm tra status
systemctl status mariadb

# Kết nối thử
mysql -u root -p
```

---

## 📞 Hỗ Trợ

- **Issues**: https://github.com/qminhhp/minhminhscript/issues
- **Documentation**: https://github.com/qminhhp/minhminhscript
- **Email**: support@example.com

---

## 📄 License

MIT License - See LICENSE file for details

---

## 🎉 Hoàn Tất!

Script đã sẵn sàng sử dụng. Chạy `wpminhminhscript` để bắt đầu!

**Các bước tiếp theo:**
1. Thêm WordPress site đầu tiên
2. Cài đặt SSL
3. Setup backup tự động
4. (Optional) Cài đặt n8n automation
5. (Optional) Setup monitoring & alerts

Happy coding! 🚀
