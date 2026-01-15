#!/usr/bin/env bash
#
# Template for a Bash script that uses Sudo the most secure way.
#
# Addresses many subtle points about safely using sudo from within a
# Bash script. The sudo password is only requested once at the
# beginning of the script.
#
# The functionality was extensively tested in real-world scripts.
#
# See README.md for implementation details.
#
main() {
    #
    # Make sure this script is not started under "sudo", that the user
    # is a sudoer and handle the case s/he is root.
    #
    # Next ask the for the Sudo password or exit.
    #
    # If the password was entered successfully remove any cached Sudo
    # timeout and then start the Sudo heartbeat that keeps the
    # password fresh.
    #
    exit_if_elevated
    exit_if_not_sudoer
    exit_if_root_query

    sudo -K && sudo -v || exit 1
    while true; do sleep 30; sudo -n true; kill -0 "$$" || exit; done 2>/dev/null &
    PID_SUDO_HEARTBEAT=$!
    #echo $PID_SUDO_HEARTBEAT
    if test_user_passwd_empty; then
        echo "WARNING: password of current user is empty"
    fi

    #
    # YOUR ACTUAL SCRIPT GOES HERE...
    #
    # Demonstrates that the Sudo password will not be asked again.
    #
    # Modify the timeouts to make sure this works on your system.
    #
    {
        sleep 1
        sudo echo Hello from $0
        sleep 15
        sudo echo Hello from $0
    }
}

#
# Sudo tool functions
#
function exit_if_elevated() {
    [[ -z "$SUDO_USER" ]] && return
    echo "Aborting: '$0' started under sudo (HOME='$HOME' UID=$UID)" >&2
    exit 1
}

function exit_if_root() {
    ((UID)) && return
    echo "Aborting: '$0' started under super-user (HOME='$HOME' UID=$UID)" >&2
    exit 1
}

function exit_if_root_query() {
    ((UID)) && return
    yes_or_no "You are $(whoami). Continue anyway" && return
    exit_if_root
}

function exit_if_not_sudoer() {
    if ((UID==0)) || groups | grep -w 'sudo' &>/dev/null; then
        : echo "user $(whoami) is a member of group 'sudo'"
    else
        echo "Aborting: '$0' requires that user '$(whoami)' can execute 'sudo' commands" >&2
        exit 1
    fi
}

function yes_or_no() {
    local key
    while ((1)); do
        echo -n "${1:-Continue}? [y/N]"
        read -sn1 key
        echo
        case "$key" in y) break;; ''|n) return 1;; esac
    done
}

function test_user_passwd_empty() {
    local u=($(sudo getent shadow | grep '^[^:]*::' | cut -d: -f1))
    local i=$(whoami)
    local v
    for v in "${u[@]}"; do
        [[ "$v" == "$i" ]] && return 0
    done
    return 1
}

#
# Run the script
#
main
RESULT=$?

# Exit the script
kill $PID_SUDO_HEARTBEAT
exit $RESULT

