#!/bin/bash
#==============================================
# 田小瑞一键脚本 v1.3 - 手动空格对齐版
#==============================================

# ---------- 公共函数 ----------
ok()    { echo -e "\033[32m[✔] $1\033[0m"; }
warn()  { echo -e "\033[33m[!] $1\033[0m"; }
error() { echo -e "\033[31m[✘] $1\033[0m"; }

# ---------- 虚拟内存管理 ----------
manage_swap_menu() {
  while true; do
    clear
    echo "====== 虚拟内存管理 ======"
    echo "1) 查看当前虚拟内存"
    echo "2) 添加 1G 虚拟内存"
    echo "3) 添加 2G 虚拟内存"
    echo "4) 添加 4G 虚拟内存"
    echo "5) 添加 8G 虚拟内存"
    echo "6) 删除虚拟内存"
    echo "7) 开机自动挂载设置"
    echo "8) 自定义添加虚拟内存"
    echo "0) 返回主菜单"
    echo "========================="
    read -rp "请选择: " opt

    case "$opt" in
      1)
        echo ""
        swapon --show || echo "无激活的交换空间"
        echo ""
        read -rp "按回车返回..." ;;
      2) add_swap 1G ;;
      3) add_swap 2G ;;
      4) add_swap 4G ;;
      5) add_swap 8G ;;
      6)
    # 删除 /swapfile（用户自建 swap 文件）
    if [ -f /swapfile ]; then
        swapoff /swapfile 2>/dev/null
        rm -f /swapfile
        sed -i '/\/swapfile/d' /etc/fstab
        ok "已删除 /swapfile 虚拟内存"
    fi

    # 查找并处理系统默认 swap 分区或 swap 文件
    swapon --show=NAME --noheadings | while read -r swapdev; do
        swapoff "$swapdev" 2>/dev/null
        # 如果是文件，直接删除
        if [ -f "$swapdev" ]; then
            rm -f "$swapdev"
            ok "已删除 swap 文件: $swapdev"
        fi
        # 如果是分区，提示用户是否删除
        if [[ "$swapdev" =~ ^/dev/ ]]; then
            read -rp "检测到 swap 分区 $swapdev。是否删除该分区? [y/N]: " yn
            yn=${yn:-y}  # 默认回车自动删除
            if [[ "$yn" =~ ^[Yy]$ ]]; then
                # 删除分区（用 sfdisk 清空分区表）
                echo "正在删除分区 $swapdev ..."
                parted "$swapdev" rm 1 >/dev/null 2>&1
                ok "已删除 swap 分区 $swapdev"
            else
                ok "保留 swap 分区 $swapdev"
            fi
        fi
        # 清理 /etc/fstab 中对应 swap 行
        sed -i "\|$swapdev|d" /etc/fstab
    done

    read -rp "按回车返回..." ;;

      7)
        grep -q '/swapfile' /etc/fstab && ok "已设置自动挂载" || warn "未检测到自动挂载"
        read -rp "按回车返回..." ;;
      8)
        read -rp "请输入虚拟内存大小（如 512M 或 3G）: " custom_size
        if [[ ! $custom_size =~ ^[0-9]+[MmGg]$ ]]; then
          error "输入格式错误，请输入如 512M 或 2G"
          sleep 1
        else
          add_swap "$custom_size"
        fi ;;
      0) return ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}

# ---------- 添加虚拟内存函数 ----------
add_swap() {
  size="$1"
  if [ -f /swapfile ]; then
    warn "检测到已有 swapfile，请先删除再添加"
    read -rp "按回车返回..."
    return
  fi

  echo "正在创建 ${size} 虚拟内存..."
  fallocate -l "$size" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=$(( ${size//[!0-9]/} * (${size,,} =~ g ? 1024 : 1) )) status=progress
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  if ! grep -q '/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
  ok "已成功添加 ${size} 虚拟内存并启用"
  read -rp "按回车返回..."
}

# ---------- 镜像源管理 ----------
# Debian apt源管理脚本
set -e

APT_DIR="/etc/apt"
BACKUP_DIR="/root"
DATE=$(date +%Y%m%d_%H%M%S)

get_debian_version(){
    if [ -f /etc/debian_version ]; then
        version=$(cut -d'.' -f1 /etc/debian_version)
        if [[ "$version" == "11" ]]; then
            echo "11"
        elif [[ "$version" == "12" ]]; then
            echo "12"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

official_sources(){
    local ver=$1
    if [[ "$ver" == "11" ]]; then
        cat <<EOF
deb http://deb.debian.org/debian bullseye main contrib non-free
deb-src http://deb.debian.org/debian bullseye main contrib non-free

deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free

deb http://security.debian.org/debian-security bullseye-security main contrib non-free
deb-src http://security.debian.org/debian-security bullseye-security main contrib non-free
EOF
    elif [[ "$ver" == "12" ]]; then
        cat <<EOF
deb http://deb.debian.org/debian bookworm main contrib non-free
deb-src http://deb.debian.org/debian bookworm main contrib non-free

deb http://deb.debian.org/debian bookworm-updates main contrib non-free
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free

deb http://security.debian.org/debian-security bookworm-security main contrib non-free
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free
EOF
    else
        echo ""
    fi
}

aliyun_sources(){
    local ver=$1
    if [[ "$ver" == "11" ]]; then
        cat <<EOF
deb http://mirrors.aliyun.com/debian/ bullseye main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bullseye main contrib non-free

deb http://mirrors.aliyun.com/debian/ bullseye-updates main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bullseye-updates main contrib non-free

deb http://mirrors.aliyun.com/debian-security bullseye-security main contrib non-free
deb-src http://mirrors.aliyun.com/debian-security bullseye-security main contrib non-free
EOF
    elif [[ "$ver" == "12" ]]; then
        cat <<EOF
deb http://mirrors.aliyun.com/debian/ bookworm main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bookworm main contrib non-free

deb http://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free

deb http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free
deb-src http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free
EOF
    else
        echo ""
    fi
}

backup_apt(){
    echo "✅ 开始备份 $APT_DIR 到 $BACKUP_DIR/apt_backup_$DATE.tar.gz"
    tar czf "$BACKUP_DIR/apt_backup_$DATE.tar.gz" "$APT_DIR"
    echo "🎉 备份完成：$BACKUP_DIR/apt_backup_$DATE.tar.gz"
}

list_backups(){
    ls -1t $BACKUP_DIR/apt_backup_*.tar.gz 2>/dev/null || echo "无备份文件"
}

restore_backup(){
    echo "📦 可用备份列表："
    list_backups
    read -rp "请输入要恢复的备份文件全路径名（或输入 'cancel' 取消）: " backup_file
    if [[ "$backup_file" == "cancel" ]]; then
        echo "已取消恢复操作。"
        return 1
    fi
    if [[ ! -f "$backup_file" ]]; then
        echo "❌ 备份文件不存在：$backup_file"
        return 1
    fi
    echo "🔁 正在恢复备份..."
    sudo rm -rf $APT_DIR
    sudo mkdir -p $APT_DIR
    sudo tar xzf "$backup_file" -C /
    echo "✅ 恢复完成。"
    return 0
}

import_common_gpg_keys(){
    sudo mkdir -p /etc/apt/trusted.gpg.d
    local keys=( 0E98404D386FA1D9 6ED0E7B82643E131 605C66F00D6C9793 54404762BBB6E853 BDE6D2B9216EC7A8 )
    for key in "${keys[@]}"; do
        echo "🔑 导入公钥: $key"
        tmpdir=$(mktemp -d)
        if gpg --no-default-keyring --keyring "$tmpdir/temp.gpg" --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" >/dev/null 2>&1; then
            sudo gpg --no-default-keyring --keyring "$tmpdir/temp.gpg" --export "$key" | sudo tee "/etc/apt/trusted.gpg.d/${key}.gpg" >/dev/null
            echo "✅ 公钥 $key 导入成功"
        else
            echo "❌ 公钥 $key 导入失败"
        fi
        rm -rf "$tmpdir"
    done
}

write_sources(){
    local ver=$1
    local type=$2

    echo "🧹 删除旧的 $APT_DIR 目录..."
    sudo rm -rf $APT_DIR

    echo "📂 创建必要目录..."
    sudo mkdir -p $APT_DIR/apt.conf.d /etc/apt/preferences.d /etc/apt/trusted.gpg.d

    echo "📝 写入新的源配置..."
    if [[ "$type" == "official" ]]; then
        official_sources "$ver" | sudo tee $APT_DIR/sources.list >/dev/null
    elif [[ "$type" == "aliyun" ]]; then
        aliyun_sources "$ver" | sudo tee $APT_DIR/sources.list >/dev/null
    else
        echo "❌ 未知源类型：$type"
        return 1
    fi

    echo '# 默认apt配置' | sudo tee $APT_DIR/apt.conf.d/99custom >/dev/null
    echo 'Acquire::Retries "3";' | sudo tee -a $APT_DIR/apt.conf.d/99custom >/dev/null

    echo "🔧 导入常用 GPG 公钥..."
    import_common_gpg_keys

    echo "🔄 运行最终更新..."
    sudo apt-get update && sudo apt update

    echo "🎉 源更新成功！"
}
# ------------ 镜像源菜单 -----------------
manage_sources_menu() {
  while true; do
    clear
    echo "========================================"
    echo "           Debian apt源管理"
    echo "========================================"
    debver=$(get_debian_version)
    if [[ -z "$debver" ]]; then
      echo "❌ 无法检测到 Debian 版本，仅支持 Debian 11 和 12"
      read -p "按回车返回主菜单..."
      break
    fi
    echo "📦 当前系统：Debian $debver"
    echo ""
    echo "请选择操作："
    echo "1) 备份 /etc/apt         2) 恢复 /etc/apt 备份"
    echo "3) 使用 官方源           4) 使用 阿里云源"
    echo "5) 更新 APT 源          0) 返回主菜单"
    echo "----------------------------------------"
    read -rp "请输入选项: " choice

    case $choice in
      1) backup_apt; read -p "按回车继续..." ;;
      2) restore_backup && read -p "按回车继续..." ;;
      3) write_sources "$debver" official; read -p "按回车继续..." ;;
      4) write_sources "$debver" aliyun; read -p "按回车继续..." ;;
      5) echo "🔄 正在更新 apt 源..."; sudo apt-get update && sudo apt update; echo "✅ 更新完成"; read -p "按回车继续..." ;;
      0) break ;;
      *) echo "❗ 无效选项，请重新输入"; read -p "按回车继续..." ;;
    esac
  done
}

# ---------- BBR 管理 ----------
manage_bbr() {
  clear
  echo "====== BBR 管理 ======"
  echo "1) 启用 BBR"
  echo "2) 查看 BBR 状态"
  echo "0) 返回主菜单"
  echo "===================="
  read -rp "请选择: " opt
  case "$opt" in
    1)
      echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
      echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
      sysctl -p
      ok "BBR 已启用"
      read -rp "按回车返回..." ;;
    2)
      sysctl net.ipv4.tcp_congestion_control
      read -rp "按回车返回..." ;;
    0) return ;;
  esac
}

# ---------- BBR 优化 ----------
optimize_bbr() {
  clear
  echo "====== BBR 优化 ======"
  echo "正在优化 TCP 参数..."
  cat >> /etc/sysctl.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_rmem='4096 87380 67108864'
net.ipv4.tcp_wmem='4096 65536 67108864'
EOF
  sysctl -p
  ok "优化完成"
  read -rp "按回车返回..."
}

# ---------- 流媒体测试 ----------
streaming_test() {
  clear
  echo "====== 流媒体测试 ======"
  bash <(curl -sSL https://github.com/lmc999/RegionRestrictionCheck/raw/main/check.sh)
  read -rp "按回车返回..."
}

# ---------- 安装宝塔 ----------
install_bt_panel() {
  clear
  echo "====== 安装宝塔面板 ======"
  wget -O install.sh http://download.bt.cn/install/install-ubuntu_6.0.sh
  bash install.sh
  read -rp "按回车返回..."
}

# ---------- 安装 DPanel ----------
install_dpanel() {
  clear
  echo "====== 安装 DPanel 面板 ======"
  bash <(curl -sSL https://raw.githubusercontent.com/Dpanel-Server/DPanel/master/install.sh)
  read -rp "按回车返回..."
}

# ---------- 系统信息 ----------
system_info() {
  clear
  echo "====== 系统详细信息 ======"

  # 基本信息
  echo "主机名: $(hostname)"
  echo "系统版本: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
  echo "内核版本: $(uname -r)"
  echo "CPU 架构: $(uname -m)"
  echo "CPU 信息: $(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ *//')"
  echo "CPU 核心: $(nproc)"

  # 内存信息（用 MB/GB 显示）
  mem_used=$(free -m | awk '/Mem:/ {printf "%.1f", $3/1024}')
  mem_total=$(free -m | awk '/Mem:/ {printf "%.1f", $2/1024}')
  echo "内存使用: ${mem_used}GB / ${mem_total}GB"

  # 磁盘使用
  disk_used=$(df -h / | awk 'NR==2 {print $3}')
  disk_total=$(df -h / | awk 'NR==2 {print $2}')
  echo "磁盘使用: ${disk_used} / ${disk_total}"

  # ---------------- 交换空间 ----------------
	swap_used_mb=$(free -m | awk '/^Swap:/{print $3}')
	swap_total_mb=$(free -m | awk '/^Swap:/{print $2}')

	if [[ $swap_total_mb -eq 0 ]]; then
    echo "交换空间: 未启用"
	else
    if [[ $swap_total_mb -ge 1024 ]]; then
        swap_used=$(awk "BEGIN {printf \"%.1fG\", $swap_used_mb/1024}")
        swap_total=$(awk "BEGIN {printf \"%.1fG\", $swap_total_mb/1024}")
    else
        swap_used="${swap_used_mb}M"
        swap_total="${swap_total_mb}M"
    fi
    echo "交换空间: $swap_used / $swap_total"
	fi

  # 系统运行时间（中文显示）
  uptime_sec=$(awk '{print int($1)}' /proc/uptime)
  days=$((uptime_sec / 86400))
  hours=$(( (uptime_sec % 86400) / 3600 ))
  mins=$(( (uptime_sec % 3600) / 60 ))

  uptime_str="已运行 "
  ((days > 0)) && uptime_str+="${days}天 "
  ((hours > 0)) && uptime_str+="${hours}小时 "
  ((mins > 0)) && uptime_str+="${mins}分钟"
  echo "系统运行时间: $uptime_str"

  # 系统负载
  echo "系统负载: $(uptime | awk -F'load average:' '{print $2}')"

  # 公网 IP
  echo "公网 IP:"
  ips=$(get_public_ips)
  if [[ -z "$ips" ]]; then
    echo "无法获取公网 IP 或无公网接口"
  else
    echo "$ips"
  fi

  echo "====================="
  read -rp "按回车继续..."
}
# 获取公网 IPv4/IPv6 干净列表
get_public_ips() {
  local ipv4_sources=( "https://ipv4.ip.sb/ip" "https://ifconfig.me/ip" "https://api.ipify.org" "https://ipinfo.io/ip" "https://ident.me" )
  local ipv6_sources=( "https://ipv6.ip.sb/ip" "https://ifconfig.co/ip" "https://api64.ipify.org" )

  local -a ipv4_list ipv6_list
  local ip

  # IPv4
  for url in "${ipv4_sources[@]}"; do
    ip="$(curl -4 -s --max-time 3 "$url" 2>/dev/null || true)"
    ip="${ip%%[[:space:]]*}"
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      ipv4_list+=("$ip")
    fi
  done

  # IPv6
  for url in "${ipv6_sources[@]}"; do
    ip="$(curl -6 -s --max-time 3 "$url" 2>/dev/null || true)"
    ip="${ip%%[[:space:]]*}"
    if [[ $ip =~ ^[0-9a-fA-F:]+$ ]] && [[ ${#ip} -ge 5 ]]; then
      ipv6_list+=("$ip")
    fi
  done

  # 输出去重
  printf "%s\n" "${ipv4_list[@]}" "${ipv6_list[@]}" | sed '/^$/d' | sort -u
}

# ---------- 一键清理 ----------
clean_system() {
  clear
  echo "====== 一键清理 ======"
  apt autoremove -y
  apt autoclean -y
  journalctl --vacuum-time=3d
  ok "系统日志与缓存已清理"
  read -rp "按回车返回..."
}

# 一键开启/关闭服务器防火墙
manage_firewall() {
  while true; do
    clear
    echo "=================================="
    echo "         防火墙管理"

    # 检测可用防火墙
    if command -v ufw >/dev/null 2>&1; then
      fw_type="ufw"
      fw_name="UFW"
      fw_status=$(sudo ufw status | grep -i "Status" | awk '{print $2}')
      case "$fw_status" in
        inactive) status_text="未开启" ;;
        active) status_text="已开启" ;;
        *) status_text="未知状态" ;;
      esac
    elif command -v firewall-cmd >/dev/null 2>&1; then
      fw_type="firewalld"
      fw_name="Firewalld"
      if systemctl is-active --quiet firewalld; then
        status_text="已开启"
      else
        status_text="未开启"
      fi
    elif command -v iptables >/dev/null 2>&1; then
      fw_type="iptables"
      fw_name="iptables"
      status_text="请手动管理规则"
    else
      fw_type="none"
      fw_name="未安装防火墙"
      status_text="未安装"
    fi

    # 显示防火墙状态
    echo "防火墙类型: $fw_name  状态: $status_text"
    echo "=================================="

    echo "1) 开启防火墙 (永久生效)"
    echo "2) 关闭防火墙 (永久生效)"
    echo "3) 临时关闭防火墙 (不改变开机自启)"
    echo "4) 重启防火墙"
    echo "0) 返回上级菜单"
    read -rp "请输入选项: " choice

    case $choice in
      1)
        case $fw_type in
          ufw)
            sudo ufw enable
            sudo systemctl enable ufw
            ;;
          firewalld)
            sudo systemctl start firewalld
            sudo systemctl enable firewalld
            ;;
          iptables)
            echo "⚠ iptables 需自行添加规则并保存"
            ;;
          *)
            echo "❌ 未安装防火墙"
            ;;
        esac
        echo "✅ 防火墙已开启（永久）"
        read -p "按回车继续..."
        ;;
      2)
        case $fw_type in
          ufw)
            sudo ufw disable
            sudo systemctl disable ufw
            ;;
          firewalld)
            sudo systemctl stop firewalld
            sudo systemctl disable firewalld
            ;;
          iptables)
            echo "⚠ iptables 需自行清空规则并禁用自启"
            ;;
          *)
            echo "❌ 未安装防火墙"
            ;;
        esac
        echo "✅ 防火墙已关闭（永久）"
        read -p "按回车继续..."
        ;;
      3)
        case $fw_type in
          ufw)
            sudo ufw disable
            echo "⚠ 防火墙已临时关闭 (开机仍可能启动)"
            ;;
          firewalld)
            sudo systemctl stop firewalld
            echo "⚠ 防火墙已临时关闭 (开机仍可能启动)"
            ;;
          iptables)
            echo "⚠ iptables 需手动清空规则"
            ;;
          *)
            echo "❌ 未安装防火墙"
            ;;
        esac
        read -p "按回车继续..."
        ;;
      4)
        case $fw_type in
          ufw)
            sudo ufw disable
            sudo ufw enable
            ;;
          firewalld)
            sudo systemctl restart firewalld
            ;;
          iptables)
            echo "⚠ iptables 需手动重启规则"
            ;;
          *)
            echo "❌ 未安装防火墙"
            ;;
        esac
        echo "🔄 防火墙已重启"
        read -p "按回车继续..."
        ;;
      0)
        break
        ;;
      *)
        echo "❗ 无效选项"
        read -p "按回车继续..."
        ;;
    esac
  done
}

#修改系统时区
change_timezone() {
  while true; do
    clear
    current_tz=$(timedatectl | grep "Time zone" | awk '{print $3}')
    echo "=================================="
    echo "        系统时区管理"
    echo "        当前时区: $current_tz"
    echo "=================================="
    echo "1) 中国 (Asia/Shanghai)"
    echo "2) 日本 (Asia/Tokyo)"
    echo "3) 俄罗斯 (Europe/Moscow)"
    echo "4) 美国 (America/New_York)"
    echo "5) 香港 (Asia/Hong_Kong)"
    echo "6) 自定义时区"
    echo "0) 返回上级菜单"
    read -rp "请选择时区: " choice

    case $choice in
      1) tz="Asia/Shanghai" ;;
      2) tz="Asia/Tokyo" ;;
      3) tz="Europe/Moscow" ;;
      4) tz="America/New_York" ;;
      5) tz="Asia/Hong_Kong" ;;
      6)
        read -rp "请输入自定义时区 (如 Europe/London): " tz
        if ! timedatectl list-timezones | grep -q "^$tz$"; then
          echo "❌ 时区无效"
          read -p "按回车继续..."
          continue
        fi
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; read -p "按回车继续..." ; continue ;;
    esac

    sudo timedatectl set-timezone "$tz"
    echo "✅ 时区已修改为 $tz"
    read -p "按回车继续..."
    break
  done
}

#修改主机名
change_hostname() {
  current_hostname=$(hostname)
  echo "当前主机名: $current_hostname"
  read -rp "请输入新的主机名: " new_hostname
  if [ -n "$new_hostname" ]; then
    sudo hostnamectl set-hostname "$new_hostname"
    echo "✅ 主机名已修改为 $new_hostname"
    echo "请重启或重新登录以使更改生效"
  else
    echo "❌ 主机名不能为空"
  fi
  read -p "按回车继续..."
}
#修改 /etc/hosts
edit_hosts() {
  echo "⚠️ 正在编辑 /etc/hosts 文件，请确保格式正确"
  sudo nano /etc/hosts
}
#切换系统语言
change_language() {
  while true; do
    clear
    current_lang=$(locale | grep LANG= | cut -d= -f2)
    echo "=================================="
    echo "        系统语言管理"
    echo "        当前语言: $current_lang"
    echo "=================================="
    echo "1) 中文 (zh_CN.UTF-8)"
    echo "2) 英文 (en_US.UTF-8)"
    echo "3) 自定义语言"
    echo "0) 返回上级菜单"
    read -rp "请选择语言: " choice

    case $choice in
      1) lang="zh_CN.UTF-8" ;;
      2) lang="en_US.UTF-8" ;;
      3)
        read -rp "请输入自定义语言 (如 zh_HK.UTF-8): " lang
        if ! locale -a | grep -q "^$lang$"; then
          echo "❌ 语言无效或未安装"
          read -p "按回车继续..."
          continue
        fi
        ;;
      0) return ;;
      *) echo "❌ 无效选项"; read -p "按回车继续..." ; continue ;;
    esac

    sudo update-locale LANG="$lang"
    echo "✅ 系统语言已修改为 $lang"
    echo "请重启或重新登录以使更改生效"
    read -p "按回车继续..."
    break
  done
}

# ---------- 安装 qBittorrent ----------
install_qbittorrent() {
    CONFIG_DIR="/root/.config/qBittorrent"
    CONF_FILE="$CONFIG_DIR/qBittorrent.conf"

    echo "==== 更新系统 ===="
    apt update && apt upgrade -y
    apt install -y software-properties-common wget nano curl gnupg lsb-release

    echo "==== 安装 qBittorrent-nox ===="
    if [ -f /etc/lsb-release ]; then
        add-apt-repository ppa:qbittorrent-team/qbittorrent-stable -y
        apt update
    fi
    apt install -y qbittorrent-nox

    echo "==== 生成或修改配置文件 ===="
    mkdir -p $CONFIG_DIR

    # 判断是否已有配置文件
    if [ -f "$CONF_FILE" ]; then
        echo "已有配置文件，更新为完整自定义配置..."
    else
        echo "首次启动，生成配置文件..."
        qbittorrent-nox &
        sleep 5
        kill $!
    fi

    # 写入完整配置
    cat > $CONF_FILE <<'EOF'
[AutoRun]
OnTorrentAdded\Enabled=false
OnTorrentAdded\Program=
enabled=false
program=

[BitTorrent]
Session\AddExtensionToIncompleteFiles=true
Session\ExcludedFileNames=
Session\MaxConnections=-1
Session\MaxConnectionsPerTorrent=-1
Session\MaxUploads=-1
Session\MaxUploadsPerTorrent=-1
Session\Port=51234
Session\Preallocation=true
Session\QueueingSystemEnabled=false

[Core]
AutoDeleteAddedTorrentFile=Never

[LegalNotice]
Accepted=true

[Meta]
MigrationVersion=4

[Network]
Proxy\OnlyForTorrents=false

[Preferences]
Advanced\RecheckOnCompletion=false
Advanced\trackerPort=9000
Advanced\trackerPortForwarding=false
Connection\ResolvePeerCountries=true
DynDNS\DomainName=changeme.dyndns.org
DynDNS\Enabled=false
DynDNS\Password=
DynDNS\Service=DynDNS
DynDNS\Username=
General\Locale=zh_CN
MailNotification\email=
MailNotification\enabled=false
MailNotification\password=
MailNotification\req_auth=true
MailNotification\req_ssl=false
MailNotification\sender=qBittorrent_notification@example.com
MailNotification\smtp_server=smtp.changeme.com
MailNotification\username=
WebUI\Address=*
WebUI\AlternativeUIEnabled=false
WebUI\AuthSubnetWhitelist=@Invalid()
WebUI\AuthSubnetWhitelistEnabled=false
WebUI\BanDuration=3600
WebUI\CSRFProtection=false
WebUI\ClickjackingProtection=false
WebUI\CustomHTTPHeaders=
WebUI\CustomHTTPHeadersEnabled=false
WebUI\HTTPS\CertificatePath=
WebUI\HTTPS\Enabled=false
WebUI\HTTPS\KeyPath=
WebUI\HostHeaderValidation=false
WebUI\LocalHostAuth=true
WebUI\MaxAuthenticationFailCount=5
WebUI\Port=8080
WebUI\ReverseProxySupportEnabled=false
WebUI\RootFolder=
WebUI\SecureCookie=true
WebUI\ServerDomains=*
WebUI\SessionTimeout=3600
WebUI\TrustedReverseProxiesList=
WebUI\UseUPnP=false
WebUI\Username=admin

[RSS]
AutoDownloader\DownloadRepacks=true
AutoDownloader\SmartEpisodeFilter=s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"
EOF

    echo "==== 创建 systemd 服务 ===="
    SERVICE_FILE="/etc/systemd/system/qbittorrent.service"
    cat > $SERVICE_FILE <<EOF
[Unit]
Description=qBittorrent-nox service
After=network.target

[Service]
User=root
ExecStart=/usr/bin/qbittorrent-nox
Restart=on-failure
LimitNOFILE=10240

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now qbittorrent

    echo "==== 安装/更新完成 ===="
    echo "WebUI 地址：http://$(curl -s ifconfig.me):8080"
    echo "用户名：admin"
    echo "密码：adminadmin"
    echo "WebUI 已设置为中文，服务已配置开机自启。"
}

# ---------- 主菜单 ----------
main_menu() {
while true; do
    clear
    # 获取系统版本信息，只显示类似 "Ubuntu 22.04.5 LTS"
    if [[ -f /etc/os-release ]]; then
      OS_VERSION=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    else
      OS_VERSION="未知系统"
    fi

    # CPU核心数
    if command -v lscpu >/dev/null 2>&1; then
      CPU_CORES=$(lscpu | awk -F: '/^CPU\(s\)/{print $2}' | xargs)
    else
      CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
    fi

    MEM_TOTAL_MB=$(free -m | awk '/^Mem:/{print $2}')
	if [[ $MEM_TOTAL_MB -ge 1024 ]]; then
    MEM_TOTAL=$(awk "BEGIN {printf \"%.1fG\", $MEM_TOTAL_MB/1024}")
	else
    MEM_TOTAL="${MEM_TOTAL_MB}M"
	fi

	# 获取虚拟内存总量
	SWAP_TOTAL_MB=$(free -m | awk '/^Swap:/{print $2}')
	if [[ $SWAP_TOTAL_MB -ge 1024 ]]; then
    SWAP_TOTAL=$(awk "BEGIN {printf \"%.1fG\", $SWAP_TOTAL_MB/1024}")
	else
    SWAP_TOTAL="${SWAP_TOTAL_MB}M"
	fi

    # 根分区存储
    if command -v df >/dev/null 2>&1; then
      DISK_TOTAL=$(df -h / | awk 'NR==2{print $2}')
    else
      DISK_TOTAL="未知"
    fi
    
    echo "==============================================="
    echo "      田小瑞一键脚本 V1.0"
    echo "      操作系统：($OS_VERSION)"
    echo -e "      $CPU_CORES核  $MEM_TOTAL内存  $DISK_TOTAL存储  $SWAP_TOTAL虚拟内存"
    echo "==============================================="
    echo "1) 虚拟内存管理           2) 镜像源管理"
    echo "3) BBR 管理               4) BBR 优化"
    echo "5) 流媒体测试             6) 安装宝塔面板"
    echo "7) 安装 DPanel 面板       8) 服务器详细信息"
    echo "9) 一键清理日志和缓存"
    echo "10) 系统管理"
	echo "11) 安装/更新 qBittorrent"
    echo "0) 退出"
    echo "==============================================="
    read -rp "请选择: " choice
    case "$choice" in
      1) manage_swap_menu ;;
      2) manage_sources_menu ;;
      3) manage_bbr ;;
      4) optimize_bbr ;;
      5) streaming_test ;;
      6) install_bt_panel ;;
      7) install_dpanel ;;
      8) system_info ;;
      9) clean_system ;;
      10)
  while true; do
    clear
    echo "=================================="
    echo "         系统管理"
    echo "=================================="
    echo "1) 防火墙管理"
    echo "2) 修改系统时区"
    echo "3) 修改主机名"
    echo "4) 修改 Host"
    echo "5) 切换系统语言"
    echo "0) 返回主菜单"
    read -rp "请输入选项: " sys_choice
    case $sys_choice in
      1) manage_firewall ;;
      2) change_timezone ;;
      3) change_hostname ;;
      4) edit_hosts ;;
      5) change_language ;;
      0) break ;;
      *) echo "❗ 无效选项"; read -p "按回车继续..." ;;
    esac
  done
  ;;
  	 11)
        echo "==== 开始安装/更新 qBittorrent-nox ===="
        # 调用函数或直接插入完整脚本
        install_qbittorrent
  ;;
      0) ok "退出脚本"; exit 0 ;;
      *) warn "无效选项"; sleep 1 ;;
    esac
  done
}

main_menu
