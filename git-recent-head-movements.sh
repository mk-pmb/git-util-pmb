#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function rhm_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly

  exec 11>&1 # Backup stdout
  exec > >(exec sort --general-numeric-sort)
  rhm_read_all_reflogs || return $?

  # ps ho user,pid,pgid,args -$$ >&2
  exec 1>&11 # Restore stdout. Implicitly closes pipes to our output
    # filter children so they can quit cleanly.
  wait
}


function rhm_read_all_reflogs () {
  local SINCE="${GIT_SINCE:--1}"
  [ "$SINCE" -ge 1 ] || SINCE="$(printf '%(%s)T' -1) - (14 * 24 * 60 * 60)"
  let SINCE="$SINCE" || true

  local REFLOGS_DIR="$(git rev-parse --git-path logs/refs)"
  [ -d "$REFLOGS_DIR" ] || return 4$(echo E: 'Cannot find reflogs dir!' >&2)

  local LIST=()
  readarray -t LIST < <(cd -- "$REFLOGS_DIR" &&
    find [a-z]*/ -mount -maxdepth 8 -type f)
  [ -n "${LIST[0]}" ] || return 4$(echo E: 'Cannot find any reflog!' >&2)

  local REF_NAME= LN= OLD_HASH= NEW_HASH= AUTHOR= UTS= TIMEZONE= DESCR=
  for REF_NAME in "${LIST[@]}"; do
    LIST=()
    exec <"$REFLOGS_DIR/$REF_NAME" || return $?$(
      echo E: "Cannot read from reflog '$REF_NAME'" >&2)
    while IFS= read -r LN; do
      DESCR="${LN#*$'\t'}"; LN="${LN%%$'\t'*}"
      TIMEZONE="${LN##* }"; LN="${LN% *}"
      UTS="${LN##* }"; LN="${LN% *}"
      OLD_HASH="${LN%% *}"; LN="${LN#* }"
      NEW_HASH="${LN%% *}"; LN="${LN#* }"
      AUTHOR="$LN"; LN=
      [ "$UTS" -ge "$SINCE" ] || continue
      LC_TIME=C printf -- '%(%F (%a) %T)T' "$UTS"
      echo " ${OLD_HASH:0:7}..${NEW_HASH:0:7} $REF_NAME"$'\t'"$DESCR"
    done
  done
}










rhm_cli_init "$@"; exit $?
