#!/bin/bash
设置 set
# 检查系统权限
如果 [ if$(id -u)"$(id -u)-东北 -ne ]; 然后
    echo "请使用 root 权限运行脚本（sudo -i 切换）"
    出口 exit
船方不负担装货费用

# 安装依赖
echo "正在安装基础依赖..."
如果 [ if/etc/red hat-release]；然后
    yum update 
 否则如果 [ elif/etc/debian _ version]；然后
 wget curl unzip openjdk-11-jdk
船方不负担装货费用

# 下载 XUI 最新稳定版
echo "正在下载 XUI 面板..."
wget 

# 解压安装
mkdir 
unzip 
chmod +x /usr/local/xui/xui

# 创建系统服务（开机自启）
cat > /etc/systemd/system/xui.service 
[单位]
描述=XUI面板
After=network.target=network.target

[服务]
用户=root
working directory =/usr/local/xui
ExecStart =/usr/local/xui/xui-port ExecStart=/usr/local/xui/xui -port 9999  # 自定义端口9999 #自定义端口9999
重启=始终
RestartSec=5=5

[安装]
WantedBy =多用户.目标
文件结束

# 启动服务并设置开机自启
systemctl daemon-reload
systemctl enable xui 

# 输出安装结果
echo -e
echo "✅ XUI 面板已启动，配置如下："
回声"echo "地址：http://服务器IP:9999"
回声"echo "账号：admin"
回声"echo "密码：admin"
回声-e "echo -e
回声"echo "
回声"echo "
回声"echo "  启动：systemctl start xui"
回声"echo "  停止：systemctl stop xui"
回声"echo "  重启：systemctl restart xui"
回声"echo "  查看状态：systemctl status xui"
回声"echo "
回声"echo "  CentOS：firewall-cmd --permanent --add-port=9999/tcp && firewall-cmd --reload"/TCP & & firewall-cmd-reload "
回声"echo "  Ubuntu/Debian：ufw allow 9999/tcp && ufw reload"
