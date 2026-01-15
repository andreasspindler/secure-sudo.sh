
## Synopsis ##

*secure-sudo.sh* -- Template for a Linux Bash script that uses `sudo`

Bash scripts that use the Linux Sudo system require attention to many
subtle points and pitfalls because `sudo` is geared towards
commandline use.

To run the test script:

~~~sh
 $ make
~~~

The Makefile installs nothing and touches no system settings or files,
but simply run `secure-sudo.sh` as a demonstration.

## Description ##

### Re-authentications ###

When you run a command using `sudo`, Linux starts a new session on a
timer. When it expires the user needs to re-authenticate. This is the
Sudo timestamp.

The first thought of course is to run the whole script as `sudo`. But
we do not want to have UID 0 for everything to not mess with file
permissions or accidentially kill processes.

The second thought is to temporarily extend the timeout for the
duration of the script. It is not advisable to change the Sudo
configuration. Rather assume that the default timestamp is 5-15
minutes.

The only viable option is to run individual statements under `sudo`.
Now if the time between each `sudo` call is too long (typically 5-15
minutes) the script is halted to repeatedly request the password.

The Github [gist](https://gist.github.com/cowboy/3118588) explains the basic solution: to ask for the
password once and to start a `sudo -n true` heartbeat as a subprocess.
This allows individual statements to be executed under `sudo` without
prompting for a password. However, scripts need to take more into
account.

### Running sudo if the user is not a sudoer always fails ###

If the user is not a sudoer the statement fails every time. For
example, under Ubuntu, only the default user created during an Ubuntu
installation will be a member of group "sudo".

Whatever the reason for the failure of `sudo` the statement is not
executed but the rest of the script is.

### Running sudo never asks for the password ###

The script may work in a simple developer VM but not in the field. If
the password of the user is empty (`passwd -d`), the Sudo timeout does
not apply, the user is never asked for the Sudo password and `sudo`
always works.

<!--
There are malicious code snippets in the web that count on empty
passwords only to make hidden use of `sudo`.
  -->

### Running sudo asks for the password every time ###

The Sudo timeout of the user might be 0 in which case `sudo` ask for
the password every time (the [gist](https://gist.github.com/cowboy/3118588) won't work).

Note that the timeout of 60 seconds used in the gist is on the edge:
if the minimum sudo timeout time of 1 minute is configured then the
script likely will ask for a password. In fact, during development of
`secure-sudo.sh` this caused a race condition.

### Running sudo changes the home directory to "/root" ###

Fom Ubuntu 19.10 (like in all modern Linuxes) on the value of the
`HOME` variable changes to "/root" under `sudo`

### Solution ###

We can't run the whole script with `sudo`, we can't fiddle with the
Sudo configuration, and to handle the exit code for each command run
under `sudo` is prone to errors. The `secure-sudo.sh` script solves
these problems by creating and checking identical conditions at the
start.

1. Test if the script is already called under `sudo` which can have
   many unwanted side effects (`exit_if_elevated`).

1. Test if the user can actually run `sudo` (`exit_if_not_sudoer`).

1. Call `sudo -v` upfront to ask for the password and run the Sudo
   session. Alternatively, we may call `sudo -K` to only reset the
   Sudo timestamp. Now the password will only be requested the first
   time `sudo` is used.

1. Start the heartbeat sub-process that keeps the Sudo session alive.
   This works because the timestamp is global per user.
   - Compared to [the gist](https://gist.github.com/cowboy/3118588), the timeout was reduced to 30 seconds
     because under Linux the lowest Sudo timeout can be 1 minute.
   - The sub-process that runs the heartbeart shows in the process
     list as user process "/bin/bash path/to/script".

1. Print a warning or exit if the user password is empty
   (`test_user_passwd_empty`).

1. Now run the actual script which now can use `sudo` without being
   asked for a password ever again.
   
1. Kill the heartbeat when the script exits.
   - If the heartbeat process is not killed it continues to run in the
     background for up to 30 seconds which would be an insecure
     side-effect.
   - Nothing will probably happen if we don't kill the heartbeat, but
     there's no reason to take the risk.
   - If killed sudo behaves normally again when the script is done.


It is up to the developer to make the script aware that the value of
`$HOME` changes into "/root" when a command is executed under `sudo`:

~~~sh
 $ lsb_release -d
Description:	Ubuntu 22.04.5 LTS
 $ sudo printenv | grep HOME
/root
 $ sudo printenv | grep SUDO_USER
andreas
 $ sudo -u $USER -H printenv | grep HOME
/home/andreas
~~~

## Examples ##

### Creating a test user ###

Let's make a test user with a Sudo timeout of 5 minutes:

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

To remove the user:

~~~sh
 $ sudo deluser testuser
 $ sudo rm -rf /home/testuser
~~~

## Copyright ##

Copyright 2025 Andreas Spindler <info@andreasspindler.de>.

I am a freelancer and systems developer with 30+ years of experience.

This project is licensed under the terms of the MIT license.

