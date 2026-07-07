#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
# Example usage: Update dist files for pre2gfmarkdown-pmb:
#   ghpages-checkout-and-reset ~/lib/node_modules/pre2gfmarkdown-pmb/dist/


function ghpdl_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  [ "$#" -ge 1 ] || set -- .
  [ "$1" != -- ] || shift
  local ORIG_CWD="$PWD"
  local VAL=
  for VAL in "$@"; do case "$1" in
    /* | . | ./* | .. | ../* ) ghpdl_one_dir "$VAL" || return $?;;
    * ) echo E: "Unsupported argument: '$VAL'" >&2; return 4;;
  esac; done
}


function ghpdl_one_dir () {
  cd -- "$1" || return $?$(echo E: "Failed to chdir to $1" >&2)
  [ . -ef / ] && return 4$(
    echo E: 'Flinching from operating in root directory!' >&2) || true
  local VAL="$PWD"
  VAL="${VAL/#$HOME'/'/'~/'}"
  [ "$VAL" != "$HOME" ] || VAL='~/'
  ( git status --short -uall . | grep . ) && return 4$(
    echo E: "Flinching: Local directory is not clean: $VAL" >&2) || true
  local CWD_SIMPLIFIED="$VAL"
  echo D: "Now working in: $CWD_SIMPLIFIED"

  local GHP_BRANCH='gh-pages'
  echo D: "Fetch remotes that we (already) know have a $GHP_BRANCH branch:"
  local GHP_REMOTES=()
  readarray -t GHP_REMOTES < <(git branch --remotes |
    sed -nre 's~$~ >>~; s!/!\n!; s!^\s+(\S+)\n!\1\t<< !p' |
    grep -Fe "<< $GHP_BRANCH >>" | cut -sf 1)
  [ -n "$GHP_REMOTES[0]}" ] || return 4$(echo E: 'Found no such remote.' >&2)
  VAL="${#GHP_REMOTES[@]}"
  echo D: "Found $VAL such remote(s): ${GHP_REMOTES[*]}"
  [ "$VAL" == 1 ] || return 4$(
    echo E: 'Cannot decide which remote to use.' >&2)

  VAL="${GHP_REMOTES[0]}"
  git fetch "$VAL" || return $?

  VAL+="/$GHP_BRANCH"
  echo D: "Checkout files from $VAL:"
  git checkout "$VAL" . || return $?$(
    echo E: 'Cannot checkout the files!' >&2)
  git status --short -uno . || return $?$(
    echo E: 'Cannot list updated files!' >&2)
  git reset . || return $?$(
    echo E: 'Cannot reset updated files!' >&2)
  echo D: "Success. @ $CWD_SIMPLIFIED"
  cd -- "$ORIG_PWD" || return $?$(
    echo E: "Cannot chdir back to: $ORIG_PWD" >&2)
}










ghpdl_cli_init "$@"; exit $?
