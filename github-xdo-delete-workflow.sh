#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function xdo () {
  local HOW_MANY="${1:-1}"; shift
  local DELAY="${1:-5}"; shift

  local COOL=(
    , ctd 'Wait for browser to be ready (and focussed)' "$DELAY" \
    , grep_curwin_title -qPie '^Workflow runs · '
    , click 1
    , sleep 1s
    , key Tab Tab space
    , sleep 2s
    , key Tab space
    )

  while [ "$HOW_MANY" -ge 1 ]; do
    xdocool "${COOL[@]}" || return $?
    (( HOW_MANY -= 1 ))
  done
}


xdo "$@"; exit $?
