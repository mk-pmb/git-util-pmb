#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_zwischensave () {
  export LANG{,UAGE}=C
  local CD_UP="$(git rev-parse --show-cdup)"
  [ -n "$CD_UP" ] || CD_UP=.
  local COMT_MSG="Zwischensave"
  local BRN_NAME="$COMT_MSG"
  BRN_NAME="${BRN_NAME,,}"
  BRN_NAME="${BRN_NAME// /-}"
  local BRN_DATE=; printf -v BRN_DATE -- '%(%Y-%m%d-%H%M %F %H:%M)T' -1
  COMT_MSG+=" ${BRN_DATE#* }"
  BRN_NAME+="-${BRN_DATE%% *}"
  echo -n 'branching: '
  git branch "$BRN_NAME"
  local RETVAL=
  echo -n 'checkout and commit: '
  ( git checkout "$BRN_NAME" || git checkout --orphan "$BRN_NAME" ) \
    && git add -A "$CD_UP" \
    && git commit -m "$COMT_MSG" "$@"
  RETVAL=$?
  [ "$RETVAL" == 0 ] || echo "rv=$RETVAL" >&2
  git status
  return "$RETVAL"
}





git_zwischensave "$@"; exit $?
