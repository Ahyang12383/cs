#!/bin/bash
# Dante Socks5 一键安装脚本（适配CentOS/Debian/Ubuntu）
# 作者：Lozy
# 版本：1.4.0

# 颜色定义
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# 默认参数
DEFAULT_PORT=2016
DEFAULT_USER="sockd"
DEFAULT_PAWD="sockd"
MASTER_IP="buyvm.info"
INSTALL_DIR="/etc/danted"
LOG_FILE="/var/log/danted.log"

# 解析命令行参数
for arg in "$@"; do
    case $arg in
        --port=*)
            DEFAULT_PORT="${arg#*=}"
            shift
            ;;
        --user=*)
            DEFAULT_USER="${arg#*=}"
            shift
            ;;
        --passwd=*)
            DEFAULT_PAWD="${arg#*=}"
            shift
            ;;
        --master=*)
            MASTER_IP="${arg#*=}"
            shift
            ;;
        --uninstall)
            UNINSTALL=1
            shift
            ;;
        *)
            echo -e "${yellow}未知参数：$arg${plain}"
            shift
            ;;
    esac
done

# 权限检查
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${red}错误：请使用root权限运行脚本${plain}"
        exit 1
    fi
}

# 检测系统
check_os() {
    if [ -f /etc/redhat-release ]; then
        OS="centos"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
    else
        echo -e "${red}不支持的系统${plain}"
        exit 1
    fi
}

# 安装依赖
install_deps() {
    echo -e "${yellow}安装依赖中...${plain}"
    if [ "$OS" = "centos" ]; then
        yum -y install gcc make openssl-devel pam-devel
    else
        apt-get update && apt-get -y install gcc make libssl-dev libpam0g-dev
    fi
}

# 下载并编译Dante
install_dante() {
    echo -e "${yellow}下载Dante源码...${plain}"
    wget --no-check-certificate https://www.inet.no/dante/files/dante-1.4.0.tar.gz
    tar zxvf dante-1.4.0.tar.gz
    cd dante-1.4.0
    ./configure --prefix=/usr/local/dante --sysconfdir=$INSTALL_DIR --with-socks-conf=$INSTALL_DIR/sockd.conf --with-socks-log=$LOG_FILE
    make && make install
    cd .. && rm -rf dante-1.4.0*
}

# 配置PAM认证
config_pam() {
    echo -e "${yellow}配置PAM认证...${plain}"
    echo "auth    required    pam_pwdfile.so pwdfile $INSTALL_DIR/sockd.passwd" > /etc/pam.d/sockd
    echo "account required    pam_permit.so" >> /etc/pam.d/sockd
    htpasswd -bc $INSTALL_DIR/sockd.passwd $DEFAULT_USER $DEFAULT_PAWD
}

# 生成配置文件
config_sockd() {
    echo -e "${yellow}生成配置文件...${plain}"
    mkdir -p $INSTALL_DIR
    cat > $INSTALL_DIR/sockd.conf << EOF
logoutput: $LOG_FILE
internal: 0.0.0.0 port = $DEFAULT_PORT
external: eth0
clientmethod: pam
srvmethod: pam
user.privileged: root
user.unprivileged: sock
user.libwrap: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
client block {
    from: 127.0.0.0/8 to: 0.0.0.0/0
    log: connect error
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

# 创建启动脚本
create_service() {
    echo -e "${yellow}创建启动服务...${plain}"
    cat > /etc/init.d/danted << EOF
#!/bin/bash
# chkconfig: 2345 90 10
# description: Dante Socks5 Server
DAEMON=/usr/local/dante/sbin/sockd
CONF=$INSTALL_DIR/sockd.conf
case "\$1" in
    start)
        \$DAEMON -f \$CONF
        ;;
    stop)
        pkill sockd
        ;;
    restart)
        \$0 stop
        \$0 start
        ;;
    status)
        pgrep sockd >/dev/null && echo -e "${green}Dante运行中${plain}" || echo -e "${red}Dante未运行${plain}"
        ;;
    add)
        htpasswd -b $INSTALL_DIR/sockd.passwd \$2 \$3
        ;;
    del)
        htpasswd -D $INSTALL_DIR/sockd.passwd \$2
        ;;
    *)
        echo "用法：\$0 {start|stop|restart|status|add|del}"
        exit 1
esac
exit 0
EOF
    chmod +x /etc/init.d/danted
    if [ "$OS" = "centos" ]; then
        chkconfig --add danted
        chkconfig danted on
    else
        update-rc.d danted defaults
    fi
}

# 卸载功能
uninstall() {
    echo -e "${yellow}开始卸载Dante...${plain}"
    /etc/init.d/danted stop
    if [ "$OS" = "centos" ]; then
        chkconfig --del danted
    else
        update-rc.d -f danted remove
    fi
    rm -rf $INSTALL_DIR /usr/local/dante /etc/init.d/danted /etc/pam.d/sockd
    echo -e "${green}卸载完成${plain}"
    exit 0
}

# 主流程
main() {
    check_root
    check_os
    if [ "$UNINSTALL" = 1 ]; then
        uninstall
    fi
    install_deps
    install_dante
    config_pam
    config_sockd
    create_service
    /etc/init.d/danted start
    echo -e "\n${green}Dante Server Install Successfuly!${plain}"
    echo -e "======================================"
    echo -e "端口：$DEFAULT_PORT"
    echo -e "账号：$DEFAULT_USER"
    echo -e "密码：$DEFAULT_PAWD"
    echo -e "管理命令：/etc/init.d/danted {start|stop|restart|status|add|del}"
    echo -e "======================================"
}

main
