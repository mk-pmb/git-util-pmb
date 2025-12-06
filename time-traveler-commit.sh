#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ttcommit_cli_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local GIT_ACTION='commit'
  case "$1" in
    --merge | \
    --action=* ) GIT_ACTION="${1#--}"; GIT_ACTION="${GIT_ACTION#*=}"; shift;;
  esac

  local NOW="$1"; shift
  local UTS=0 VAL=

  local WEEKDAY_NAMES_SHORT=":$(
    TZ=UTC           printf '%(%a)T:' 7{0..6}01337
    TZ=UTC LC_TIME=C printf '%(%a)T:' 7{0..6}01337
    )"
  local MONTH_NAMES_SHORT=":$(
    TZ=UTC           printf '%(%b)T:' {1..300..27}00000
    TZ=UTC LC_TIME=C printf '%(%b)T:' {1..300..27}00000
    )"

  # Support unquoted dates for user convenience:
  local DATE_WORDS_LC="${WEEKDAY_NAMES_SHORT,,}${MONTH_NAMES_SHORT,,}"
  while [ "$#" -ge 1 ]; do
    VAL="$1"
    VAL="${VAL%,}"
    VAL="${VAL,,}"
    [ "${DATE_WORDS_LC/:$VAL:/}" == "$DATE_WORDS_LC" ] || VAL=1
    VAL="${VAL#-}"
    VAL="${VAL#+}"
    case "$VAL" in
      [0-9]* ) NOW+=" $1"; shift;;
      * ) break;;
    esac
  done

  VAL="${NOW,,}"
  VAL="${VAL/,/}"
  VAL="${VAL//  / }"
  case "$VAL" in
    [a-z][a-z][a-z]' '[0-9]* | [+@-][0-9]* ) UTS="$(date +%s -d "$NOW")";;
    * ) echo E: "Flinching: Unsupported date format: '$NOW'" >&2; return 4;;
  esac

  [ "$UTS" -ge 1023456789 ] || return 4$(echo E: >&2 \
    'Flinching: Not time-travelling to long before git itself was published!')
    # Initial commit of the git repository for git itself:
    # commit e83c5163316f89bfbde7d9ab23ca2e25604af290 (first-commit-ever)
    # From: Linus Torvalds <torvalds@*****.org>
    # Date: Thu, 7 Apr 2005 15:13:13 -0700        # UTS=1112911993

  NOW="$(date -Rd "@$UTS")"
  env GIT_{AUTHOR,COMMITTER}_DATE="$NOW" git "$GIT_ACTION" "$@" || return $?
}










ttcommit_cli_main "$@"; exit $?
