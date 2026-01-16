
## Synopsis ##

*secure-sudo.sh* is a template for Bash scripts using `sudo`.

The functionality was extensively tested in real-world scripts before
published here.

The makefile simply runs `secure-sudo.sh` as a test case.

## Motivation ##

While UNIX systems and APIs are now standardized with Linux, the
privileges under which processes are executed remain a frontier.

`sudo` allows the user role to be changed temporarily.

`sudo` can be used from within Bash scripts, but this requires special
attention sicnce `sudo` is geared towards commandline use.

## Description ##

> sudo, allows a permitted user to execute a command as the superuser
> or another user, as specified by the security policy. The invoking
> user's real (not effective) user-ID is used to determine the user
> name with which to query the security policy.

Every call to `sudo` starts a new session on a timer. This is the sudo
timestamp (usually 5-15 minutes). When it expires the user needs to
re-authenticate to Linux.

### Challenges for scripts that require sudo  ###

#### Starting the script via sudo ####

A risky solution is to start the script that internally requires
`sudo` using `sudo`. UID 0 for everything can mess with file
permissions, accidentially kill processes or change passwords.

Best practices:
- validate active user and maybe even commands upfront
- assume the session timeout is unknown
- run only the necessary commands under `sudo`

#### Frequent reauthentications ####

If the time between each `sudo` call is too long the script is halted
to repeatedly request the password. This problem was solved by [this
Github gist](https://gist.github.com/cowboy/3118588):
- ask for the password once
- start a `sudo -n true` heartbeat
- update the timer every 60 seconds

Under Linux the lowest `sudo` timeout can be 1 minute. During testing
of `secure-sudo.sh` such a low value triggered race conditions. A
value of 30 seconds resolved the issue.

#### Sudo may not execute the command ####

`sudo` will not execute a command from the script if the user is not
privileged or types the wrong password, but the rest of the script is.

Is the user privileged enough?

> If the -l option was specified without a command, sudo, will exit
> with a value of 0 if the user is allowed to run sudo, and they
> authenticated successfully (as required by the security policy). 

Are the commands used permitted?

> If a command is specified with the -l option, the exit value will
> only be 0 if the command is permitted by the security policy,
> otherwise it will be 1.

#### Sudo may never prompt ####

If the user password is empty, sudo always works (no password prompt
occurs and the timeout does not apply). For example, the script may
always work in a VM in which the developer removed the password for
convenience (`passwd -d`).

Note that malicious code snippets from the web may count on empty
passwords only to make hidden use of `sudo` to gain control.

#### Sudo may ask for the password every time ####

The sudo timeout of the user might be 0 in which case `sudo` asks for
the password every time (the [gist](https://gist.github.com/cowboy/3118588) won't work).

#### Sudo changes the home directory to "/root" ####

Fom Ubuntu 19.10 on (like in all modern Linuxes) the value of the
`HOME` variable changes to "/root" under `sudo`

#### Sudo exit values and signal handling ####

Only when the failure of `sudo` has been ruled out can the exit value
be assumed to be that of the command:

> Upon successful execution of a command, the exit status from sudo,
> will be the exit status of the program that was executed. If the
> command terminated due to receipt of a signal, sudo, will send
> itself the same signal that terminated the command.

#### Sudo may not implement all options

Like with `which`, there may be a script behind `sudo` that does not
implement all options listed on the sudo man page or lack its own sudo
like Windows/Cygwin.

#### Sudo under Windows/Cygwin

There is no sudo under Cygwin. Based on this [recommendation](https://sourceware.org/legacy-ml/cygwin/2010-04/msg00651.html) from
the Cygwin mailing list we can fake sudo by writing a script-specific
function, or a general `/bin/sudo`:

~~~sh
#!/usr/bin/bash
cygstart --action=runas -- "$@"
~~~

But `cygstart` does not implement important sudo options such as `-b`
(background), `-l` (dry run), `-u USER` and `-n`. 

### Solutions ###

The `secure-sudo.sh` script addresses these issues by creating and
checking equal conditions at the start of the Bash script.

1. Test if called under `sudo` (function `exit_if_elevated`).

1. Test if the user is privileged (function `exit_if_unprivileged`).

1. Run `sudo -v` to ask for the password upfront. Alternatively, use
   `sudo -K` to only reset the timestamp so that the user will only be
   challenged when `sudo` is required.

1. Start the heartbeat sub-process that keeps the sudo session alive:
   - works because the timestamp is global per user
   - shows in the process list (`ps -u`) as "/bin/bash path/to/script"

1. Print a warning or exit if the user password is empty (function
   `test_user_passwd_empty`).

1. Run the actual script code which now can:
   - use `sudo` freely
   - evaluate its exit value as the exit value of a command

1. Kill the heartbeat PID and exit:
   - normal sudo behavior restored
   - session timeout applies again
   - maybe call `sudo -K` to reset the timeout

The script has to be aware that the value of `$HOME` changes into
"/root" when a command is executed under `sudo`.

~~~sh
 $ lsb_release -d
Description:	Ubuntu 22.04.5 LTS
 $ sudo printenv | grep HOME=
/root
 $ sudo printenv | grep SUDO_USER
andreas
 $ sudo -u $USER -H printenv | grep HOME
/home/andreas
~~~

Note that if the heartbeat is not killed the subprocess continues to
run in the background. The reason is that under Linux child processes
are not killed when the parent process exits or is killed. For
example, if another script is started immediately after this one, it
benefits from our sudo heartbeat, at least for a short time, since the
sudo session applies per user.

## Use cases ##

### Testing the solution locally ###

~~~sh
 $ make
~~~

### Creating a test user ###

Let's make a test user with a sudo timeout of 5 minutes:

~~~sh
 $ echo $USER
 andreas
 $ sudo useradd -m -s $(which bash) -G $USER testuser
 $ sudo usermod -a -G sudo testuser
 $ sudo passwd testuser
 $ sudo bash -c "echo 'Defaults timestamp_timeout=3' >/etc/sudoers.d/testuser"
 $ su testuser
 $ groups
testuser sudo andreas
~~~

To set the password you have to run `passwd` to set it initially.

To remove the user again:

~~~sh
 $ sudo deluser testuser
 $ sudo rm -rf /home/testuser
~~~

## Todos ##

- add a TERM handler that kills the heartbeat process
- copy all functions to `libsudo.sh` to be sourced by scripts

## Copyright ##

Copyright 2025 Andreas Spindler <info@andreasspindler.de>.

The author is a freelancer and systems developer with 30+ years of
experience.

As in the old days, this code was hand-written without the help of AI
(exception: Google Translate).

This project is licensed under the terms of the MIT license.

