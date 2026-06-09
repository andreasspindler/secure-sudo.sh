
## Usage ##

*secure-sudo.sh* is a template for Bash scripts using `sudo`.

The template was extensively tested in real-world scripts.

To run the script (prints "hello world"):

~~~sh
 $ make
~~~

To further test add a test user with a sudo timeout of 5 minutes:

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

To set the the password initially use `passwd`.

To remove the user again:

~~~sh
 $ sudo deluser testuser
 $ sudo rm -rf /home/testuser
~~~

## Details ##

> sudo, allows a permitted user to execute a command as the superuser or another
> user, as specified by the security policy. The invoking user's real (not
> effective) user-ID is used to determine the user name with which to query the
> security policy.

`sudo` is geared towards commandline use. `sudo` can be used from within
scripts, but there are a few things to keep in mind. The whole purpose of the
`secure-sudo.sh` template is to address these.

### Sudo repeatedly asks for a password ###

Every call to `sudo` starts a new session on a timer (usually 5-15 minutes).
This is the sudo timestamp. When it expires the user needs to reauthenticate to
Linux.

If the time between each `sudo` call is too long the script is halted to
repeatedly request the password. Based on [this Github gist](https://gist.github.com/cowboy/3118588) the solution is
to:
- ask for the password once
- start a `sudo -n true` heartbeat
- update the timer frequently

Under Linux the lowest `sudo` timeout can be 1 minute. During testing of
`secure-sudo.sh` such a low value triggered race conditions. A value of 30
seconds resolved the issue.

### Sudo may never ask for a password ###

If the user has a blank password, sudo will never ask for the password (timeout
does not apply). In the past, malicious code snippets from the web may counted
on empty passwords to make hidden use of sudo to gain control.

### Sudo may ask for the password every time ###

If the sudo timeout is 0 in which case it asks for the password every time.

### The script was already started under sudo ###

Whether or not sudo is needed internally, it is generally not a good idea to
start a script under sudo. UID 0 for everything can mess with file permissions,
accidentially kill processes or change passwords.

### Sudo may not execute the command ###

`sudo` will not execute a command from the script if the user is not privileged
or enters the wrong password.

To test if the user is privileged:

> If the -l option was specified without a command, sudo, will exit with a value
> of 0 if the user is allowed to run sudo, and they authenticated successfully
> (as required by the security policy).

To test if the user is allowed to run a command:

> If a command is specified with the -l option, the exit value will only be 0 if
> the command is permitted by the security policy, otherwise it will be 1.

### Sudo changes the home directory to "/root" ###

Fom Ubuntu 19.10 on (like in all modern Linuxes) the value of the `HOME`
variable changes to "/root" under `sudo`:

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

The script has to be aware that the value of `$HOME` changes into "/root" when a
command is executed under `sudo`.

### Sudo exit values and signal handling ###

Only when the user is privileged enough and failure of `sudo` has been ruled
out, the sudo exit value is that of the command:

> Upon successful execution of a command, the exit status from sudo, will be the
> exit status of the program that was executed. If the command terminated due to
> receipt of a signal, sudo, will send itself the same signal that terminated
> the command.

### Sudo may not have implemented all options ###

Like with `which`, there may be a script behind `sudo` that does not implement
all options listed on the sudo man page. Windows/Cygwin even lack its own sudo
command entirely.

### Sudo under Windows/Cygwin ###

There is no sudo under Cygwin. Based on this [recommendation](https://sourceware.org/legacy-ml/cygwin/2010-04/msg00651.html) from the Cygwin
mailing list we can fake sudo by writing a script-specific function, or a
general `/bin/sudo`:

~~~sh
#!/usr/bin/bash
cygstart --action=runas -- "$@"
~~~

Of course `cygstart` does not implement important sudo options such as `-b`
(background), `-l` (dry run), `-u USER` and `-n`.

## Implementation ##

The `secure-sudo.sh` script addresses these issues by creating and checking
equal conditions at the start of the Bash script.

1. Test if called under `sudo` (function `exit_if_elevated`).

1. Test if the user is privileged (function `exit_if_unprivileged`).

1. Run `sudo -v` to ask for the password upfront. Alternatively, use `sudo -K`
   to only reset the timestamp so that the user will only be challenged when
   `sudo` is required.

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

Note that if the heartbeat is not killed the subprocess continues to run in the
background. The reason is that under Linux child processes are not killed when
the parent process exits or is killed. For example, if another script is started
immediately after this one, it benefits from the sudo heartbeat, at least for a
short time, since the sudo session applies per user.

## Todos ##

- add a TERM handler that kills the heartbeat process

## Copyright ##

[secure-sudo.sh](http://www.github.com/andreasspindler/secure-sudo.sh)

Copyright 2025 Andreas Spindler <info@andreasspindler.de>.

This repo was created without AI assistance.

This project is licensed under the terms of the MIT license.

