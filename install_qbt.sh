#!/bin/bash
set -e

QBIT_VERSION="4.6.7"
LIBTORRENT_VERSION="1.2.19"   # 可改为 2.0.x，例如：2.0.10
CORES=$(nproc)

echo "========== 更新系统 =========="
sudo apt update && sudo apt upgrade -y

echo "========== 安装编译依赖 =========="
sudo apt install -y \
    build-essential \
    pkg-config \
    automake \
    libtool \
    git \
    curl \
    qtbase5-dev \
    qttools5-dev-tools \
    libboost-dev \
    libboost-system-dev \
    libboost-chrono-dev \
    libboost-random-dev \
    libssl-dev \
    libgeoip-dev \
    zlib1g-dev \
    python3 \
    python3-pip

echo "========== 安装 CMake 3.16+（适用于 libtorrent）=========="
CMAKE_VER=$(cmake --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
if dpkg --compare-versions "$CMAKE_VER" lt "3.16.0"; then
    pip3 install cmake
    export PATH=$HOME/.local/bin:$PATH
fi

echo "========== 下载并编译 libtorrent-rasterbar $LIBTORRENT_VERSION =========="
cd /tmp
git clone --branch RC_${LIBTORRENT_VERSION//./_} https://github.com/arvidn/libtorrent.git
cd libtorrent
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr .. 
make -j$CORES
sudo make install

echo "========== 下载并编译 qBittorrent-nox v$QBIT_VERSION =========="
cd /tmp
git clone --branch release-$QBIT_VERSION https://github.com/qbittorrent/qBittorrent.git
cd qBittorrent
./configure --disable-gui --prefix=/usr
make -j$CORES
sudo make install

echo "========== 创建 qBittorrent-nox Systemd 服务 =========="
sudo useradd -r -s /usr/sbin/nologin qbittorrent-nox || true
sudo mkdir -p /var/lib/qbittorrent
sudo chown qbittorrent-nox: /var/lib/qbittorrent

sudo tee /etc/systemd/system/qbittorrent-nox.service > /dev/null <<EOF
[Unit]
Description=qBittorrent-nox service
After=network.target

[Service]
User=qbittorrent-nox
ExecStart=/usr/bin/qbittorrent-nox --webui-port=8080 --profile=/var/lib/qbittorrent
Restart=on-failure
TimeoutStopSec=20
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

echo "========== 启动并启用服务 =========="
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now qbittorrent-nox

echo "========== 安装完成 ✅ =========="
echo "Web UI 默认地址：http://<你的IP>:8080"
echo "默认用户名：admin"
echo "默认密码：adminadmin"
