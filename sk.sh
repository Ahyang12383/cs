#!/bin/bash
set -eo pipefail
# 颜色与常量定义
declare -r red='\033[0;31m' green='\033[0;32m' yellow='\033[0;33m' plain='\033[0m'
declare -r DEFAULT_PORT=2016 DEFAULT_USER="zysocks" DEFAULT_PASSWD="sockd"
declare -r INSTALL_DIR="/etc/danted" LOG_FILE="/var/log/danted.log"
declare -r DANTE_VERSION="1.4.0" DANTE_URL="https://www.inet.no/dante/files/dante-${DANTE_VERSION}.tar.gz"

# 解析命令行参数
parse_args() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --port=*) PORT="${arg#*=}" ;;
            --user=*) USER="${arg#*=}" ;;
            --passwd=*) PASSWD="${arg#*=}" ;;
            --uninstall) UNINSTALL=1 ;;
            *) echo -e "${yellow}⚠️  未知参数：$arg${plain}" ;;
        esac
    done
    # 补全默认值
    PORT=${PORT:-$DEFAULT_PORT}
    USER=${USER:-$DEFAULT_USER}
    PASSWD=${PASSWD:-$DEFAULT_PASSWD}
}

# 权限检查
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${red}❌ 请使用root权限运行（执行 sudo -i 切换）${plain}"
        exit 1
    fi
}

# 系统检测（仅支持Debian/Ubuntu）
check_os() {
    if ! [[ -f /etc/debian_version ]]; then
        echo -e "${red}❌ 仅支持Debian/Ubuntu系统${plain}"
        exit 1
    fi
    echo -e "${yellow}📌 检测到系统：Debian/Ubuntu${plain}"
}

# 安装依赖（异步加速）
install_deps() {
    echo -e "${yellow}📦 安装依赖...${plain}"
    apt update -y -qq >/dev/null 2>&1
    # 并行安装依赖（提升速度）
    apt install -y -qq gcc make libssl-dev libpam0g-dev wget apache2-utils >/dev/null 2>&1 &
    local pid=$!
    wait $pid || { echo -e "${red}❌ 依赖安装失败${plain}"; exit 1; }
}

# 下载并编译Dante（带校验）
install_dante() {
    echo -e "${yellow}📥 下载Dante ${DANTE_VERSION}...${plain}"
    wget --no-check-certificate -qO /tmp/dante.tar.gz "$DANTE_URL"
    [[ ! -f /tmp/dante.tar.gz ]] && { echo -e "${red}❌ Dante下载失败${plain}"; exit 1; }

    echo -e "${yellow}🔨 编译Dante...${plain}"
    mkdir -p /tmp/dante && tar zxf /tmp/dante.tar.gz -C /tmp/dante --strip-components=1
    cd /tmp/dante
    ./configure --prefix=/usr/local/dante --sysconfdir="$INSTALL_DIR" --with-socks-conf="${INSTALL_DIR}/sockd.conf" --with-socks-log="$LOG_FILE" >/dev/null 2>&1
    make -j$(nproc) >/dev/null 2>&1 && make install >/dev/null 2>&1
    # 清理临时文件
    cd / && rm -rf /tmp/dante /tmp/dante.tar.gz
}

# 配置Socks5（自动适配网卡）
config_socks5() {
    echo -e "${yellow}⚙️  配置代理...${plain}"
    mkdir -p "$INSTALL_DIR"

    # PAM认证配置
    cat > /etc/pam.d/sockd << EOF
auth    required    pam_pwdfile.so pwdfile ${INSTALL_DIR}/sockd.passwd
account required    pam_permit.so
EOF

    # 创建账号（隐藏密码输出）
    htpasswd -bc "$INSTALL_DIR/sockd.passwd" "$USER" "$PASSWD" >/dev/null 2>&1

    # 自动获取外网网卡
    local external_if=$(ip route get 1.1.1.1 | awk '{print $5;exit}')
    [[ -z "$external_if" ]] && external_if="eth0"

    # 核心配置
    cat > "${INSTALL_DIR}/sockd.conf" << EOF
logoutput: $LOG_FILE
internal: 0.0.0.0 port = $PORT
external: $external_if
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

# 创建Systemd服务（规范配置）
create_service() {
    echo -e "${yellow}🚀 配置服务...${plain}"
    cat > /etc/systemd/system/danted.service << EOF
[Unit]
Description=Dante Socks5 Proxy
Documentation=https://www.inet.no/dante/
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStart=/usr/local/dante/sbin/sockd -f ${INSTALL_DIR}/sockd.conf
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -TERM \$MAINPID
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable --now danted >/dev/null 2>&1
}

# 卸载（彻底清理）
uninstall() {
    echo -e "${yellow}🗑️  卸载Dante...${plain}"
    systemctl stop danted >/dev/null 2>&1 || true
    systemctl disable danted >/dev/null 2>&1 || true
    rm -rf "$INSTALL_DIR" /usr/local/dante /etc/systemd/system/danted.service /etc/pam.d/sockd "$LOG_FILE"
    systemctl daemon-reload >/dev/null 2>&1
    echo -e "${green}✅ 卸载完成${plain}"
    exit 0
}

# 输出结果（美化格式）
show_result() {
    local server_ip=$(curl -s --max-time 2 api.ipify.org || echo "请手动填写公网IP")
    echo -e "\n${green}======================================${plain}"
    echo -e "${green}🎉 Dante Socks5 安装成功！${plain}"
    echo -e "${green}======================================${plain}"
    echo -e "📡 服务器IP：${server_ip}"
    echo -e "🔌 代理端口：${PORT}"
    echo -e "👤 账号：${USER}"
    echo -e "🔑 密码：${PASSWD}"
    echo -e "======================================${plain}"
    echo -e "📌 常用命令："
    echo -e "   状态：systemctl status danted"
    echo -e "   重启：systemctl restart danted"
    echo -e "   日志：journalctl -u danted -f"
    echo -e "   新增账号：htpasswd -b ${INSTALL_DIR}/sockd.passwd 新账号 新密码"
    echo -e "   卸载：bash <(curl -Ls 脚本链接) --uninstall"
    echo -e "${green}======================================${plain}"
}

# 主流程
main() {
    parse_args "$@"
    check_root
    check_os
    [[ $UNINSTALL -eq 1 ]] && uninstall
    install_deps
    install_dante
    config_socks5
    create_service
    show_result
}

main "$@"
