#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
# ghit = <g>it <hi>story <t>ree view.
#
# Launch my current favorite git history tree viewer
# with my preferred options and my preferred window icon.


function ghit () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DBGLV="${DEBUGLEVEL:-0}"
  local DBG="echo D: $FUNCNAME:"
  local USI='/usr/share/icons'
  local PNG_ICON="
    $USI/elementary-xfce/categories/48/applications-versioncontrol.png
    "
  for PNG_ICON in $PNG_ICON ''; do
    [ -f "$PNG_ICON" ] && break
  done
  local GG_CMD=(
    gitg
    --standalone
    --all
    )
  [ "$DBGLV" -lt 2 ] || $DBG "fork: ${GG_CMD[*]}" >&2
  "${GG_CMD[@]}" &>/dev/null &
  local GG_PID=$!
  [ "$DBGLV" -lt 2 ] || $DBG "gg_pid='$GG_PID'" >&2
  disown "$GG_PID"

  [ -n "$PNG_ICON" ] || return 3$(echo E: $FUNCNAME: "Found no icon!" >&2)
  local WIN_ID=
  local RETRIES=5
  while [ "$RETRIES" -gt 0 ]; do
    sleep 1s
    WIN_ID="$(wmctrl -xl \
      | sed -nre 's!\s+! !g;s~^(0x\S+) \S+ [Gg]itg.[Gg]itg .*~\1~p')"
    [ "$DBGLV" -lt 2 ] || $DBG "win='$WIN_ID'" >&2
    [ -z "$WIN_ID" ] || break
    (( RETRIES -= 1 ))
  done
  for WIN_ID in $WIN_ID; do
    [ "$DBGLV" -lt 2 ] || $DBG "win='$WIN_ID' icon='$PNG_ICON'" >&2
    xseticon-pmb "$WIN_ID" png "$PNG_ICON"
  done
}


ghit "$@"; exit $?
