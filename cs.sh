#!/bin/bash
# 极简Socks5一键脚本（Ubuntu/Debian）
# 仓库地址：https://github.com/你的用户名/仓库名
# 一键执行：curl -fSL https://raw.githubusercontent.com/你的用户名/仓库名/main/socks5.sh   bash

# 基础检查：root权限
[ "$(id -u)" != 0 ] && echo -e " 033[31m请用root运行：sudo $0 033[0m" && exit 1

# 交互式配置
read -p "输入Socks5端口（默认1080）：" PORT
PORT=${PORT:-1080}
read -p "输入连接密码（必填）：" PWD
while [ -z "$PWD" ]; do
    echo -e " 033[33m密码不能为空 033[0m"
    read -p "输入连接密码：" PWD
done

# 安装依赖+配置
echo -e " n 033[32m1. 安装依赖... 033[0m"
apt update -y && apt install -y shadowsocks-libev

echo -e " n 033[32m2. 生成配置... 033[0m"
cat > /etc/shadowsocks-libev/config.json << EOF
{"server":"0.0.0.0","server_port":$PORT,"password":"$PWD","method":"aes-256-gcm"}
EOF

# 启动服务+防火墙
echo -e " n 033[32m3. 启动服务... 033[0m"
systemctl enable --now shadowsocks-libev
ufw allow $PORT/tcp > /dev/null 2>&1 && ufw reload > /dev/null 2>&1

# 输出信息
SERVER_IP=$(curl -s ip.sb)
echo -e " n 033[32m=== 部署完成 === 033[0m"
echo "Socks5地址：socks5://$PWD@$SERVER_IP:$PORT"
echo -e " 033[33m提示：需开放服务器安全组$PORT端口 033[0m"
