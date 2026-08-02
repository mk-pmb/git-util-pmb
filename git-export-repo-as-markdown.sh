#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function repomd_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local VAL="$(git rev-parse --show-cdup)"
  [ -z "$VAL" ] || cd -- "$VAL" || return $?
  local GIT_LS_FILES=() MDTB_OPT=()
  local ARG= KEY= VAL=
  while [ "$#" -ge 1 ]; do
    ARG="$1"; shift
    case "$ARG" in
      -* ) MDTB_OPT+=( "$ARG" );;
      * ) GIT_LS_FILES=( "$ARG" );;
    esac
  done
  exec < <(git ls-files --full-name -- "${GIT_LS_FILES[@]}" |
    sort --version-sort)
  while IFS= read -r VAL; do
    [ -f "$VAL" ] || continue
    set -- "$@" "$VAL"
    KEY="$(git status --short -uall -- "$VAL")"
    # ^-- Column 1 is how the staging area differs from the HEAD commit.
    #     Column 2 is how the worktree differs from the staging area.
    #     Column 3 is always a space character.
    KEY="${KEY:0:2}"
  done
  [ -n "$1" ] || return 4$(echo E: 'Found no files to export!' >&2)
  local LEAK="$(git status --short -uall -- "$@")"
  LEAK="${LEAK//$'\n'/, }"
  [ -z "$LEAK" ] || echo W: "Exporting uncommitted changes: $LEAK" >&2
  echo -ne '\xEF\xBB\xBF'
  ghciu-fmt-markdown-textblock bundle_files "${MDTB_OPT[@]}" "$@" || return $?
  [ -z "$LEAK" ] || echo W: "Exported uncommitted changes: $LEAK" >&2
}











repomd_cli_init "$@"; exit $?
