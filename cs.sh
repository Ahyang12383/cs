#!/bin/bash
#足球5一键部署脚本（基于shadowsocks-libev)
# 依赖:curl、unzip、libssl-dev等

# 检查是否为根用户
如果 [ "$(id -u)" -东北 0 ]; 然后
回声"❌ 请使用根用户运行(须藤一切换)"
  出口 1
船方不负担装货费用

# 安装依赖
回声"🔧 正在安装依赖..."
apt更新表示“有…的”& apt安装表示“有…的”curl unzip build-essential libssl-dev libpcre 3戴夫 libev-dev asciidoc xmlto automake libtool

# 下载并编译shadowsocks-libev(最新稳定版)
SS _版本="3.3.5"
回声"📥 正在下载shadowsocks-libev v${SS_VERSION}..."
wget https://github . com/shadow socks/shadow socks-libev/releases/download/v${SS_VERSION}/shadowsocks-libev-${SS_VERSION}. tar.gz
水手-zxfshadowsocks-libev-${SS_VERSION}. tar.gz && cd shadowsocks-libev-${SS_VERSION}

。/配置-前缀=/usr/local
制作并制作安装
激光唱片..&& rm-射频shadowsocks-libev-${SS_VERSION}*

# 配置足球5(自定义端口、密码)
阅读-p "🔑 请设置足球5密码（建议8位以上):"SS _通行证
阅读-p "📡 请设置监听端口（1024-65535，例如 1080）："SS _端口

# 创建配置文件
cat >/etc/shadow socks-libev/config . JSON< < EOF
{
"服务器":" 0.0.0.0 "，
"服务器端口":${SS端口}，
"密码":" ${SS_PASS} "，
【超时】:300，
“方法”:“chacha20-ietf-poly1305”，
"模式":" tcp_and_udp "
}
文件结束

# 创建系统服务（开机自启）
cat >/etc/systemd/system/shadow socks-libev . service< < EOF
[单位]
description = shadow socks-libev socks 5服务器
After=network.target

[服务]
类型=简单
ExecStart =/usr/local/bin/ss-server-c/etc/shadow socks-libev/config . JSON
重启=开-失败

[安装]
WantedBy =多用户.目标
文件结束

# 启动服务并设置开机自启
systemctl守护程序-重新加载
system CTL start shadow socks-libev
systemctl启用shadowsocks-libev

# 检查运行状态
如果系统控制处于激活状态安静shadow socks-利贝夫；然后
回声-e “n🎉足球5服务部署成功!"
回声-e "📋 连接信息："
回声-e "服务器IP:$(科尔-icanhazip.com)"
回声-e "  端口：${SS_PORT}"
回声-e "  密码：${SS_PASS}"
回声-e "加密方式:chacha20-ietf-poly1305 "
回声-e "协议:Socks5(支持TCP/UDP)"
其他
回声-e “n❌服务启动失败,请检查日志:journalctl -u shadowsocks-libev "
船方不负担装货费用
