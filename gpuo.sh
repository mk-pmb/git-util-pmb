#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gpuo_main () {
  local FIRST_BRANCH_NAME=
  local CURRENT_BRANCH_NAME=
  local ARG=
  for ARG in "$@"; do
    [ -n "$FIRST_BRANCH_NAME" ] || case "$ARG" in
      [0-9A-Za-z]* ) FIRST_BRANCH_NAME="$ARG";;
    esac
  done
  local PRE=()
  if [ -z "$FIRST_BRANCH_NAME" ]; then
    CURRENT_BRANCH_NAME="$(git branch | sed -nre 's~^\* ~~p')"
    [ -n "$CURRENT_BRANCH_NAME" ] || return 3$(
      echo "E: $FUNCNAME: failed to guess CURRENT_BRANCH_NAME!" >&2)
    PRE=( "$CURRENT_BRANCH_NAME" )
  fi
  git push -u origin "${PRE[@]}" "$@" || return $?
}










gpuo_main "$@"; exit $?
