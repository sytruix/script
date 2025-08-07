#!/bin/bash
# apt_source_manager.sh
# Debian apt源管理脚本
# 支持Debian 11/12，官方源/阿里云源，备份恢复，自动导入公钥

set -e

APT_DIR="/etc/apt"
BACKUP_DIR="/root"
DATE=$(date +%Y%m%d_%H%M%S)

# 判断Debian版本
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

# 官方源模板
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

# 阿里云源模板
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

# 备份 /etc/apt
backup_apt(){
    echo "✅ 开始备份 $APT_DIR 到 $BACKUP_DIR/apt_backup_$DATE.tar.gz"
    tar czf "$BACKUP_DIR/apt_backup_$DATE.tar.gz" "$APT_DIR"
    echo "🎉 备份完成：$BACKUP_DIR/apt_backup_$DATE.tar.gz"
}

# 列出备份文件
list_backups(){
    ls -1t $BACKUP_DIR/apt_backup_*.tar.gz 2>/dev/null || echo "无备份文件"
}

# 恢复备份
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
    rm -rf $APT_DIR
    mkdir -p $APT_DIR
    tar xzf "$backup_file" -C /
    echo "✅ 恢复完成。"
    return 0
}

# 批量导入常见Debian公钥，避免公钥缺失错误
import_common_gpg_keys(){
    mkdir -p /etc/apt/trusted.gpg.d
    local keys=(
        0E98404D386FA1D9
        6ED0E7B82643E131
        605C66F00D6C9793
        54404762BBB6E853
        BDE6D2B9216EC7A8
    )
    for key in "${keys[@]}"; do
        echo "🔑 导入公钥: $key"
        # 使用gpg命令导入，存储到trusted.gpg.d目录
        tmpdir=$(mktemp -d)
        if gpg --no-default-keyring --keyring "$tmpdir/temp.gpg" --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" >/dev/null 2>&1; then
            gpg --no-default-keyring --keyring "$tmpdir/temp.gpg" --export "$key" > "/etc/apt/trusted.gpg.d/${key}.gpg"
            echo "✅ 公钥 $key 导入成功"
        else
            echo "❌ 公钥 $key 导入失败"
        fi
        rm -rf "$tmpdir"
    done
}

# check_missing_keys 函数如果需要可自行扩展为动态检测缺失公钥，目前用固定导入
check_missing_keys(){
    import_common_gpg_keys
}

# 写入源及执行导入钥匙和更新
write_sources(){
    local ver=$1
    local type=$2

    echo "🧹 删除旧的 $APT_DIR 目录..."
    rm -rf $APT_DIR

    echo "📂 创建必要目录..."
    mkdir -p $APT_DIR/apt.conf.d
    mkdir -p /etc/apt/preferences.d
    mkdir -p /etc/apt/trusted.gpg.d
    mkdir -p /etc/apt/sources.list.d

    echo "📝 写入新的源配置..."
    if [[ "$type" == "official" ]]; then
        official_sources "$ver" > $APT_DIR/sources.list
    elif [[ "$type" == "aliyun" ]]; then
        aliyun_sources "$ver" > $APT_DIR/sources.list
    else
        echo "❌ 未知源类型：$type"
        exit 1
    fi

    echo '# 默认apt配置' > $APT_DIR/apt.conf.d/99custom
    echo 'Acquire::Retries "3";' >> $APT_DIR/apt.conf.d/99custom

    echo "🔧 导入常用 GPG 公钥..."
    check_missing_keys

    echo "🔄 运行最终更新..."
    apt-get update && apt update

    echo "🎉 源更新成功！"
}

# 主菜单界面
show_menu(){
    clear
    echo "=================================="
    echo "  Debian 系统 apt源管理脚本"
    echo "=================================="
    debver=$(get_debian_version)
    if [[ -z "$debver" ]]; then
        echo "❌ 无法检测到 Debian 版本，脚本仅支持 Debian 11 和 12"
        exit 1
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
    echo "0) 退出"
    echo "----------------------------------"
    echo -n "请输入选项: "
}

while true; do
    show_menu
    read -r choice
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
            apt-get update && apt update
            echo "✅ 更新完成。"
            read -p "按回车继续..."
            ;;
        0)
            echo "👋 退出脚本，再见！"
            exit 0
            ;;
        *)
            echo "❗ 无效选项，请重新输入。"
            ;;
    esac
done
