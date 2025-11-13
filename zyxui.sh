#!/bin/bash
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;34m'
yellow='\033[0;33m'
plain='\033[0m'
cur_dir=$(pwd)

# 权限检查
check_root() {
    [[ $EUID -ne 0 ]] && echo -e "${red}错误：请用root权限运行（sudo -i）${plain}" && exit 1
}

# 检测系统版本
check_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        release=$ID
    elif [[ -f /usr/lib/os-release ]]; then
        source /usr/lib/os-release
        release=$ID
    else
        echo "无法识别系统，退出安装" >&2
        exit 1
    fi
    echo "系统版本：$release"
}

# 检测CPU架构
check_arch() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    i*86 | x86) echo '386' ;;
    armv8* | armv8 | arm64 | aarch64) echo 'arm64' ;;
    armv7* | armv7 | arm) echo 'armv7' ;;
    armv6* | armv6) echo 'armv6' ;;
    armv5* | armv5) echo 'armv5' ;;
    s390x) echo 's390x' ;;
    *) echo -e "${red}不支持的CPU架构${plain}" && exit 1 ;;
    esac
}
arch=$(check_arch)
echo "CPU架构：$arch"

# 安装基础依赖
install_base() {
    case "${release}" in
    ubuntu | debian | armbian)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    centos | rhel | almalinux | rocky | ol)
        yum -y update && yum install -y -q wget curl tar tzdata
        ;;
    fedora | amzn | virtuozzo)
        dnf -y update && dnf install -y -q wget curl tar tzdata
        ;;
    *)
        apt-get update && apt-get install -y -q wget curl tar tzdata
        ;;
    esac
}

# 生成随机字符串
gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

# 安装后配置
config_after_install() {
    local existing_hasDefaultCredential=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'hasDefaultCredential: .+' | awk '{print $2}')
    local existing_webBasePath=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'webBasePath: .+' | awk '{print $2}')
    local existing_port=$(/usr/local/x-ui/x-ui setting -show true | grep -Eo 'port: .+' | awk '{print $2}')
    local URL_lists=(
        "https://api4.ipify.org"
		"https://ipv4.icanhazip.com"
		"https://v4.api.ipinfo.io/ip"
		"https://ipv4.myexternalip.com/raw"
		"https://4.ident.me"
		"https://check-host.net/ip"
    )
    local server_ip=""
    for ip_address in "${URL_lists[@]}"; do
        server_ip=$(curl -s --max-time 3 "${ip_address}" 2>/dev/null | tr -d '[:space:]')
        if [[ -n "${server_ip}" ]]; then
            break
        fi
    done

    if [[ ${#existing_webBasePath} -lt 4 ]]; then
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_webBasePath=$(gen_random_string 18)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)
            read -rp "是否自定义面板端口？（否则随机生成）[y/n]: " config_confirm
            [[ -z "$config_confirm" ]] && config_confirm="n"
            if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
                read -rp "请设置面板端口：" config_port
                echo -e "${yellow}你的面板端口：${config_port}${plain}"
            else
                local config_port=$(shuf -i 1024-62000 -n 1)
                echo -e "${yellow}随机生成端口：${config_port}${plain}"
            fi
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            echo -e "新安装，生成随机登录信息："
            echo -e "###############################################"
            echo -e "${green}账号：${config_username}${plain}"
            echo -e "${green}密码：${config_password}${plain}"
            echo -e "${green}端口：${config_port}${plain}"
            echo -e "${green}访问路径：${config_webBasePath}${plain}"
            echo -e "${green}访问地址：http://${server_ip}:${config_port}/${config_webBasePath}${plain}"
            echo -e "###############################################"
        else
            local config_webBasePath=$(gen_random_string 18)
            echo -e "${yellow}访问路径过短，生成新路径...${plain}"
            /usr/local/x-ui/x-ui setting -webBasePath "${config_webBasePath}"
            echo -e "${green}新访问路径：${config_webBasePath}${plain}"
            echo -e "${green}访问地址：http://${server_ip}:${existing_port}/${config_webBasePath}${plain}"
        fi
    else
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)
            echo -e "${yellow}检测到默认凭证，更新安全信息...${plain}"
            /usr/local/x-ui/x-ui setting -username "${config_username}" -password "${config_password}"
            echo -e "生成新登录信息："
            echo -e "###############################################"
            echo -e "${green}账号：${config_username}${plain}"
            echo -e "${green}密码：${config_password}${plain}"
            echo -e "###############################################"
        else
            echo -e "${green}账号、密码、访问路径已配置，退出...${plain}"
        fi
    fi
    /usr/local/x-ui/x-ui migrate
}

# 安装逻辑
install_x-ui() {
    check_root
    check_os
    install_base
    cd /usr/local/

    # 下载最新版本
    tag_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ ! -n "$tag_version" ]]; then
        tag_version=$(curl -4 -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$tag_version" ]]; then
            echo -e "${red}获取版本失败，请检查网络${plain}"
            exit 1
        fi
    fi
    echo -e "获取到最新版本：${tag_version}，开始安装..."
    wget --inet4-only -N -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${tag_version}/x-ui-linux-${arch}.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载失败，请确认服务器可访问GitHub${plain}"
        exit 1
    fi

    # 下载命令行工具
    wget --inet4-only -O /usr/bin/x-ui-temp https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
    if [[ $? -ne 0 ]]; then
        echo -e "${red}下载x-ui.sh失败${plain}"
        exit 1
    fi

    # 停止旧服务并清理
    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui 2>/dev/null
        rm /usr/local/x-ui/ -rf
    fi

    # 解压并配置
    tar zxvf x-ui-linux-${arch}.tar.gz
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui x-ui.sh bin/xray-linux-${arch}
    if [[ $arch == "armv5" || $arch == "armv6" || $arch == "armv7" ]]; then
        mv bin/xray-linux-${arch} bin/xray-linux-arm
        chmod +x bin/xray-linux-arm
    fi

    # 更新命令行工具
    mv -f /usr/bin/x-ui-temp /usr/bin/x-ui
    chmod +x /usr/bin/x-ui

    # 配置系统服务
    cp -f x-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui

    # 安装后配置
    config_after_install

# 输出完成信息
    echo -e "${green}x-ui ${tag_version} 安装完成，已启动${plain}"
    echo -e ""
    echo -e "┌───────────────────────────────────────────────────────┐
│  ${blue}x-ui 管理命令：${plain}                                      │
│  ${blue}x-ui${plain}              - 管理菜单                        │
│  ${blue}x-ui start${plain}        - 启动服务                      │
│  ${blue}x-ui stop${plain}         - 停止服务                      │
│  ${blue}x-ui restart${plain}      - 重启服务                      │
│  ${blue}x-ui status${plain}       - 查看状态                      │
│  ${blue}x-ui log${plain}          - 查看日志                      │
│  ${blue}x-ui update${plain}       - 更新版本                      │
│  ${blue}x-ui uninstall${plain}    - 卸载面板                      │
└───────────────────────────────────────────────────────┘"
}

# 卸载逻辑（已删除安装提示）
uninstall_x-ui() {
    check_root
    echo -e "\n${yellow}⚠️  确认卸载XUI面板？Xray也会被卸载 [默认n]：${plain}"
    read -p "Are you sure you want to uninstall? xray will also be removed! [Default n]: " confirm
    [[ -z "$confirm" ]] && confirm="n"
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${green}已取消卸载${plain}"
        exit 0
    fi

    # 停止服务
    systemctl stop x-ui 2>/dev/null
    systemctl disable x-ui 2>/dev/null
    rm -f /etc/systemd/system/x-ui.service
    systemctl daemon-reload

    # 清理文件
    rm -rf /usr/local/x-ui
    rm -f /usr/bin/x-ui

    echo -e "\n${green}Uninstalled Successfully.${plain}"
    # 已删除原有的安装提示行
}

# 主流程
if [[ "$1" == "uninstall" ]]; then
    uninstall_x-ui
else
    install_x-ui
fi
