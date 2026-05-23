#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ttcommit_cli_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local GIT_ACTION='commit'
  case "$1" in
    --merge | \
    --action=* ) GIT_ACTION="${1#--}"; GIT_ACTION="${GIT_ACTION#*=}"; shift;;
  esac

  local NOW= VAL= UTS=0

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
    [ "${DATE_WORDS_LC/:$VAL:/}" == "$DATE_WORDS_LC" ] ||
      { NOW+=" $1"; shift; continue; }
    case "${VAL//[1-9]/0}" in
      '' ) shift;;
      0000-0000-0000 )
        NOW+=" ${VAL:0:7}-${VAL:7:2} ${VAL:10:2}:${VAL:12:2}:"
        shift;;
      [+@-]0* ) NOW+=" $1"; shift;;
      00:00: ) NOW+=" $1$(printf -- '%(%S)T' -1)"; shift;;
      0* ) NOW+=" $1"; shift;;
      * ) break;;
    esac
    case "$NOW" in
      *[0-9]d ) NOW+='ay';;
      *[0-9]h ) NOW+='our';;
      *[0-9]m ) NOW+='in';;
      *[0-9]s ) NOW+='ec';;
    esac
  done

  NOW="${NOW,,}"
  NOW="${NOW/,/}"
  NOW="${NOW//   / }"
  NOW="${NOW//  / }"
  VAL="${WEEKDAY_NAMES_SHORT//:/ }"
  for VAL in ${VAL,,}; do NOW="${NOW// $VAL / }"; done
  NOW="${NOW# }"
  case "${NOW//[1-9]/0}" in
    [a-z][a-z][a-z]' 0 '* ) NOW="${NOW/ / 0}";; # ensure day has 2 digits
  esac
  case "${NOW//[1-9]/0}" in
    [a-z][a-z][a-z]' 00 00:00 '* )
      echo E: 'Seconds required for this time format!' >&2; return 4;;
  esac
  case "${NOW//[1-9]/0}" in
    *[^0]00:00: ) NOW+="$(printf '%(%S)T' -1)";;
    [a-z][a-z][a-z]' 00 00:00:00 0000 '[+-]0000 )
      # e.g. __ "jan 01 00:00:00 1970 +0000"
      #      ^-- Potential weekday and comma have already been cut off.
      # Ubuntu focal's date command seems to understand month name
      # abbreviations only if they are between day and year;
      NOW="${NOW:4:2} ${NOW:0:3} ${NOW:16:4} ${NOW:7:8} ${NOW:21}"
      ;; # dd         mmm        yyyy        HH:MM:SS   zzzzz
  esac
  UTS=
  case "$NOW" in
    [0-9]* | [+@-][0-9]* ) UTS="$(date +%s -d "$NOW")";;
    * ) echo E: "Flinching: Unsupported date format: '$NOW'" >&2; return 4;;
  esac

  [ -n "$UTS" ] || return 4$(echo E: >&2 \
    "Failed to parse date/time format: '$NOW'")
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
