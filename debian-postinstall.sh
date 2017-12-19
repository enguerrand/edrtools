#!/bin/bash
set -e
SOURCES_LIST=/etc/apt/sources.list
PKG_RECOMMENDS="chrony mlocate ncdu sudo system-config-printer"
PKG_UNRECOMMENDS="rpcbind memtest86+ nano"
INSTALL_RECOMMENDS="n"
REMOVE_UNRECOMMENDS="n"
GRUB_TIMEOUT="n"
VIM="n"
APT_LISTS="n"
REMOTE_SUPPORT="n"
UNATTENDED_UPGRADES="n"
FIREWALL="n"
GREETER_SHOW_USERS="n"
PERSISTENT_JOURNALD="n"
DISABLE_BLUETOOTH="n"

function abort(){
    echo "Error: $@" >&2
    exit -1
}

function print_usage(){
    cat << EOF
Usage: $(basename $0)"

Postinstall script targeted at Debian installs.
Must be executed as root.
EOF
}

function ask_y(){
    local _confirm="initial"
    local _prefix=""
    local _suffix=" [Yn]: "
    while ! [ -z "$_confirm" ] && ! [[ "$_confirm" =~ ^[YyNn]$ ]]; do
        read -p "${_prefix}${@}${_suffix}" _confirm
        _prefix="Invalid input! "
        ! [[ "$_confirm" =~ [nN] ]]
    done
}

function apt_lists() {
    sed -i -e "s/^deb-src/#deb-src/g" $SOURCES_LIST
    sed -i -e "s/ main$/ main contrib non-free/g" $SOURCES_LIST
    ${EDITOR:-vi} $SOURCES_LIST
}

function install_recommends(){
    apt install $PKG_RECOMMENDS
}

function remove_unrecommends(){
    apt remove $PKG_UNRECOMMENDS
}

function unattended_upgrades(){
    apt install unattended-upgrades
    dpkg-reconfigure -plow unattended-upgrades
    systemctl enable unattended-upgrades
}

function setup_vim(){
    apt install vim-nox
    echo "set mouse=" >> ~/.vimrc
    vim /etc/vim/vimrc
}

function firewall(){
    apt install -y git
    [ -d edrtools ] || cd /opt && git clone https://github.com/enguerrand/edrtools.git
    /opt/edrtools/install_firewall.sh
    systemctl enable firewall
    systemctl start firewall
}

function grub_timeout(){
    sed -i -e 's/^\(GRUB_TIMEOUT=\)[0-9]*$/\110/g' /etc/default/grub
    vi /etc/default/grub
}

function remote_support(){
    apt install openssh-server openvpn
    echo "TODO: fix sshd_config"
    echo "TODO: configure vpn"
    echo "TODO: enable vpn && ssh server"
}

function greeter_show_users(){
    sed -i -e "s/^#greeter-hide-users=false$/greeter-hide-users=false/g" /etc/lightdm/lightdm.conf
}

function persistent_journald(){
    mkdir -v -p /var/log/journal
}

function disable_bluetooth(){
    apt install rfkill sudo
    local _script="/usr/local/bin/disable_bluetooth.sh"
    echo '#!/bin/bash' > $_script
    echo 'rfkill block bluetooth' >> $_script
    chmod +x $_script
    echo "Take the following line into the clipboard before we call visudo: "
    echo "ALL ALL = NOPASSWD: /usr/local/bin/disable_bluetooth.sh"
    read -p "Hit enter to proceed to visudo" foo
    visudo
    echo "Now add the following command to autostart with a 5 seconds delay:"
    echo $_script
    read -p "Hit enter to continue"
}

function print_remaining_todos(){
    cat << EOF
Edit fstab (check swap uid. Also check swap ui on parallel installs!)
install missing fireware / mesa 
Migrate Thunderbird profile
Migrate Firefox profile
Change nemo favorites to data directory if applicable
Add user to group "sudo"
EOF
}

if [ "x$1" == "x-h" ] || [ "x$1" == "x--help" ];then
    print_usage
    exit 0
fi

[ "$(id -u)" == "0" ] || abort "Run as root!"


ask_y "Setup vim?" && \
    VIM="y"

ask_y "/etc/apt/sources.list -> Enable contrib & non-free and disable deb-src?" && \
    APT_LISTS="y"

ask_y "Setup iptables-based firewall?" && \
    FIREWALL="y"

ask_y "Setup unattended security updates?" && \
    UNATTENDED_UPGRADES="n"

ask_y "Configure remote support (ssh & vpn)?" && \
    REMOTE_SUPPORT="y"

ask_y "Install recommended packages $PKG_RECOMMENDS?" && \
    INSTALL_RECOMMENDS="y"

ask_y "Remove unrecommended packages $PKG_UNRECOMMENDS?" && \
    REMOVE_UNRECOMMENDS="y"

ask_y "Increase GRUB Timeout?" && \
    GRUB_TIMEOUT="y"

ask_y "Show user choice on login screen?" && \
    GREETER_SHOW_USERS="y"

ask_y "Enable persistent storage of journald logs?" && \
    PERSISTENT_JOURNALD="y"

ask_y "Disable automatic activation of bluetooth on startup?" && \
    DISABLE_BLUETOOTH="y"

[ "$APT_LISTS" == "y" ] && apt_lists
[ "$VIM" == "y" ] && setup_vim
apt update && apt -y full-upgrade
[ "$GRUB_TIMEOUT" == "y" ] && grub_timeout
[ "$REMOTE_SUPPORT" == "y" ] && remote_support
[ "$FIREWALL" == "y" ] && firewall
[ "$UNATTENDED_UPGRADES" == "y" ] && unattended_upgrades
[ "$INSTALL_RECOMMENDS" == "y" ] && install_recommends
[ "$REMOVE_UNRECOMMENDS" == "y" ] && remove_unrecommends
[ "$REMOVE_UNRECOMMENDS" == "y" ] || [ "$GRUB_TIMEOUT" == "y" ] && update-grub
[ "$GREETER_SHOW_USERS" == "y" ] && greeter_show_users
[ "$PERSISTENT_JOURNALD" == "y" ] && persistent_journald
[ "$DISABLE_BLUETOOTH" == "y" ] && disable_bluetooth
print_remaining_todos
