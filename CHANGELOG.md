# Changelog

Tất cả thay đổi quan trọng của WP Minhminh Script sẽ được ghi lại trong file này.

## [1.0.0] - 2025-11-14

### Added
- 🎉 Phiên bản đầu tiên của WP Minhminh Script
- ✨ Quản lý nhiều WordPress sites với PHP-FPM pools riêng biệt
- 🔐 Tự động tạo system users và database users cho mỗi site
- 🌐 Tự động cấu hình Nginx vhosts với best practices
- 🔒 Tích hợp Let's Encrypt SSL tự động
- 💾 Hệ thống backup và restore đầy đủ
- 📦 Chức năng clone sites
- 🚀 Migration VPS và transfer sites giữa các servers
- 🔄 Tích hợp n8n workflow automation
- 🐳 Hỗ trợ Docker cho n8n instances
- 🔧 Quản lý PHP-FPM pools với monitoring
- 📊 Giám sát tài nguyên hệ thống
- 🔥 Cache management (Redis, Memcached)
- 🛡️ Security features (Firewall, Fail2ban, Rate limiting)
- 📝 Log rotation và management
- 🌍 Domain management với DNS tools
- 🔄 Auto-update system với version checking

### Supported OS
- ✅ Ubuntu 20.04+
- ✅ Debian 11+
- ✅ AlmaLinux 9+
- ✅ Rocky Linux 9+
- ✅ RHEL 9+

### Features
- **WordPress Management**: Cài đặt, xóa, sửa, clone sites
- **PHP-FPM Isolation**: Mỗi site chạy trên pool riêng với user riêng
- **Nginx Configuration**: Auto-generate vhosts với SSL
- **Database Management**: Tạo/xóa database, user, backup/restore
- **SSL/TLS**: Let's Encrypt integration với auto-renewal
- **Backup System**: Full backup, incremental backup, scheduled backups
- **Migration Tools**: Transfer sites giữa VPSs, full VPS migration
- **n8n Integration**: Deploy n8n instances với reverse proxy
- **Cache Management**: Redis, Memcached, OPcache configuration
- **Security**: Firewall rules, Fail2ban, rate limiting, security headers
- **Monitoring**: Resource monitoring, error log tracking
- **Auto Updates**: Built-in update system với changelog

### Technical Details
- Script directory: `/opt/wpminhminhscript`
- Config directory: `/etc/wpminhminhscript`
- Log directory: `/var/log/wpminhminhscript`
- Backup directory: `/var/backups/wpminhminhscript`
- Sites directory: `/var/www` (configurable)

### Installation
```bash
curl -sL https://raw.githubusercontent.com/qminhhp/minhminhscript/main/install.sh | AUTO_INSTALL=yes bash
```

### Requirements
- Linux VPS (Ubuntu/Debian/AlmaLinux/Rocky/RHEL)
- Root access
- Minimum 1GB RAM
- 10GB disk space
- Internet connection

### Known Issues
- None reported yet

---

## Version Format

Dự án sử dụng [Semantic Versioning](https://semver.org/):
- MAJOR: Thay đổi không tương thích ngược
- MINOR: Thêm tính năng mới (tương thích ngược)
- PATCH: Bug fixes (tương thích ngược)

Example: 1.0.0
- 1 = Major version
- 0 = Minor version
- 0 = Patch version
