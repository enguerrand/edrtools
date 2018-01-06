#!/bin/bash
set -e
SOURCES_LIST=/etc/apt/sources.list
PKG_RECOMMENDS="chrony mlocate ncdu sudo system-config-printer screen"
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

function print_user(){
    grep "^[^:]*:x:1000:" /etc/passwd | cut -d':' -f 1
}

function install_pubkey(){
    local _username=$(print_user)
    local _userhome=/home/${_username}
    [ -d "${_userhome}" ] || read -p "Could not autodetect home directory. Please specify it: " _userhome
    if [ -d "${_userhome}" ]; then
        local _ssh_dir=${_userhome}/.ssh
        mkdir -p ${_ssh_dir}
        chmod 700 ${_ssh_dir}
        local _keysfile=${_ssh_dir}/authorized_keys
        echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrGQJotAFOgKxtExapqFsCTAnzfRzfQPkymVahIGhTCa1o13CG7RSXX/uFX7K/JFetWnmtb2XihZFDHaICfp2/M0MKvvP3UBoHg7GS+4trtS/4FySylxCSlyby5xDbxVJHDvcO98IvLB0h4kAV5+/V4lSZyhC+oKjCkHtbsO0TAmgW4/9Oavh0dNDG3G3B8FH21koAIj9sO+QGIFBs71bbXAFBL/0vCl/+spRC+dxKDzDgJ8QsIS0wK8KdZA7LKZc0ooSLxac1PTzRq1YDQp6grxeNCxrOyEK+nCHzCVVp6+jDoHK5WEUKpombzpL20ZKjdGh0IH749ch/xgAb+Wat edr-pwd" >> ${_keysfile}
        chmod 600 ${_keysfile}
        chown -R ${_username}:${_username} ${_ssh_dir}
        echo "Public ssh key installed to ${_keysfile}"
    else
        echo "Could not find home directory ${_userhome}. No public key installed"
    fi
}

function find_vpn_sample_config(){
	local _path=/usr/share/doc/openvpn/examples/sample-config-files/client.conf
	[ -f "${_path}" ] || _path=$(find /usr/share/doc/openvpn/examples -name client.conf | head -n 1)
	[ -f "${_path}" ] || _path=$(find /usr/share/doc/openvpn/ -name client.conf | head -n 1)
	echo ${_path}
}

function create_vpn_client_conf(){
    local _config_file=/etc/openvpn/client.conf
    local _keyname=""
	local _key_file=$(find /etc/openvpn/keys/ -name "*.key")
	if [ -f "${_key_file}" ]; then
		local _file_name=$(basename "${_key_file}")
		_keyname=${_file_name%.*}
	fi
    [ -z "$_keyname" ] && read -p "Enter client key name: " _keyname
    cat > ${_config_file} << EOF
client
dev tun
proto udp
remote beast.rochefort.de 1194
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
ca /etc/openvpn/keys/ca.crt
cert /etc/openvpn/keys/${_keyname}.crt
key /etc/openvpn/keys/${_keyname}.key
remote-cert-tls server
;tls-auth ta.key 1
;cipher AES-256-CBC
comp-lzo
verb 3
EOF
	echo "Installed client config file $_config_file"
    ask_y "Compare to sample config file?" && \
		vimdiff $_config_file $(find_vpn_sample_config)
}

function remote_support(){
    apt install openssh-server openvpn
    echo "Edit sshd_config" && sleep 1 && vi /etc/ssh/sshd_config
    echo "TODO: configure vpn"
    systemctl enable openvpn
    systemctl enable ssh
    ask_y "Install edr's public ssh key? (Only do this if you are me!)" && \
        install_pubkey
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
Install vpn keys and create client.conf
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
