#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gup_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(dirname -- "$(readlink -m -- "$BASH_SOURCE")")"

  local ARG="$1"; shift
  case "$ARG" in

    '' ) echo E: 'No command name given' >&2; return 4;;

    --resolve )
      [ "$#" -ge 1 ] || set -- .
      while [ "$#" -ge 1 ]; do
        readlink -m -- "$SELFPATH/$1" || return $?
        shift
      done
      return 0;;

  esac

  for ARG in "$ARG" \
    "$ARG".sh \
    "$ARG".sed \
    "$ARG"
  do
    ARG="$SELFPATH/$ARG"
    [ -x "$ARG" ] && break
  done
  exec "$ARG" "$@" || return $?
}










gup_cli_init "$@"; exit $?
