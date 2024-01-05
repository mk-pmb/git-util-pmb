#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_toplevel () {
  local CD_UP="$(git rev-parse --show-cdup)"
  [ -n "$CD_UP" ] || CD_UP=.

  local REPO_ABS="$(git rev-parse --show-toplevel)"
  [ -n "$REPO_ABS" ] || REPO_ABS='?'

  pretty_ls "$REPO_ABS" | sed -re 's~\t~&'"$CD_UP"' = ~'
  cd -- "$CD_UP" || return $?
  local FN=
  local FILES_HAS=()
  local NO_HAS=()
  for FN in .git{ignore,config,} .{,git}/{HEAD,config,annex}; do
    if [ -e "$FN" ]; then
      # show .git/ even if showing subdirs, b/c it could be a symlink.
      FILES_HAS+=( "$FN" )
    else
      NO_HAS+=( "$FN" )
    fi
  done
  if [ -n "${FILES_HAS[*]}" ]; then
    readarray -t FILES_HAS < <(sort_filenames "${FILES_HAS[@]}")
    pretty_ls "${FILES_HAS[@]}"
  fi
  if [ -n "${NO_HAS[*]}" ]; then
    readarray -t NO_HAS < <(sort_filenames "${NO_HAS[@]}")
    echo $'\e[91;40m'"not in $CD_UP:"$'\e[0m' \
      $'\e[90;40m'"${NO_HAS[*]}"$'\e[0m'
  fi
}


function pretty_ls () {
  local LS_OPTS=(
    --directory
    --file-type
    --format=long
    --human-readable
    --color=always
    --
    )
  ls "${LS_OPTS[@]}" "$@" | sed -re 's~^((\S+\s+){7}\S+)\s+~\1\t~'
}


function sort_filenames () {
  printf '%s\n' "$@" | LANG=C sort --version-sort
}












git_toplevel "$@"; exit $?
