#!/bin/bash
set -euo pipefail
# XUI 面板一键安装脚本（Ubuntu/Debian/CentOS通用）
# 仓库地址：https://github.com/Ahyang12383/cs
# 一键执行：curl -fsSL https://raw.githubusercontent.com/Ahyang12383/cs/refs/heads/main/cs.sh | bash

# 1. 权限校验
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m❌ 请使用 root 用户运行（sudo -i 切换）\033[0m"
    exit 1
fi

# 2. 定义参数（可修改）
XUI_PORT="54321"  # 面板默认端口
XUI_USER="admin"  # 默认用户名
XUI_DIR="/etc/x-ui"

# 3. 安装依赖
echo -e "\033[34m🔧 安装基础依赖...\033[0m"
if [ -f /etc/debian_version ]; then
    apt update -y > /dev/null 2>&1 && apt install -y curl wget unzip tar openssl > /dev/null 2>&1
elif [ -f /etc/redhat-release ]; then
    yum update -y > /dev/null 2>&1 && yum install -y curl wget unzip tar openssl > /dev/null 2>&1
else
    echo -e "\033[31m❌ 不支持当前系统，仅兼容 Ubuntu/Debian/CentOS\033[0m"
    exit 1
fi

# 4. 下载 XUI 最新版
echo -e "\033[34m📥 下载 XUI 面板（官方最新版）...\033[0m"
wget -qO xui.zip https://github.com/vaxilu/x-ui/releases/latest/download/x-ui-linux-amd64.zip

# 5. 解压安装
rm -rf $XUI_DIR && mkdir -p $XUI_DIR
unzip -q xui.zip -d $XUI_DIR
chmod +x $XUI_DIR/x-ui-linux-amd64
rm -rf xui.zip

# 6. 创建系统服务（开机自启）
cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=XUI Panel (Based on Xray)
After=network.target

[Service]
Type=simple
WorkingDirectory=$XUI_DIR
ExecStart=$XUI_DIR/x-ui-linux-amd64 -port $XUI_PORT
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# 7. 启动服务
systemctl daemon-reload > /dev/null 2>&1
systemctl enable --now x-ui > /dev/null 2>&1

# 8. 生成随机密码
RANDOM_PASS=$(openssl rand -hex 8)
$XUI_DIR/x-ui-linux-amd64 setting -username $XUI_USER -password $RANDOM_PASS

# 9. 输出登录信息
SERVER_IP=$(curl -sL ip.sb)
echo -e "\n\033[32m🎉 XUI 面板安装成功！\033[0m"
echo -e "\033[33m📋 登录信息：\033[0m"
echo -e "  面板地址：http://${SERVER_IP}:${XUI_PORT}"
echo -e "  用户名：${XUI_USER}"
echo -e "  密码：${RANDOM_PASS}"
echo -e "\033[33m💡 常用命令：\033[0m"
echo -e "  重启面板：systemctl restart x-ui"
echo -e "  查看日志：journalctl -u x-ui -f"
echo -e "  修改密码：${XUI_DIR}/x-ui-linux-amd64 setting -password 新密码"
echo -e "\033[33m⚠️  请开放服务器安全组 ${XUI_PORT} 端口\033[0m"
