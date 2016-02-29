#!/bin/bash
BASEDIR=$(dirname $0)
source $BASEDIR/inc_msg.sh
function set_dependencies(){
    export DEPENDENCIES="$@"
}

function print_dependencies(){
    local _dep;
    echo "Requires:"
    for _dep in $DEPENDENCIES; do
        echo "     $_dep"
    done
}

function check_dependencies(){
    local _dep;
    for _dep in $DEPENDENCIES; do
        check_dependency $_dep
    done
}

function check_dependency(){
    local _dep=$1
    which $_dep >/dev/null 2>&1 || abort "Missing dependency: $_dep"
    local _executable=$(which $_dep)
    [ -x $_executable ] || abort "Not executable: $_executable"
}
