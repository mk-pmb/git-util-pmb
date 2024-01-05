#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function prettify_repo_config () {
  local DBGLV="${DEBUGLEVEL:-0}"
  local GIT_DIR="$(git rev-parse --git-dir)"
  case "$GIT_DIR" in
    . | ./* ) GIT_DIR="$PWD${GIT_DIR#\.}";;
    ../* ) GIT_DIR="$PWD/$GIT_DIR";;
  esac
  [ "$DBGLV" -ge 4 ] && echo "I: detected git dir as '$GIT_DIR'"
  local GIT_CFG="$GIT_DIR/config"
  [ "$DBGLV" -ge 2 ] && echo "I: detected config file as '$GIT_CFG'"
  if [ ! -f "$GIT_CFG" ] || [ -L "$GIT_CFG" ]; then
    echo "E: flinching: $GIT_CFG is not a regular file." >&2
    ls -l "$GIT_CFG"
    return 3
  fi

  local CFG_TMP="$GIT_DIR/prettier-config"
  sed -nre '
    b after_non_blank
    : blank
      /\S/b non_blank
      p;n
    b blank
    : non_blank
      p;n
      : after_non_blank
      /\S/!b blank
      s~^\[~\n&~
      1{/, tab-width: /!s!^!# -*- coding: utf-8, tab-width: 4 -*-\n!}
    b non_blank
    ' -- "$GIT_CFG" >"$CFG_TMP" || return $?
  diff -- "$GIT_CFG" "$CFG_TMP" >/dev/null
  local DIFF_RV="$?"
  if [ "$DIFF_RV" == 0 ]; then
    [ "$DBGLV" -ge 1 ] && echo "I: $FUNCNAME: no changes"
  elif [ "$DIFF_RV" == 1 ]; then
    [ "$DBGLV" -ge 1 ] && echo "I: $FUNCNAME: diff found changes"
    cp --no-target-directory "$GIT_CFG"{,.bak} || return $?
    cat "$CFG_TMP" >"$GIT_CFG" || return $?
  else
    echo "W: $FUNCNAME: diff failed, rv=$DIFF_RV" >&2
    return "$DIFF_RV"
  fi
  [ ! -f "$GIT_CFG".bak ] || rm -- "$GIT_CFG".bak || return $?
  rm -- "$CFG_TMP" || return $?
  return 0
}








[ "$1" == --lib ] && return 0; prettify_repo_config "$@"; exit $?
