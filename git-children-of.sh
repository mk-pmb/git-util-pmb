#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_children_of () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local PARENT="$(git rev-parse "${1:-HEAD}")"
  local SIBL=( $(git rev-list --all --children | sed -nre "s:^$PARENT ::p" \
    | tr ' ' '\n' | LANG=C sort --unique | sed -re '$s~^~<last>~' ) )

  local DISPLAY_COMMIT=(
    git log
    --oneline
    --decorate=short
    --color=always
    -n 1
    )

  exec > >(tr -d '\r')
  "${DISPLAY_COMMIT[@]}" "$PARENT"
  local ITEM=
  for ITEM in "${SIBL[@]}"; do
    case "$ITEM" in
      '' ) continue;;
      '<last>'* ) echo -n " '"; ITEM="${ITEM#*>}";;
      * ) echo -n ' |';;
    esac
    echo -n '— '
    "${DISPLAY_COMMIT[@]}" "$ITEM"
  done
}










git_children_of "$@"; exit $?
