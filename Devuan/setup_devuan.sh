#!/bin/sh
#  shellcheck disable=SC2154

#
#  Part of https://github.com/emkey1/AOK-Filesystem-Tools
#
#  License: MIT
#
#  setup_devuan.sh
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  This modifies a Devuan Linux FS with the AOK changes
#

install_sshd() {
    #
    #  Install sshd, then remove the service, in order to not leave it running
    #  unless requested to: with enable_sshd / disable_sshd
    #
    msg_1 "Installing openssh-server"

    msg_2 "Remove previous ssh host keys if present in FS to ensure not using known keys"
    rm -f /etc/ssh/ssh_host*key*

    openrc_might_trigger_errors

    msg_3 "Install sshd and sftp-server (scp server part)"
    apt install -y openssh-server openssh-sftp-server

    msg_3 "Disable sshd for now, enable it with: enable_sshd"
    rc-update del ssh default
}

prepare_env_etc() {
    msg_2 "prepare_env_etc()"

    msg_3 "Devuan AOK inittab"
    cp -a "$aok_content"/Devuan/etc/inittab /etc

    msg_3 "hosts file helping apt tools"
    cp -a "$aok_content"/Devuan/etc/hosts /etc

    #
    #  Most of the Debian services, mounting fs, setting up networking etc
    #  serve no purpose in iSH, since all this is either handled by iOS
    #  or done by the app before bootup
    #
    # # skipping openrc
    # msg_2 "Disabling previous openrc runlevel tasks"
    # rm /etc/runlevels/*/* -f

    msg_3 "Adding env versions & AOK Logo to /etc/update-motd.d"
    mkdir -p /etc/update-motd.d
    cp -a "$aok_content"/Devuan/etc/update-motd.d/* /etc/update-motd.d

    msg_3 "prepare_env_etc() done"
}

setup_login() {
    #
    #  What login method will be used is setup during FIRST_BOOT,
    #  at this point we just ensure everything is available and initial boot
    #  will use the default loging that should work on all platforms.
    #
    # SKIP_LOGIN
    msg_2 "Install Debian AOK login methods"
    cp "$aok_content"/Debian/bin/login.loop /bin
    chmod +x /bin/login.loop
    cp "$aok_content"/Debian/bin/login.once /bin
    chmod +x /bin/login.once

    # TODO: enabled in Debian, verify it can be ignored here
    # cp -a "$aok_content"/Debian/etc/pam.d/common-auth /etc/pam.d

    cp -a /bin/login /bin/login.original
}

#===============================================================
#
#   Main
#
#===============================================================

#
#  Since this is run as /etc/profile during deploy, and this wait is
#  needed for /etc/profile (see Alpine/etc/profile for details)
#  we also put it here
#
sleep 2

#  Ensure important devices are present
echo "-> Running fix_dev <-"
/opt/AOK/common_AOK/usr_local_sbin/fix_dev

if [ ! -d "/opt/AOK" ]; then
    echo "ERROR: This is not an AOK File System!"
    echo
    exit 1
fi

tsd_start="$(date +%s)"

#  shellcheck disable=SC1091
. /opt/AOK/tools/utils.sh

if [ "$build_env" -eq 0 ]; then
    echo
    echo "##  WARNING! this setup only works reliably on iOS/iPadOS and Linux(x86)"
    echo "##           You have been warned"
    echo
fi

msg_script_title "setup_devuan.sh  Devuan specific AOK env"

start_setup Devuan "$(cat /etc/debian_version)"

if test -f /AOK; then
    msg_1 "Removing obsoleted /AOK new location is /opt/AOK"
    rm -rf /AOK
fi

prepare_env_etc

#
#  This must run before any task doing apt actions
#
msg_2 "Installing sources.list"
cp "$aok_content"/Devuan/etc/apt_sources.list /etc/apt/sources.list

msg_1 "apt update"
apt update -y

#
#  Doing some user interactions as early as possible, unless this is
#  pre-built, then this happens on first boot via setup_alpine_final_tasks.sh
#
if ! bldstat_get "$status_prebuilt_fs"; then
    user_interactions
fi

if [ "$QUICK_DEPLOY" -eq 0 ]; then
    msg_1 "apt upgrade"
    apt upgrade -y

    if [ -n "$DEB_PKGS" ]; then
        msg_1 "Add core Debian packages"
        echo "$DEB_PKGS"
        bash -c "DEBIAN_FRONTEND=noninteractive apt install -y $DEB_PKGS"
    fi
    #
    # Devuan draws in some 91 packages if openssh-server is installed
    # seems a bit much, also I havent figured out how to disable sshd
    # initially, so not active ATM
    #
    # install_sshd
else
    msg_1 "QUICK_DEPLOY - skipping apt upgrade and DEB_PKGS"
fi

# msg_2 "Add boot init.d items suitable for iSH"
# rc-update add urandom boot

# msg_2 "Add shutdown init.d items suitable for iSH"
# rc-update add sendsigs off
# rc-update add umountroot off
# rc-update add urandom off

# # skipping openrc
# if [ "$QUICK_DEPLOY" -eq 0 ]; then
#     msg_2 "Disable some auto-enabled services that wont make sense in iSH"
#     openrc_might_trigger_errors

#     rc-update del dbus default
#     rc-update del elogind default
#     rc-update del rsync default
#     rc-update del sudo default
# else
#     msg_2 "QUICK_DEPLOY - did not remove default services"
# fi

#
#  Common deploy, used both for Alpine & Debian
#
if ! "$setup_common_aok"; then
    error_msg "$setup_common_aok reported error"
fi

#
#  Overriding common runbg with Debian specific, work in progress...
#
# msg_2 "Adding runbg service"
# cp -a "$aok_content"/Devuan/etc/init.d/runbg /etc/init.d
# ln -sf /etc/init.d/runbg /etc/rc2.d/S04runbg

setup_login

if bldstat_get "$status_prebuilt_fs"; then
    select_profile "$setup_devuan_final"
else
    "$setup_devuan_final"
    not_prebuilt=1
fi

msg_1 "Setup complete!"

duration="$(($(date +%s) - tsd_start))"
display_time_elapsed "$duration" "Setup Devuan"

if [ "$not_prebuilt" = 1 ]; then
    msg_1 "Please reboot/restart this app now!"
    echo "/etc/inittab was changed during the install."
    echo "In order for this new version to be used, a restart is needed."
    echo
fi
