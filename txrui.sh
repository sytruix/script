#!/bin/bash

# ----------- 虚拟内存管理函数 -----------
set_swap() {
  local size=$1
  local swapfile="/swapfile"

  echo "正在设置虚拟内存为 $size..."

  sudo swapoff -a
  sudo rm -f $swapfile
  sudo fallocate -l $size $swapfile
  sudo chmod 600 $swapfile
  sudo mkswap $swapfile
  sudo swapon $swapfile

  echo "虚拟内存已设置为 $size"
}

delete_swap() {
  echo "正在删除虚拟内存..."

  sudo swapoff -a
  sudo rm -f /swapfile

  echo "虚拟内存已删除"
}

manage_swap() {
  while true; do
    echo "虚拟内存管理"
    echo "1) 设定虚拟内存1GB"
    echo "2) 设定虚拟内存2GB"
    echo "3) 设定虚拟内存4GB"
    echo "4) 自定义设定虚拟内存"
    echo "5) 删除虚拟内存"
    echo "0) 返回主菜单"

    read -rp "请输入选项: " swap_choice

    case $swap_choice in
      1) set_swap 1G ;;
      2) set_swap 2G ;;
      3) set_swap 4G ;;
      4) 
        read -rp "请输入虚拟内存大小（例如512M, 3G）: " custom_size
        set_swap "$custom_size"
        ;;
      5) delete_swap ;;
      0) break ;;
      *) echo "无效选项" ;;
    esac
  done
}

# ----------- 镜像源管理函数 -----------
# Debian apt源管理脚本相关代码开始

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

# deb http://deb.debian.org/debian bullseye-backports main contrib non-free
# deb-src http://deb.debian.org/debian bullseye-backports main contrib non-free
EOF
    elif [[ "$ver" == "12" ]]; then
        cat <<EOF
deb http://deb.debian.org/debian bookworm main contrib non-free
deb-src http://deb.debian.org/debian bookworm main contrib non-free

deb http://deb.debian.org/debian bookworm-updates main contrib non-free
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free

deb http://security.debian.org/debian-security bookworm-security main contrib non-free
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free

# deb http://deb.debian.org/debian bookworm-backports main contrib non-free
# deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free
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

# deb http://mirrors.aliyun.com/debian/ bullseye-backports main contrib non-free
# deb-src http://mirrors.aliyun.com/debian/ bullseye-backports main contrib non-free
EOF
    elif [[ "$ver" == "12" ]]; then
        cat <<EOF
deb http://mirrors.aliyun.com/debian/ bookworm main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bookworm main contrib non-free

deb http://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free
deb-src http://mirrors.aliyun.com/debian/ bookworm-updates main contrib non-free

deb http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free
deb-src http://mirrors.aliyun.com/debian-security bookworm-security main contrib non-free

# deb http://mirrors.aliyun.com/debian/ bookworm-backports main contrib non-free
# deb-src http://mirrors.aliyun.com/debian/ bookworm-backports main contrib non-free
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
    local keys=(
        0E98404D386FA1D9
        6ED0E7B82643E131
        605C66F00D6C9793
        54404762BBB6E853
        BDE6D2B9216EC7A8
    )
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

check_missing_keys(){
    import_common_gpg_keys
}

write_sources(){
    local ver=$1
    local type=$2

    echo "🧹 删除旧的 $APT_DIR 目录..."
    sudo rm -rf $APT_DIR

    echo "📂 创建必要目录..."
    sudo mkdir -p $APT_DIR/apt.conf.d
    sudo mkdir -p /etc/apt/preferences.d
    sudo mkdir -p /etc/apt/trusted.gpg.d

    echo "📂 创建必要文件..."
    sudo touch -p /etc/apt/sources.list.d/docker.list

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
    check_missing_keys

    echo "🔄 运行最终更新..."
    sudo apt-get update && sudo apt update

    echo "🎉 源更新成功！"
}

manage_sources() {
  while true; do
    clear
    echo "=================================="
    echo "      Debian apt源管理"
    echo "=================================="
    debver=$(get_debian_version)
    if [[ -z "$debver" ]]; then
      echo "❌ 无法检测到 Debian 版本，脚本仅支持 Debian 11 和 12"
      read -p "按回车返回主菜单..."
      break
    else
      echo "📦 当前系统：Debian $debver"
    fi
    echo ""
    echo "请选择操作："
    echo "1) 备份 /etc/apt"
    echo "2) 恢复 /etc/apt 备份"
    echo "3) 使用 官方源"
    echo "4) 使用 阿里云源"
    echo "5) 更新 APT 源"
    echo "0) 返回主菜单"
    echo "----------------------------------"
    read -rp "请输入选项: " choice

    case $choice in
      1)
        backup_apt
        read -p "按回车继续..."
        ;;
      2)
        restore_backup && read -p "按回车继续..."
        ;;
      3)
        ver=$(get_debian_version)
        write_sources "$ver" official
        read -p "按回车继续..."
        ;;
      4)
        ver=$(get_debian_version)
        write_sources "$ver" aliyun
        read -p "按回车继续..."
        ;;
      5)
        echo "🔄 正在更新 apt 源..."
        sudo apt-get update && sudo apt update
        echo "✅ 更新完成。"
        read -p "按回车继续..."
        ;;
      0)
        break
        ;;
      *)
        echo "❗ 无效选项，请重新输入。"
        read -p "按回车继续..."
        ;;
    esac
  done
}
manage_bbr() {
  echo "正在下载并运行 BBR 管理脚本..."
  wget -N --no-check-certificate "https://github.000060000.xyz/tcpx.sh"
  chmod +x tcpx.sh
  ./tcpx.sh
  read -p "按回车返回主菜单..."
}

optimize_bbr() {
  echo "正在运行 BBR 优化脚本..."
  bash <(curl -Ls https://github.com/lanziii/bbr-/releases/download/123/tools.sh)
  read -p "按回车返回主菜单..."
}

streaming_test() {
  echo "正在运行流媒体解锁测试..."
  bash <(curl -L -s check.unlock.media) -M 4 -R 0
  read -p "按回车返回主菜单..."
}

install_bt_panel() {
  echo "正在安装宝塔面板..."
  if [ -f /usr/bin/curl ]; then
    curl -sSO https://download.bt.cn/install/install_panel.sh
  else
    wget -O install_panel.sh https://download.bt.cn/install/install_panel.sh
  fi
  bash install_panel.sh ed8484bec
  read -p "按回车返回主菜单..."
}

install_dpanel() {
  echo "正在安装 DPanel 面板..."
  curl -sSL https://dpanel.cc/quick.sh -o quick.sh && sudo bash quick.sh
  read -p "按回车返回主菜单..."
}
# --- 主菜单 ---
while true; do
  clear
  echo "田小瑞一键脚本 v1.1"
  echo "====================="
  echo "1) 虚拟内存管理"
  echo "2) 镜像源管理"
  echo "3) BBR管理"
  echo "4) BBR优化"
  echo "5) 流媒体测试"
  echo "6) 安装宝塔面板"
  echo "7) 安装DPanel面板"
  echo "8) 退出"
  echo "====================="
  read -rp "请选择操作: " main_choice

  case $main_choice in
    1) manage_swap ;;
    2) manage_sources ;;
    3) manage_bbr ;;
    4) optimize_bbr ;;
    5) streaming_test ;;
    6) install_bt_panel ;;
    7) install_dpanel ;;
    8) echo "退出脚本"; exit 0 ;;
    *) echo "无效选项"; sleep 1 ;;
  esac
done
