#!/usr/bin/env bash
#
# Template for a Bash script that uses sudo securely.
#
# See README.md for details.
#
function main {
    # test user privileges
    exit_if_elevated
    exit_if_unprivileged
    exit_if_root_query

    # install sudo heartbeat
    sudo -K && sudo -v || exit 1
    while true; do sleep 30; sudo -n true; kill -0 "$$" || exit; done 2>/dev/null &
    PID_SUDO_HEARTBEAT=$!
    test_user_passwd_empty

    # run the actual script
    {
        # modify the timeouts to make sure the sudo password is not requested on
        # your system.
        sleep 1
        sudo echo hello
        sleep 2
        sudo echo World
    }
}

function exit_if_elevated {
    [[ -z "$SUDO_USER" ]] && return
    echo "Aborting: '$0' started under sudo (HOME='$HOME' UID=$UID)" >&2
    exit 1
}

function exit_if_root {
    # exit 1 unless user is root
    ((UID)) && return
    echo "Aborting: '$0' started under superuser (HOME='$HOME' UID=$UID)" >&2
    exit 1
}

function exit_if_root_query {
    # exit 1 unless user is root and wants to continue
    ((UID)) && return
    yes_or_no "You are root. Continue anyway" && return
    exit 1
}

function exit_if_unprivileged {
    # exit 1 unless user is root or a sudoer
    ((UID==0)) && return
    sudo -ln &>/dev/null && return
    echo "Aborting: user '$(whoami)' can't execute superuser commands" >&2
    exit 1
}

function yes_or_no {
    local key
    while ((1)); do
        echo -n "${1:-Continue}? [y/N]"
        read -sn1 key
        echo
        case "$key" in y) break;; ''|n) return 1;; esac
    done
}

function test_user_passwd_empty {
    local u=($(sudo getent shadow | grep '^[^:]*::' | cut -d: -f1))
    local i=$(whoami)
    local v
    for v in "${u[@]}"; do
        if [[ "$v" == "$i" ]]; then
            echo "WARNING: password of user '$(whoami)' is empty" >&2
            return 0
        fi
    done
    return 1
}

# Treat unset variables and parameters other than the special parameters “@” and
# “*”, or array variables subscripted with “@” or “*”, as an error when
# performing parameter expansion. If expansion is attempted on an unset variable
# or parameter, the shell prints an error message, and, if not interactive,
# exits with a non-zero status.

set -u

# If set, the return value of a pipeline is the value of the last (rightmost)
# command to exit with a non-zero status, or zero if all commands in the
# pipeline exit successfully. This option is disabled by default.

set -o pipefail

# If set, pathname expansion patterns which match no files expand to nothing and
# are removed, rather than expanding to themselves.

shopt -s nullglob

main
RESULT=$?
kill $PID_SUDO_HEARTBEAT
exit $RESULT

