# 田小瑞一键脚本 v1.0.1

![Script Version](https://img.shields.io/badge/version-1.0.1-blue.svg)
![Bash](https://img.shields.io/badge/bash-4.0+-green.svg)
![Linux](https://img.shields.io/badge/linux-supported-orange.svg)

一个功能强大的Linux服务器管理系统脚本，提供一站式的服务器运维解决方案。

### ✨ 脚本特点
- 🔧 **25+功能模块** - 从基础优化到高级管理
- 🐳 **Docker完整支持** - 安装、配置、维护一站式
- 🗄️ **数据库管理** - MySQL/PostgreSQL备份恢复
- 🛡️ **安全防护** - Fail2Ban、SSL证书、SSH管理
- 🚀 **网络加速** - GitHub加速、NTP同步、ICMP控制
- 📦 **一键安装** - 各种面板和工具的快速部署

## ⚡ 一键运行

想要立即体验？使用这个一键命令：
```bash
curl -fsSL https://raw.githubusercontent.com/txrui/script/refs/heads/main/txrui.sh | sudo bash
```

## 🚀 快速开始

### 下载和运行

#### 一键运行命令（推荐）
```bash
# 一键下载并运行（自动获取权限）
curl -fsSL https://raw.githubusercontent.com/txrui/script/refs/heads/main/txrui.sh | sudo bash
```

> **注意**: 一键运行命令会自动下载并执行脚本，适合快速测试。如果您需要保留脚本文件以便后续使用，请使用手动下载方式。

#### 手动下载方式
```bash
# 下载脚本
wget -O txrui.sh https://raw.githubusercontent.com/txrui/script/refs/heads/main/txrui.sh

# 赋予执行权限
chmod +x txrui.sh

# 运行脚本（需要root权限）
sudo ./txrui.sh
```

### 系统要求
- **操作系统**: Linux (Debian/Ubuntu/RHEL/CentOS/AlmaLinux/Rocky/Fedora/openSUSE/Arch)
- **权限**: Root用户
- **网络**: 需要互联网连接（用于下载和更新）

## 📋 功能总览

### 🏗️ 系统优化
- **1)** 虚拟内存管理 - 添加/删除/自动挂载虚拟内存
- **2)** 镜像源管理 - 支持10+镜像源，覆盖9个Linux发行版
- **3)** BBR管理 - 启用BBR拥塞控制算法
- **4)** BBR优化 - 应用完整的TCP优化参数

### 📦 应用安装
- **5)** 流媒体测试 - 测试Netflix/HBO等流媒体解锁
- **6)** 宝塔面板 - 一键安装宝塔Linux管理面板
- **7)** DPanel面板 - 安装DPanel管理面板
- **8)** 服务器详细信息 - 全面的系统和网络信息

### 🧹 系统维护
- **9)** 一键清理 - 清理缓存、日志、临时文件、Docker等
- **10)** 系统管理 - 防火墙、时区、语言、Hosts等设置

### 📥 下载工具
- **11)** 系统默认QB - 安装系统仓库的qBittorrent
- **12)** 选择安装QB - 选择版本安装qBittorrent (v4.6.3-v5.1.4)

### 👁️ 监控工具
- **13)** ServerStatus客户端 - 连接监控服务器
- **14)** ServerStatus服务端 - 搭建监控服务端

## 🆕 新增功能 (v1.0.1)

### 🐳 系统工具
- **15)** Docker管理 - 安装/卸载/维护/加速源配置
- **16)** 数据库管理 - MySQL/PostgreSQL备份恢复
- **17)** Python环境管理 - 安装/升级/配置/维护

### 🛡️ 安全工具
- **18)** Fail2Ban管理 - SSH暴力破解防护
- **19)** SSL证书助手 - Let's Encrypt证书管理

### 🌐 网络增强
- **20)** GitHub加速 - Hosts/代理/镜像加速
- **21)** SSH端口修改 - 自定义SSH端口和防火墙配置
- **22)** ICMP响应控制 - 开启/关闭ping响应
- **23)** NTP时间同步 - 时间同步和NTP服务器配置

### 🏠 面板工具
- **24)** CasaOS面板 - 家庭云系统面板

### 🔄 系统更新
- **25)** 脚本自更新 - 自动检查和更新脚本

## 🎯 详细功能说明

### Docker管理
- ✅ 安装/卸载Docker CE
- ✅ 服务启动/停止/重启
- ✅ 配置加速源 (阿里云/腾讯云/华为云)
- ✅ 容器镜像清理
- ✅ 系统资源监控

### 数据库管理
- ✅ MySQL/MariaDB 安装卸载
- ✅ PostgreSQL 安装卸载
- ✅ 全库/单库备份
- ✅ 数据恢复
- ✅ 状态监控

### Python环境管理
- ✅ Python2/3 安装管理
- ✅ pip 升级和配置
- ✅ 清华大学pip源配置
- ✅ 包缓存清理
- ✅ 已安装包查看

### 安全防护
- ✅ Fail2Ban SSH防护配置
- ✅ IP封禁列表管理
- ✅ SSL证书自动化申请
- ✅ 证书续签管理

### 网络优化
- ✅ GitHub访问加速
- ✅ SSH端口安全修改
- ✅ ICMP响应控制
- ✅ NTP时间同步

## 🖥️ 支持的系统

| 发行版 | 版本 | 包管理器 | 测试状态 |
|--------|------|----------|----------|
| Debian | 11/12 | APT | ✅ 完全支持 |
| Ubuntu | 18.04-24.04 | APT | ✅ 完全支持 |
| CentOS | 7/8 | YUM | ✅ 完全支持 |
| AlmaLinux | 8/9 | DNF | ✅ 完全支持 |
| Rocky Linux | 8/9 | DNF | ✅ 完全支持 |
| RHEL | 7/8/9 | YUM/DNF | ✅ 完全支持 |
| Fedora | 35+ | DNF | ✅ 完全支持 |
| openSUSE | Leap | Zypper | ✅ 完全支持 |
| Arch Linux | 最新 | Pacman | ✅ 完全支持 |

## 📖 使用指南

### 基本使用
```bash
# 运行脚本
sudo ./txrui.sh

# 选择功能编号
# 按提示操作即可
```

### 常用功能示例

#### Docker管理
```bash
# 选择 15) Docker管理
# 1) 安装Docker -> 自动安装并配置
# 7) 配置加速源 -> 选择阿里云加速
```

#### qBittorrent安装
```bash
# 选择 12) 选择安装版本QB
# 1) v5.1.4 (最新推荐) -> 安装最新稳定版
```

#### 系统清理
```bash
# 选择 9) 一键清理日志和缓存
# 自动清理所有类型的缓存和垃圾文件
```

### 高级配置

#### 自定义镜像源
```bash
# 2) 镜像源管理
# 选择发行版和镜像源类型
# 支持阿里云/腾讯云/华为云等
```

#### SSH安全配置
```bash
# 21) SSH端口修改 -> 自定义SSH端口
# 18) Fail2Ban管理 -> 配置SSH防护
```

## ⚠️ 注意事项

### 安全提醒
- 🔴 **重要**: 首次使用请仔细阅读每个选项的说明
- 🔴 **备份**: 重要操作前会自动备份，但建议手动备份重要数据
- 🔴 **权限**: 部分操作需要root权限，请谨慎使用

### 使用建议
- 📋 **测试环境**: 建议在测试环境先熟悉功能
- 📋 **网络连接**: 确保网络连接稳定，特别是下载操作
- 📋 **系统兼容**: 使用支持的系统版本获得最佳体验

### 已知限制
- 🚫 **不支持**: Windows/macOS系统
- 🚫 **需要root**: 必须使用root用户运行
- 🚫 **网络依赖**: 部分功能需要互联网连接

## 🐛 故障排除

### 常见问题

#### 脚本无法运行
```bash
# 检查权限
ls -la txrui.sh
chmod +x txrui.sh

# 检查bash版本
bash --version
```

#### Docker安装失败
```bash
# 检查系统版本
cat /etc/os-release

# 检查网络连接
ping -c 3 get.docker.com
```

#### 镜像源配置失败
```bash
# 检查DNS配置
cat /etc/resolv.conf

# 测试网络连接
curl -I https://mirrors.aliyun.com
```

## 🤝 贡献指南

### 开发环境
```bash
# Fork项目
# 创建特性分支
git checkout -b feature/new-function

# 提交更改
git commit -m "Add new function"

# 推送分支
git push origin feature/new-function

# 创建Pull Request
```

### 代码规范
- 🔧 使用Bash最佳实践
- 📝 添加详细注释
- 🧪 测试功能兼容性
- 📋 更新README文档

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

## 📞 联系我们

- 📧 **邮箱**: sytruix@gmail.com
- 🐛 **Issues**: [GitHub Issues](https://github.com/sytruix/script/issues)
- 💬 **讨论**: [GitHub Discussions](https://github.com/sytruix/script/discussions)

## 📈 更新日志

### v1.0.1 (最新)
- ✨ 新增11个高级功能模块
- 🐳 完整的Docker管理套件
- 🗄️ 数据库备份恢复功能
- 🐍 Python环境管理
- 🛡️ Fail2Ban安全防护
- 🔐 SSL证书自动化管理
- 🚀 GitHub访问加速
- 📡 网络工具增强

### v1.0.0
- 🎯 核心服务器管理功能
- 📦 基本的应用安装
- 🧹 系统清理功能
- 🌐 镜像源管理
- 👁️ 监控工具集成

## 🙏 致谢

感谢所有为这个项目贡献代码和建议的开发者！

---

**⭐ 如果这个脚本对你有帮助，请给它一个Star！**
