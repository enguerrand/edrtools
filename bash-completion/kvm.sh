[ -d $HOME/.kvmrc/ ] && complete -W "$(find $HOME/.kvmrc/ \( ! -name default -a ! -name ".*" \) -type f -printf "%f\n")" kvm
