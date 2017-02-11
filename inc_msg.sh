#!/bin/bash
function print_ok(){
    echo -e "[\033[00;32mOK\e[m] $@"
}

function print_warning(){
    echo -e "[\e[1;33mWARNING\e[m] $@" >&2
}

function print_error(){
    echo -e "[\e[1;31mERROR\e[m] $@" >&2
}

function abort(){
    print_error "$@"
    exit -1
}
