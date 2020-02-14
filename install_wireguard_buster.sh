#!/bin/bash
set -e
function print_usage(){
    cat << EOF
Usage: $(basename $0)
EOF
}
function abort(){
    echo "Error: $@" >&2
    exit -1
}
if [ "x$1" == "x-h" ] || [ "x$1" == "x--help" ];then
    print_usage
    exit 0
fi

list=/etc/apt/sources.list.d/unstable.list
prefs_unstable=/etc/apt/preferences.d/limit-unstable
prefs_wireguard=/etc/apt/preferences.d/limit-unstable
[ -e "${list}" ] && abort "File ${list} already exists!"
[ -e "${prefs_unstable}" ] && abort "File ${prefs_unstable} already exists!"
[ -e "${prefs_wireguard}" ] && abort "File ${prefs_wireguard} already exists!"
echo "deb http://deb.debian.org/debian/ unstable main" > ${list}
cat > ${prefs_unstable} << EOF
Package: *
Pin: release a=unstable
Pin-Priority: -1
EOF

cat > ${prefs_wireguard} << EOF
Package: wireguard*
Pin: release a=unstable
Pin-Priority: 90
EOF

apt update
apt install linux-headers-$(uname -r) wireguard
