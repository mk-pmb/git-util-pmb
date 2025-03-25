#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ggrep_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  local SELFNAME="$(basename -- "$SELFFILE" .sh)"

  if tty --silent <&1; then
    clear
    exec smart-less-pmb +Gg -e "$SELFFILE" "$@"
    return $?$(echo E: ggrep: "Failed to re-exec self, rv=$?." >&2)
  fi
  local FOUND="$(git grep --color=always -nF "$@" |

    # Protect our variable memory from matches in minified JavaScript files:
    cut --bytes=1-800 |

    LANG=C sed -rf "$SELFPATH"/ggrep.preparse.sed)"

  local MAXLEN_FILE=0 MAXLEN_LNUM=0 MATCH_CNT=0
  ggrep_with_each_result ggrep_learn_column_lengths || return $?
  [ "$MATCH_CNT" != 0 ] || return 0
  local PREV_FILE= MATCH_LEN="${#MATCH_CNT}" MATCH_NUM=0
  ggrep_with_each_result ggrep_print_result_line || return $?
  echo
}


function ggrep_with_each_result () {
  local FOUND="$FOUND" FILE= LNUM= TEXT= SEP=$'\t' VAL=
  while [ -n "$FOUND" ]; do
    TEXT="${FOUND%%$'\n'*}"
    [ "${#TEXT}" != "${#FOUND}" ] || FOUND=
    FOUND="${FOUND#*$'\n'}"
    [ -n "$TEXT" ] || continue

    # check if we're missing a color reset, which may have been cut off by
    # due to our defense against overly long input lines:
    VAL="${TEXT//[^$'\f\r']/}"
    VAL="${VAL//$'\f\r'/}"
    [ -z "$VAL" ] || TEXT+=$'\r'
    VAL=

    FILE="${TEXT%%$SEP*}"
    [ "${#FILE}" != "${#TEXT}" ] || TEXT=
    TEXT="${TEXT#*$SEP}"

    LNUM="${TEXT%%$SEP*}"
    [ "${#LNUM}" != "${#TEXT}" ] || TEXT=
    TEXT="${TEXT#*$SEP}"

    "$@" || return $?
  done
}


function ggrep_learn_column_lengths () {
  [ "$MAXLEN_FILE" -ge "${#FILE}" ] || MAXLEN_FILE="${#FILE}"
  [ "$MAXLEN_LNUM" -ge "${#LNUM}" ] || MAXLEN_LNUM="${#LNUM}"
  (( MATCH_CNT += 1 ))
}


function ggrep_print_result_line () {
  [ -z "$PREV_FILE" ] || [ "$FILE" == "$PREV_FILE" ] || echo
  (( MATCH_NUM += 1 ))
  printf -- '% *u ' "$MATCH_LEN" "$MATCH_NUM"
  if [ "$FILE" == "$PREV_FILE" ]; then
    printf -- '%- *s ^ ' "$MAXLEN_FILE" ''
  else
    printf -- '%- *s @ ' "$MAXLEN_FILE" "$FILE"
    PREV_FILE="$FILE"
  fi
  printf -- '% *u ' "$MAXLEN_LNUM" "$LNUM"
  if [[ "$TEXT" == *$'\f'* ]]; then
    echo -n :
  else
    echo -n -
  fi
  TEXT="${TEXT//$'\f'/$'\x1B[7m'}"
  TEXT="${TEXT//$'\r'/$'\x1B[0m'}"
  echo "$TEXT"
}










ggrep_cli_init "$@"; exit $?
