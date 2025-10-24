#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function grds_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  grds_core | LANG=C sort
}


function grds_core () {
  exec </dev/null
  local VAL="$(git fsck --no-reflog | sed -nre 's~^dangling commit ~~p')"
  local C_HASH= C_UTS= C_WKD= C_DATE= C_SUBJ=
  for C_HASH in $VAL; do
    VAL="$(git log -n 1 --pretty=$'%at\t%aD\t%ai\t%s' "$C_HASH")"
    [ -n "$VAL" ] || continue
    C_UTS="${VAL%%$'\t'*}"; VAL="${VAL#*$'\t'}"
    C_WKD="${VAL%%, *}"; VAL="${VAL#*$'\t'}"
    C_DATE="${VAL%%$'\t'*}"; VAL="${VAL#*$'\t'}"
    C_SUBJ="${VAL%%$'\t'*}"; VAL="${VAL#*$'\t'}"
    case "$C_SUBJ" in
      'WIP on '* ) ;;
      * ) continue;;
    esac
    C_DATE="${C_DATE% [+-][0-9][0-9][0-9][0-9]}"
    C_DATE="${C_DATE/ / $C_WKD }"
    printf -- '%s\t' "$C_DATE" "${C_HASH:0:7}"
    echo "$C_SUBJ"
  done
}










grds_cli_init "$@"; exit $?
