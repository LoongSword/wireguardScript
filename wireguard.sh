#!/bin/bash

#服务端ip
ipv4ServerAddress="192.0.2.1"
ipv6ServerAddress="2001:db8:1::1"
#域名或者公网ip
publicAddress=""
#端口
UDPListenPort=12345
#需要转发的ip段
ClientAllowedIPs="192.0.2.0/24,2001:db8:1::0/32"
DNSIps="8.8.8.8, 114.114.114.114"

COM_OS="no"
wireguardwg=""
_red_println() {
    printf '\e[1;31;31m%b\n\e[0m' "$1"
}
_purple_println() {
    printf '\e[1;31;35m%b\n\e[0m' "$1"
}
_yellow_println() {
    printf '\033[1;31;33m%b\n\033[0m' "$1"
}
_cyan_println() {
    printf '\033[1;31;36m%b\n\033[0m' "$1"
}

_red_print() {
    printf '\e[1;31;31m%b\e[0m' "$1"
}
_purple_print() {
    printf '\e[1;31;35m%b\e[0m' "$1"
}
_yellow_print() {
    printf '\033[1;31;33m%b\033[0m' "$1"
}
_cyan_print() {
    printf '\033[1;31;36m%b\033[0m' "$1"
}

_blue_backgrounda_println() {
    printf '\033[1;37;44m%b\n\033[0m' "$1"
}
_blue_backgrounda_print() {
    printf '\033[1;37;44m%b\033[0m' "$1"
}

_info() {
    printf -- "%s" "[$(date "+%Y-%m-%d %H:%M:%S")] "
    printf -- "%s" "$1"
    printf "\n"
}


_exists() {
    local cmd="$1"
    if eval type type > /dev/null 2>&1; then
        eval type "$cmd" > /dev/null 2>&1
    elif command > /dev/null 2>&1; then
        command -v "$cmd" > /dev/null 2>&1
    else
        which "$cmd" > /dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
}
_error() {
    printf -- "%s" "[$(date "+%Y-%m-%d %H:%M:%S")] "
    _red_println "$1"
    exit 2
}

_warning() {
    printf -- "%s" "[$(date "+%Y-%m-%d %H:%M:%S")] "
    _yellow_println "$1"
}

_os() {
    local os=$(cat /etc/os-release | awk -F '[".]' '$1=="ID="{print $2}')
    if [ -z $os ]; then
        os=$(cat /etc/os-release | awk -F '[=.]' '$1=="ID"{print $2}')
    fi
    printf -- "%s" "${os}"
}

_os_ver() {
    local version=$(cat /etc/os-release | awk -F '[".]' '$1=="VERSION_ID="{print $2}')
    printf -- "%s" "${version%%.*}"
}

_os_ver_all() {
    local version_all=$(cat /etc/os-release | awk -F '[".]' '$1=="VERSION="{print $2}')
    printf -- "%s" "${version_all%%.*}"
}
check_os() {
    _info "Check OS version"
    if _exists "virt-what"; then
        virt="$(virt-what)"
    elif _exists "systemd-detect-virt"; then
        virt="$(systemd-detect-virt)"
    fi
    if [ -n "${virt}" -a "${virt}" = "lxc" ]; then
        _error "Virtualization is LXC, which is not supported."
    fi
    if [ -n "${virt}" -a "${virt}" = "openvz" ] || [ -d "/proc/vz" ]; then
        _error "Virtualization is OpenVZ, which is not supported."
    fi
    [ -z "$(_os)" ] && _error "Not supported OS"
    case "$(_os)" in
        ubuntu)
            [ -n "$(_os_ver)" -a "$(_os_ver)" -lt 16 ] && _error "Not supported OS, please change to Ubuntu 16+ and try again."
            _info "os is $(_os_ver_all)"
            COM_OS="ubuntu"
            ;;
        debian)
            [ -n "$(_os_ver)" -a "$(_os_ver)" -lt 8 ] &&  _error "Not supported OS, please change to De(Rasp)bian 8+ and try again."
            _info "os is $(_os_ver_all)"
            COM_OS="debian"
            ;;
        arch)
            _info "os is arch"
            COM_OS="arch"
            ;;
        centos)
            [ -n "$(_os_ver)" -a "$(_os_ver)" -lt 7 ] &&  _error "Not supported OS, please change to CentOS 7+ and try again."
            _info "os is $(_os_ver_all)"
            COM_OS="centos"
            ;;
        *)
            _error "Not supported OS"
            ;;
    esac
}
wireguard_client_install(){
    check_os
    _info "start install wireguard"
    case "$COM_OS" in
            ubuntu)
                if _exists "wg" && _exists "wg-quick"; then
                    _error "debian WireGuard is installed"
                else
                    apt-get -y install wireguard openresolv iptables
                    _success_failed $? "install wireguard"
                    _create_folder
                fi
                ;;
            debian)
                if _exists "wg" && _exists "wg-quick"; then
                    _error "debian WireGuard is installed"
                else
                    apt-get -y install wireguard openresolv iptables
                    _success_failed $? "debian install wireguard"
                    _create_folder
                fi
                ;;
            arch)
                if _exists "wg" && _exists "wg-quick"; then
                    _error "arch WireGuard is installed"
                else
                    pacman  --noconfirm -S wireguard-tools openresolv iptables
                    _success_failed $? "arch install wireguard"
                    _create_folder
                fi
                ;;
            centos)
                if _exists "wg" && _exists "wg-quick"; then
                    _error "WireGuard is installed"
                else
                    if [ $(_os_ver) -eq 7 ]; then
                        yum install -y yum-utils epel-release && yum-config-manager --setopt=centosplus.includepkgs=kernel-plus --enablerepo=centosplus --save && sed -e 's/^DEFAULTKERNEL=kernel$/DEFAULTKERNEL=kernel-plus/' -i /etc/sysconfig/kernel && yum install -y kernel-plus wireguard-tools iptables
                        _success_failed $? "centos install wireguard"
                    else
                        yum install -y yum-utils epel-release && yum-config-manager --setopt=centosplus.includepkgs="kernel-plus, kernel-plus-*" --setopt=centosplus.enabled=1 --save && sed -e 's/^DEFAULTKERNEL=kernel-core$/DEFAULTKERNEL=kernel-plus-core/' -i /etc/sysconfig/kernel&& yum install -y kernel-plus wireguard-tools iptables
                        _success_failed $? "install wireguard"
                    fi
                    _warning "you need reboot"
                    _success_failed $? "centos install wireguard"
                    _create_folder
                fi
                ;;
            *)
            _error "Intstall not supported OS"
                ;;
        esac
}
wireguard_server_install() {
    check_os
    _info "start install wireguard"
    case "$COM_OS" in
            ubuntu)
                if _exists "wg" && _exists "wg-quick"; then
                    _error "ubuntu WireGuard is installed"
                else
                    apt-get -y install wireguard openresolv qrencode iptables
                    _success_failed $? "ubuntu install wireguard"
                    _ipForward_server
                    _create_folder
                    _create_server_profile
                    _enable_start_wireguard "$(cat /etc/hostname)wg"
                fi
                ;;
            debian)
                if _exists "wg" && _exists "wg-quick"; then
                    _error "debian WireGuard is installed"
                else
                    apt-get -y install wireguard openresolv qrencode iptables
                    _success_failed $? "debian install wireguard"
                    _ipForward_server
                    _create_folder
                    _create_server_profile
                    _enable_start_wireguard "$(cat /etc/hostname)wg"
                fi
                ;;
            arch)
                if _exists "wg" && _exists "wg-quick"; then
                    _error "arch WireGuard is installed"
                else
                    pacman  --noconfirm -S wireguard-tools openresolv qrencode iptables
                    _success_failed $? "arch install wireguard"
                    _ipForward_server
                    _create_folder
                    _create_server_profile
                    _enable_start_wireguard "$(cat /etc/hostname)wg"
                fi
                ;;
            centos)
                if _exists "wg" && _exists "wg-quick"; then
                    _error "centos WireGuard is installed"
                else
                    if [ $(_os_ver) -eq 7 ]; then
                        yum install -y yum-utils epel-release && yum-config-manager --setopt=centosplus.includepkgs=kernel-plus --enablerepo=centosplus --save && sed -e 's/^DEFAULTKERNEL=kernel$/DEFAULTKERNEL=kernel-plus/' -i /etc/sysconfig/kernel && yum install -y kernel-plus wireguard-tools openresolv iptables
                        _success_failed $? "install wireguard"
                    else
                        yum install -y yum-utils epel-release && yum-config-manager --setopt=centosplus.includepkgs="kernel-plus, kernel-plus-*" --setopt=centosplus.enabled=1 --save && sed -e 's/^DEFAULTKERNEL=kernel-core$/DEFAULTKERNEL=kernel-plus-core/' -i /etc/sysconfig/kernel&& yum install -y kernel-plus wireguard-tools openresolv iptables
                        _success_failed $? "install wireguard"
                    fi
                    _warning "you need reboot"
                    _success_failed $? "centos install wireguard"
                    _ipForward_server
                    _create_folder
                    _create_server_profile
                    _enable_start_wireguard "$(cat /etc/hostname)wg"
                fi
                ;;
            *)
            _error "Intstall not supported OS"
                ;;
        esac
}
_ipForward_server(){
    #ipv4
    ipv4=$(cat /etc/sysctl.conf | awk '/net.ipv4.ip_forward/')
    if [[ -z $ipv4 ]]; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        _success_failed $? "ipv4 forwad"
    else
        _info "ipv4 forwad is Already exists"
    fi
    #ipv6
    ipv6=$(cat /etc/sysctl.conf | awk '/net.ipv6.conf.all.forwarding/')
    if [[ -z $ipv6 ]]; then
        echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
        _success_failed $? "ipv6 forwad"
    else
        _info "ipv6 forwad is Already exists"
    fi
    sysctl -p
}
_create_folder(){
    if [ ! -d "/etc/wireguard/" ];then
        mkdir -p /etc/wireguard && chmod 0777 /etc/wireguard
        _success_failed $? "create folder wireguard"
        cd /etc/wireguard
        umask 077
    else
        _info "Folder already exists"
        cd /etc/wireguard
    fi

}
_create_server_profile(){
    wg genkey | tee server_privatekey | wg pubkey > server_publickey
    count=0
    networkCardsId=""
    declare -a networkCards
    for i in `ls /sys/class/net/`;do
        networkCards[${count}]=${i}
        networkCardsId="$count:${i}                   ""$networkCardsId"
        count=$(expr ${count} + 1)
    done
    _yellow_println "network card number :       $networkCardsId"
    read -p "Please enter the network card number :  " networkCard
    _info "Selected network card :   "${networkCards[$networkCard]}
    read -p "Please enter the ipv4, server ipv4 : " -e -i "${ipv4ServerAddress}" ipv4Address
    read -p "Please enter the ipv6, server ipv6 : "  -e -i "${ipv6ServerAddress}" ipv6Address
    echo "
    [Interface]
    PrivateKey = $(cat server_privatekey)
    Address = $ipv4Address/24,$ipv6Address/32
    PostUp = iptables -I INPUT -p udp --dport ${UDPListenPort} -j ACCEPT
    PostUp = iptables -I FORWARD -i ${networkCards[$networkCard]} -o $(cat /etc/hostname)wg -j ACCEPT
    PostUp = iptables -I FORWARD -i $(cat /etc/hostname)wg -j ACCEPT
    PostUp = iptables -t nat -A POSTROUTING -o ${networkCards[$networkCard]} -j MASQUERADE
    PostUp = ip6tables -I FORWARD -i $(cat /etc/hostname)wg -j ACCEPT
    PostUp = ip6tables -t nat -A POSTROUTING -o ${networkCards[$networkCard]} -j MASQUERADE
    PostDown = iptables -D INPUT -p udp --dport ${UDPListenPort} -j ACCEPT
    PostDown = iptables -D FORWARD -i ${networkCards[$networkCard]} -o $(cat /etc/hostname)wg -j ACCEPT
    PostDown = iptables -D FORWARD -i $(cat /etc/hostname)wg -j ACCEPT
    PostDown = iptables -t nat -D POSTROUTING -o ${networkCards[$networkCard]} -j MASQUERADE
    PostDown = ip6tables -D FORWARD -i $(cat /etc/hostname)wg -j ACCEPT
    PostDown = ip6tables -t nat -D POSTROUTING -o ${networkCards[$networkCard]} -j MASQUERADE
    ListenPort = $UDPListenPort
    MTU = 1420 " | tee  $(cat /etc/hostname)wg.conf >/dev/null
    _success_failed $? "create wireguard configuration file $(cat /etc/hostname)wg.conf"
}

_success_failed(){
    if [ $1 -eq 0 ]; then
        _info "$2 success"
    else
        _error "$2 failed"
    fi
}

_enable_start_wireguard(){
    systemctl enable wg-quick@$1
    _success_failed $? "enable start up wg-quick@$1"
}
_disable_start_wireguard(){
    systemctl enable wg-quick@$1
    _success_failed $? "disable start up wg-quick@$1"
}

wireguard_uninstall(){
    read -p "Whether to stop the wireguard service y/n, default y : " down
    case "$down" in
    y)
        wg-quick down $(cat /etc/hostname)wg
        _success_failed $? "stop wireguard"
        ;;
    '')
        wg-quick down $(cat /etc/hostname)wg
        _success_failed $? "stop wireguard"
        ;;
    *)
        _warning "You may need to manually stop the service"
        ;;
    esac

    check_os
    _info "start uninstall wireguard"
    case "$COM_OS" in
        ubuntu)
            if _exists "wg" && _exists "wg-quick"; then
                apt-get remove -y wireguard-tools
                _success_failed $? "ubuntu wireguard uninstall"
            else
                _error "ubuntu WireGuard is uninstalled"
            fi
            ;;
        debian)
            if _exists "wg" && _exists "wg-quick"; then
                apt-get remove -y wireguard-tools
                _success_failed $? "debian wireguard uninstall"
            else
                _error "debian WireGuard is uninstalled"
            fi
            ;;
        arch)
            if _exists "wg" && _exists "wg-quick"; then
                pacman --noconfirm -Rs wireguard-tools
                _success_failed $? "arch wireguard uninstall"
            else
                _error "arch WireGuard is uninstalled"
            fi
            ;;
        centos)
            _info "start install wireguard"
            if _exists "wg" && _exists "wg-quick"; then
                yum remove -y wireguard-tools
                _success_failed $? "centos wireguard uninstall"
            else
                _error "centos WireGuard is uninstalled"
            fi
            ;;
        *)
        _error "Intstall not supported OS"
            ;;
    esac
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    _success_failed $? "remove net.ipv4.ip_forward from /etc/sysctl.conf "
    sed -i '/net.ipv6.conf.all.forwarding/d' /etc/sysctl.conf
    _success_failed $? "remove net.ipv6.conf.all.forwarding from /etc/sysctl.conf "
    rm -rf /etc/wireguard
    _success_failed $? "remove folder /etc/wireguard "
}


wireguard_client_config_file(){
    _create_folder
    read -p "Please enter the client name : " clientName
    read -p "Please enter the ipv4, server ipv4 : " -e -i "${ipv4ServerAddress}" ipv4Address
    read -p "Please enter the ipv6, server ipv6 : "  -e -i "${ipv6ServerAddress}" ipv6Address
    clien_publickey=$clientName"_publickey"
    clien_privatekey=$clientName"_privatekey"
    wg genkey | tee $clien_privatekey | wg pubkey > $clien_publickey
    _success_failed $? "client $clien_privatekey and $clien_publickey create"
    _warning "Please save client $clientName PublicKey and PrivateKey"
    echo "
    [Interface]
    PrivateKey = $(cat $clien_privatekey)
    Address = $ipv4Address/24,$ipv6Address/32
    DNS = $DNSIps
    MTU = 1420

    [Peer]
    PublicKey = $(cat server_publickey)
    Endpoint = $publicAddress:$UDPListenPort
    AllowedIPs = $ClientAllowedIPs
    PersistentKeepalive = 25 " | tee  $clientName"wg".conf >/dev/null
    _success_failed $? "create wireguard client configuration file $clientName"wg".conf"

     echo "
     # 客户端$clientName
     [Peer]
     PublicKey =  $(cat $clien_publickey)
     AllowedIPs = $ipv4Address,$ipv6Address" | tee -a $(cat /etc/hostname)wg.conf >/dev/null
    _success_failed $? "Append wireguard configuration file $(cat /etc/hostname)wg.conf"
}

_get_wireguard_name(){
    wireguardwg="$(cat /etc/hostname)wg"
    _warning "default wireguard configuration is $wireguardwg"
    read -p "Use default wireguard configuration $wireguardwg input y, or enter wireguard configuration name,Enter default y : " wireguardwg
    case "$wireguardwg" in
    y)
        wireguardwg="$(cat /etc/hostname)wg"
        ;;
    '')
        wireguardwg="$(cat /etc/hostname)wg"
        ;;
    *)
        ;;
    esac
}

wireguard_operation(){
    _purple_println "----------------------------------------------------"
    _yellow_println " 1. start wireguard                                   "
    _purple_println " 2. stop wireguard                                   "
    _purple_println " 3. restart wireguard                                   "
    _purple_println " 4. Reload profile                                       "
    _red_println    " 5. show status                                         "
    _cyan_println   " 0. Return to main menu                                         "
    _purple_println "----------------------------------------------------"

    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
        _get_wireguard_name
        wg-quick up $wireguardwg
        echo
        echo
        wireguard_operation
        ;;
    2)
        _get_wireguard_name
        wg-quick down $wireguardwg
        echo
        echo
        wireguard_operation
        ;;
    3)
        _get_wireguard_name
        wg-quick down $wireguardwg && wg-quick up $wireguardwg
        echo
        echo
        wireguard_operation
        ;;
    4)
        _get_wireguard_name
        wg syncconf $wireguardwg <(wg-quick strip $wireguardwg)
        echo
        echo
        wireguard_operation
        ;;
    5)
        _get_wireguard_name
        wg show $wireguardwg
        echo
        echo
        wireguard_operation
    ;;
    0)
        echo
        echo
        start_wireguard
    ;;
    *)
        _red_println "Incorrect input, please enter correct serial number！！！"
        echo
        echo
        wireguard_operation
    ;;
    esac
}


wireguard_config_to_QRcode(){
    echo $(cat $1) | qrencode -o - -t UTF8
    #       qrencode -t ansiutf8 $(cat /etc/wireguard/$clientName.conf)
}
wireguard_config_to_file(){
    cat $1 | while read line
    do
    echo $line
    done
}

wireguard_choose_file_or_qr(){
   echo
   echo
    _purple_println "----------------------------------------------------"
    _yellow_println " 1. Document form                                         "
    _purple_println " 2. QR code form                                      "
    _cyan_println   " 0. Return to the previous menu                                    "
    _purple_println "----------------------------------------------------"

    echo
    read -p "please enter a number:" num
    case "$num" in
    1)
        wireguard_config_to_file $1
        ;;
    2)
        wireguard_config_to_QRcode $1
        ;;
    0)
        echo
        echo
        wireguard_config_file_display
    ;;
    *)
        _red_println "Incorrect input, please enter correct serial number！！！"
        echo
        echo
        wireguard_choose_file_or_qr
    ;;
    esac
}

wireguard_config_file_display(){
    cd /etc/wireguard
    echo
    echo
    _purple_println "----------------------------------------------------"
    _yellow_println " 1. View native profile                                 "
    _purple_println " 2. View the specified profile                               "
    _cyan_println   " 0. Return to the previous menu                             "
    _purple_println "----------------------------------------------------"

    echo
    read -p "please enter a number:" num
    case "$num" in
    1)
        _yellow_println "Native profile $(cat /etc/hostname)wg.conf"
        if [ -f "$(cat /etc/hostname)wg.conf" ];then
            wireguard_choose_file_or_qr "$(cat /etc/hostname)wg.conf"
        else
            _warning "The Native config is not found"
            wireguard_config_file_display
        fi
        echo
        echo
        wireguard_config_file_display
        ;;
    2)
        read -p "Please enter the client config name : " clientName
        _yellow_println "Profile name entered $clientName"wg.conf""
        if [ -f $clientName"wg.conf" ];then
            wireguard_choose_file_or_qr  "$clientName"wg.conf
        else
            _warning "The client config you entered is not found"

        fi
        echo
        echo
        wireguard_config_file_display
        ;;
    0)
        echo
        echo
        wireguard_operation
    ;;
    *)
        _red_println "Incorrect input, please enter correct serial number！！！"
        echo
        echo
        wireguard_config_file_display
    ;;
    esac
}


start_wireguard(){
    echo
    echo
    echo
    echo
    echo
    echo
    _purple_println "----------------------------------------------------"
    _yellow_println " 1. Install wireguard Server                            "
    _purple_println " 2. Install wireguard Client                             "
    _purple_println " 3. Create wireguard Client File                          "
    _purple_println " 4. show configuration file                                 "
    _red_println   " 5. Uninstall wireguard                                   "
    _yellow_println " 6. wireguard start and stop                                "
    _cyan_println   " 0. sign out                                         "
    _purple_println "----------------------------------------------------"


    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
        wireguard_server_install
        echo
        echo
        start_wireguard
    ;;
    2)
        wireguard_client_install
        echo
        echo
        start_wireguard
    ;;
    3)
        wireguard_client_config_file
        echo
        echo
        start_wireguard
    ;;
    4)
        wireguard_config_file_display
    ;;
    5)
        wireguard_uninstall
        echo
        echo
        start_wireguard
    ;;
    6)
        wireguard_operation
        echo
        echo
        start_wireguard
    ;;
    0)
        exit 1
    ;;
    *)
        _red_println "输入有误，请输入正确的序号！！！"
        start_wireguard
    ;;
    esac
}
clear
[ ${EUID} -ne 0 ] && _red_print "This script must be run as root\n" && exit 1
_blue_backgrounda_println "------------------------------------------------------------"
_blue_backgrounda_println " 介绍：wireguard服务端，客户端安装卸载,配置文件生成         "
_blue_backgrounda_println " 系统：Debian,ubuntu,Centos,arch                            "
_blue_backgrounda_println " 作者：LoongSword                                           "
_blue_backgrounda_println " 参与者：                                                   "
_blue_backgrounda_println "------------------------------------------------------------"
start_wireguard

