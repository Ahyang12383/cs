#!/bin/bash
set -e
# 核心配置（可按需修改）
PANEL_PORT=9999
DEFAULT_USER="xuiadmin"
DEFAULT_PWD="Xui@2024"

# 权限检查
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ 请使用 root 权限运行脚本（sudo -i 切换）"
        exit 1
    fi
}

# 安装功能
install_xui() {
    check_root
    echo -e "\n🚀 开始安装 XUI 面板（端口：$PANEL_PORT）..."
    
    # 安装依赖
    echo "📦 安装基础依赖..."
    if [ -f /etc/redhat-release ]; then
        yum update -y && yum install -y wget curl unzip java-11-openjdk
    elif [ -f /etc/debian_version ]; then
        apt update -y && apt install -y wget curl unzip openjdk-11-jdk
    fi

    # 下载解压
    echo "📥 下载 XUI 最新稳定版..."
    wget -qO /tmp/xui.zip https://github.com/vaxilu/xui/releases/latest/download/xui-linux-amd64.zip
    mkdir -p /usr/local/xui
    unzip -o /tmp/xui.zip -d /usr/local/xui
    chmod +x /usr/local/xui/xui

    # 初始化账号密码
    echo "🔑 配置账号密码..."
    cat > /usr/local/xui/db.sqlite3 << EOF
CREATE TABLE IF NOT EXISTS "xui_user" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "username" TEXT NOT NULL, "password" TEXT NOT NULL, "permission" TEXT NOT NULL DEFAULT 'admin', "enable" INTEGER NOT NULL DEFAULT 1, "expireTime" INTEGER NOT NULL DEFAULT 0);
INSERT OR REPLACE INTO "xui_user" ("username", "password", "permission") VALUES ('$DEFAULT_USER', '$DEFAULT_PWD', 'admin');
EOF

    # 创建系统服务
    cat > /etc/systemd/system/xui.service << EOF
[Unit]
Description=XUI Panel
After=network.target
[Service]
User=root
WorkingDirectory=/usr/local/xui
ExecStart=/usr/local/xui/xui -port $PANEL_PORT
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

    # 启动并设置开机自启
    systemctl daemon-reload
    systemctl enable xui --now

    # 防火墙放行
    echo "🔥 配置防火墙端口..."
    if [ -f /etc/redhat-release ]; then
        firewall-cmd --permanent --add-port=$PANEL_PORT/tcp && firewall-cmd --reload
    elif [ -f /etc/debian_version ]; then
        ufw allow $PANEL_PORT/tcp && ufw reload
    fi

    # 输出结果
    echo -e "\n================ 安装完成 ================"
    echo "✅ 访问地址：http://服务器IP:$PANEL_PORT"
    echo "✅ 登录账号：$DEFAULT_USER"
    echo "✅ 登录密码：$DEFAULT_PWD"
    echo -e "==========================================="
    echo "⚠️  重要：登录后请立即修改密码！"
    echo "📌 常用命令：systemctl start/stop/restart xui"
}

# 卸载功能
uninstall_xui() {
    check_root
    echo -e "\n🗑️  开始卸载 XUI 面板..."
    
    # 停止服务
    echo "🛑 停止 XUI 服务..."
    systemctl stop xui 2>/dev/null
    systemctl disable xui 2>/dev/null
    rm -rf /etc/systemd/system/xui.service
    systemctl daemon-reload

    # 清理文件
    echo "🧹 删除安装目录和数据库..."
    rm -rf /usr/local/xui
    rm -rf /tmp/xui.zip 2>/dev/null

    # 清理防火墙
    echo "🚫 移除防火墙端口规则..."
    if [ -f /etc/redhat-release ]; then
        firewall-cmd --permanent --remove-port=$PANEL_PORT/tcp 2>/dev/null
        firewall-cmd --reload 2>/dev/null
    elif [ -f /etc/debian_version ]; then
        ufw delete allow $PANEL_PORT/tcp 2>/dev/null
        ufw reload 2>/dev/null
    fi

    echo -e "\n✅ XUI 面板已彻底卸载！所有文件、服务均已清理"
}

# 优化：通过命令行参数指定操作，避免交互式输入
if [ "$1" = "install" ]; then
    install_xui
elif [ "$1" = "uninstall" ]; then
    uninstall_xui
else
    echo "========================================"
    echo "          XUI 面板一键管理脚本          "
    echo "========================================"
    echo "使用方式："
    echo "  安装：$0 install"
    echo "  卸载：$0 uninstall"
    echo "========================================"
    exit 1
fi
