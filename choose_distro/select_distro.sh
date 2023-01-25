#!/bin/sh
# shellcheck disable=SC2154
#
#  Part of https://github.com/emkey1/AOK-Filesystem-Tools
#
#  License: MIT
#
#  Copyright (c) 2023: Jacob.Lundqvist@gmail.com
#
#  Setup Distro choice
#

# shellcheck disable=SC1091
. /opt/AOK/tools/utils.sh

tcd_start="$(date +%s)"

# dialog_app="dialog --erase-on-exit"
dialog_app="whiptail"

if ! bldstat_get "$status_select_distro_prepared"; then
    msg_1 "Need to run $setup_select_distro_prepare"
    "$setup_select_distro_prepare"
else
    msg_1 "$setup_select_distro_prepare alredy done"
fi
bldstat_clear "$status_select_distro_prepared"

#
#  Ensure TERM is sensible, tmux and ch-rooting tends to leave it in a state
#  not appreciated by whiptail
#
TERM=xterm

#
#  On my iPad the dialog is displayed with what seems to be screen width 80
#  lets see if this helps...
#
clear

#
#  whiptail is somewhat sensitive about what TERM is being used...
#
if [ "$dialog_app" = "whiptail" ] && [ "${TERM#*screen}" != "$TERM" ]; then
    echo
    echo "ERROR: whiptail will not work if TERM is 'screen' or a variation thereof"
    echo "Simple fix:"
    echo
    echo "TERM=xterm-256color"
    echo "/etc/profile"
    echo
    exit 1
fi

text="Alpine is the regular AOK FS,
fully stable. This will install
Alpine $ALPINE_VERSION

Debian is experimental, not yet stable,
this is version 10 (Buster).
It was end of lifed 2022-07-18
and is thus now unmaintained.
But should be fine for testing Debian
with the AOK FS extensions under iSH-AOK."

$dialog_app \
    --topleft \
    --title "Select AOK Distro" \
    --yes-button "Alpine" \
    --no-button "Debian" \
    --yesno "$text" 0 0

exitstatus=$?

if [ "$exitstatus" -eq 0 ]; then
    # Alpine selected
    echo
    msg_1 "running $setup_alpine_scr"
    "$setup_alpine_scr"
else
    test -f "$additional_tasks_script" && notification_additional_tasks
    "$aok_content"/choose_distro/install_debian.sh
fi

bldstat_clear "$status_being_built"

duration="$(($(date +%s) - tcd_start))"
display_time_elapsed "$duration" "Choose Distro"

#
#  Need to exit running this profile, otherwise control will spill over
#  into the replaced profile if it has more lines than this one.
#  In order for this exit not to terminate the session instantly
#  a shell is started, in order to be able to inspect the deploy
#  outcome.
#
/bin/sh
exit
