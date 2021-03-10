#!/bin/bash
set -e
BASEDIR=$(dirname $0)
source $BASEDIR/inc_dependencies.sh

set_dependencies xclip

function print_usage(){
    cat << EOF
Usage: $(basename $0)

EOF
    print_dependencies
}
if [ "x$1" == "x-h" ] || [ "x$1" == "x--help" ];then
    print_usage
    exit 0
fi

check_dependencies

echo -n $(date +"%F") | xclip -selection clipboard
