#!/bin/bash
set -e
BASEDIR=$(dirname $0)
source $BASEDIR/inc_dependencies.sh
source $BASEDIR/inc_msg.sh

set_dependencies iptables ip6tables

function print_usage(){
    echo "Usage: $(basename $0)"
    print_dependencies
}

if [ "x$1" == "x-h" ];then
    print_usage
    exit 0
fi

check_dependencies

function print_firewall_conf(){
    local _stop_file=$1
    local _conf_file=$2
cat << EOF
#!/bin/bash
# $_conf_file
#
# Iptables
FW4="$(which iptables)"
FW6="$(which ip6tables)"

# delete existing rules
$_stop_file

# Standard rules
\$FW4 -P INPUT   ACCEPT
\$FW4 -P FORWARD DROP
\$FW4 -P OUTPUT  ACCEPT
\$FW6 -P INPUT   ACCEPT
\$FW6 -P FORWARD DROP
\$FW6 -P OUTPUT  ACCEPT

# IP Protocol specific rules
\$FW4 -A INPUT -p icmp -j ACCEPT -m comment --comment "allow ping"
\$FW6 -A INPUT -p icmpv6 -j ACCEPT -m comment --comment "allow ping6"

for FW in {\$FW4,\$FW6}; do
    # INPUT
    \$FW -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    \$FW -A INPUT -i lo -j ACCEPT -m comment --comment "Allow inbound traffic on lo"
    #\$FW -A INPUT -p tcp --dport 22 -j ACCEPT -m comment --comment "Allow inbound ssh"
    \$FW -A INPUT -j DROP
done
EOF
}

print_firewall_stop(){
    local _stop_file=$1
cat << EOF
#!/bin/bash
# $_stop_file
#
# Iptables
FW4="$(which iptables)"
FW6="$(which ip6tables)"

# delete existing chains & rules
for FW in {\$FW4,\$FW6}; do
    \$FW -F
    \$FW -X
    \$FW -P INPUT   ACCEPT
    \$FW -P FORWARD ACCEPT
    \$FW -P OUTPUT  ACCEPT
done
EOF
}

print_service_file(){
    local _stop_file=$1
    local _conf_file=$2
    local _serv_file=$3
    
cat << EOF
# $_serv_file
[Unit]
Description=Custom iptables-based firewall
Wants=network.target
Before=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$_conf_file
ExecReload=$_conf_file
ExecStop=$_stop_file

[Install]
WantedBy=multi-user.target
EOF
}

CONF_DIR=/etc/firewall
CONF_FILE=${CONF_DIR}/firewall.conf
STOP_FILE=${CONF_DIR}/firewall.stop
SERV_FILE=/etc/systemd/system/firewall.service
mkdir -p ${CONF_DIR} /

[ -f ${STOP_FILE} ] && abort "File $STOP_FILE exists!"
[ -f ${CONF_FILE} ] && abort "File $CONF_FILE exists!"
echo "Installing ${STOP_FILE}"
print_firewall_stop ${STOP_FILE} > ${STOP_FILE} 
echo "Installing ${CONF_FILE}"
print_firewall_conf ${STOP_FILE} ${CONF_FILE} > ${CONF_FILE}
chmod +x ${STOP_FILE} ${CONF_FILE}

read -p "Iptables scripts installed. Install systemd service file? [Yn] " SYSTEMD
[[ "$SYSTEMD" =~ [Nn] ]] && exit 0
[ -f ${SERV_FILE} ] && abort "File $SERV_FILE exists!"
print_service_file ${STOP_FILE} ${CONF_FILE} ${SERV_FILE} > ${SERV_FILE}
echo "Service file written to ${SERV_FILE}"

