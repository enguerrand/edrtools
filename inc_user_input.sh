#!/bin/bash
#
# Builds a multiple choice menu
# Example:
#
# ~$ source /opt/edrtools/inc_user_input.sh
# ~$ mchoice MY_RESULT foo bar "two words"
# 1) foo
# 2) bar
# 3) two words
# Your choice: 2
# ~$ echo $MY_RESULT
# bar
#
function mchoice(){ 
    local result_var_name=$1
    [ -z $result_var_name ] && return
    shift
    local index=1
    local args=("$@")
    while true; do
        for opt in "${args[@]}"; do
            echo "${index}) $opt"
            index=$[ $index + 1 ]
        done
        read -p "Your choice: " choice
        local choice_index=$[ $choice - 1 ]
        local result=${args[${choice_index}]}
        if [ -z "$result" ] || [ $choice_index -lt 0 ]; then
            index=1;
            continue;
        fi
        read -r ${result_var_name} <<< "$result"
        export ${!result_var_name}
        break
    done
}
