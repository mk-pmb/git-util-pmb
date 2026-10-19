#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gaxfsz_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local TASK='extract'
  local VAL=
  while [ "$#" -ge 1 ]; do
    VAL="$1"; shift
    case "$VAL" in
      --sum )
        VAL="$("$FUNCNAME" "$@")"
        let VAL=-1 VAL="${VAL//$'\n'/+}+0" || return $?
        echo "$VAL"; return $?;;
      --sum=[A-Za-z]* ) # e.g. --sum=MiB
        units --terse "$($FUNCNAME --sum "$@"
          ) bytes" "${VAL#*=}"; return $?;;
      * ) echo E: "Unsupported CLI argument: $1"; return 4;;
    esac
  done
  gaxfsz_"$TASK" "$@"; return $?
}


function gaxfsz_extract () {
  tty --silent && exec < <(git show)
  # NB: The sort has to happen on the full hash!
  #   If two files are the same size, they are still different files!
  grep -oPe '\bSHA\w+-s\d+--\w+(\.\w+|)$' | LANG=C sort -Vu |
    grep -oPe '-s\d+(?=--)' | cut -b 3-
}










gaxfsz_cli_init "$@"; exit $?
