#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_mark_whatchanged () {
  local L=()
  readarray -t L < <(git branch | sed -nre 's~^  (mwc-[0-9a-f]+)$~\1~p')
  if [ "${#L[@]}" -ge 1 ]; then
    echo "D: Gonna clean up ${#L[@]} branches: ${L[*]}"
    git branch --quiet --delete "${L[@]}" || return $?
  fi
  if [ -z "$*" ]; then
    echo 'D: No reference given.'
    return 0
  fi

  L=()
  readarray -t L < <(
    git whatchanged --decorate --oneline "$@" | grep -Pe '^\w' | tac)
  local N="${#L[@]}"
  if [ "$N" == 0 ]; then
    echo "E: Found no matching commits."
    return 3
  fi
  echo "D: Found $N commits to be marked."
  local M="${MWC_MAX_COMMITS:-50}"
  [ "$N" -le "$M" ] || return 3$(echo "E: That's too many commits." \
    "Current limit: $M. Set MWC_MAX_COMMITS to change it." >&2)
  local C= I=0
  for C in "${L[@]}"; do
    (( I += 1 ))
    printf '% 4d  ' "$I"
    echo "$C"
    git branch --force {mwc-,}"${C%% *}" || return $?
  done
}


git_mark_whatchanged "$@"; exit $?
