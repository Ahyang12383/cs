#!/bin/bash
set -e
# 颜色定义
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 默认参数（可通过命令行覆盖）
DEFAULT_PORT=2016
DEFAULT_USER="zysocks"
DEFAULT_PASSWD="sockd"
INSTALL_DIR="/etc/danted"
LOG_FILE="/var/log/danted.log"

# 解析命令行参数
for arg in "$@"; do
    case $arg in
        --port=*) PORT="${arg#*=}"; shift ;;
        --user=*) USER="${arg#*=}"; shift ;;
        --passwd=*) PASSWD="${arg#*=}"; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        *) echo -e "${yellow}未知参数：$arg${plain}"; shift ;;
    esac
done

# 补全默认参数
PORT=${PORT:-$DEFAULT_PORT}
USER=${USER:-$DEFAULT_USER}
PASSWD=${PASSWD:-$DEFAULT_PASSWD}

# 权限检查
check_root() {
    [[ $EUID -ne 0 ]] && echo -e "${red}❌ 请使用root权限运行（执行 sudo -i 切换）${plain}" && exit 1
}

# 系统检测（仅支持Debian/Ubuntu）
check_os() {
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
        echo -e "${yellow}📌 检测到系统：Debian/Ubuntu${plain}"
    else
        echo -e "${red}❌ 不支持当前系统，仅适配Debian/Ubuntu${plain}" && exit 1
    fi
}

# 安装依赖
install_deps() {
    echo -e "${yellow}📦 安装编译依赖...${plain}"
    apt update -y >/dev/null 2>&1
    apt install -y gcc make libssl-dev libpam0g-dev wget apache2-utils >/dev/null 2>&1
}

# 下载并编译Dante
install_dante() {
    echo -e "${yellow}📥 下载并编译Dante 1.4.0...${plain}"
    wget --no-check-certificate -qO dante.tar.gz https://www.inet.no/dante/files/dante-1.4.0.tar.gz
    tar zxf dante.tar.gz >/dev/null 2>&1
    cd dante-1.4.0
    ./configure --prefix=/usr/local/dante --sysconfdir=$INSTALL_DIR --with-socks-conf=$INSTALL_DIR/sockd.conf --with-socks-log=$LOG_FILE >/dev/null 2>&1
    make >/dev/null 2>&1 && make install >/dev/null 2>&1
    cd .. && rm -rf dante.tar.gz dante-1.4.0
}

# 配置Socks5代理与认证
config_socks5() {
    echo -e "${yellow}⚙️  配置代理与账号...${plain}"
    mkdir -p $INSTALL_DIR

    # PAM认证配置
    cat > /etc/pam.d/sockd << EOF
auth    required    pam_pwdfile.so pwdfile $INSTALL_DIR/sockd.passwd
account required    pam_permit.so
EOF

    # 创建账号密码
    htpasswd -bc $INSTALL_DIR/sockd.passwd $USER $PASSWD >/dev/null 2>&1

    # 代理核心配置
    EXTERNAL_IF=$(ip route get 1 | awk '{print $5;exit}')
    cat > $INSTALL_DIR/sockd.conf << EOF
logoutput: $LOG_FILE
internal: 0.0.0.0 port = $PORT
external: $EXTERNAL_IF
clientmethod: pam
srvmethod: pam
user.privileged: root
user.unprivileged: sock
user.libwrap: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
    socksmethod: pam
}

block {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
EOF
}

# 创建Systemd服务（开机自启）
create_service() {
    echo -e "${yellow}🚀 创建系统服务...${plain}"
    cat > /etc/systemd/system/danted.service << EOF
[Unit]
Description=Dante Socks5 Proxy Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/dante/sbin/sockd -f $INSTALL_DIR/sockd.conf
ExecStop=pkill sockd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable danted --now >/dev/null 2>&1
}

# 卸载功能
uninstall() {
    echo -e "${yellow}🗑️  开始卸载Dante Socks5...${plain}"
    systemctl stop danted >/dev/null 2>&1
    systemctl disable danted >/dev/null 2>&1
    rm -rf $INSTALL_DIR /usr/local/dante /etc/systemd/system/danted.service /etc/pam.d/sockd $LOG_FILE
    systemctl daemon-reload >/dev/null 2>&1
    echo -e "${green}✅ 卸载完成！所有文件已清理${plain}"
    exit 0
}

# 输出安装结果
show_result() {
    SERVER_IP=$(curl -s --max-time 2 api.ipify.org || echo "请手动填写服务器公网IP")
    echo -e "\n${green}======================================${plain}"
    echo -e "${green}🎉 Dante Socks5 安装成功！${plain}"
    echo -e "${green}======================================${plain}"
    echo -e "📡 服务器IP：${SERVER_IP}"
    echo -e "🔌 代理端口：${PORT}"
    echo -e "👤 登录账号：${USER}"
    echo -e "🔑 登录密码：${PASSWD}"
    echo -e "======================================${plain}"
    echo -e "📌 常用命令："
    echo -e "   启动服务：systemctl start danted"
    echo -e "   停止服务：systemctl stop danted"
    echo -e "   重启服务：systemctl restart danted"
    echo -e "   查看状态：systemctl status danted"
    echo -e "   添加账号：htpasswd -b $INSTALL_DIR/sockd.passwd 新账号 新密码"
    echo -e "   卸载服务：bash <(curl -Ls 脚本链接) --uninstall"
    echo -e "${green}======================================${plain}"
}

# 主流程
main() {
    check_root
    check_os
    [[ $UNINSTALL -eq 1 ]] && uninstall
    install_deps
    install_dante
    config_socks5
    create_service
    show_result
}

main
