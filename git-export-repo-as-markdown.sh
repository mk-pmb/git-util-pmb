#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function repomd_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local VAL="$(git rev-parse --show-cdup)"
  [ -z "$VAL" ] || cd -- "$VAL" || return $?
  local GIT_LS_FILES=() MDTB_OPT=()
  local ARG= KEY= VAL= FLAGS=','
  local APPEND_EXTRA_FILES=$'\n'
  while [ "$#" -ge 1 ]; do
    ARG="$1"; shift
    case "$ARG" in
      '' ) ;;

      +* ) APPEND_EXTRA_FILES+="${ARG:1}"$'\n'; shift;;
      --extra ) APPEND_EXTRA_FILES+="$1"$'\n'; shift;;

      --no-bom | \
      --list-only | \
      '' ) FLAGS+="${ARG#--},";;

      -* ) MDTB_OPT+=( "$ARG" );;
      * ) GIT_LS_FILES+=( "$ARG" );;
    esac
  done
  exec < <(git ls-files --full-name -- "${GIT_LS_FILES[@]}" |
    sort --version-sort)
  while IFS= read -r VAL; do
    [ -f "$VAL" ] || continue
    set -- "$@" "$VAL"
    case "$APPEND_EXTRA_FILES" in
      *$'\n'"$VAL"$'\n'* )
        echo E: "Cannot append extra file: File is tracked in git: $VAL" >&2
        return 4;;
    esac
    KEY="$(git status --short -uall -- "$VAL")"
    # ^-- Column 1 is how the staging area differs from the HEAD commit.
    #     Column 2 is how the worktree differs from the staging area.
    #     Column 3 is always a space character.
    KEY="${KEY:0:2}"
  done
  [ -n "$1" ] || return 4$(echo E: 'Found no files to export!' >&2)
  local LEAK="$(git status --short -uall -- "$@")"
  [ -z "$LEAK" ] || LEAK="Exporting uncommitted changes: ${LEAK//$'\n'/, }"$'\n'

  local LIST=()
  readarray -t LIST < <(echo "$APPEND_EXTRA_FILES" | grep -Pe '\S')
  if [ -n "${LIST[0]}" ]; then
    set -- "$@" "${LIST[@]}"
    printf -v VAL -- '%s, ' "${LIST[@]}"
    VAL="${VAL%, }"
    [ -z "$LEAK" ] || LEAK+=' + '
    LEAK+="Exporting untracked extra files: $VAL"
  fi

  [ -z "$LEAK" ] || echo W: "$LEAK" >&2
  if [[ "$FLAGS" == *,list-only,* ]]; then printf -- '%s\n' "$@"; return $?; fi
  [[ "$FLAGS" == *,no-bom,* ]] || echo -ne '\xEF\xBB\xBF'
  ghciu-fmt-markdown-textblock bundle_files "${MDTB_OPT[@]}" "$@" || return $?
  [ -z "$LEAK" ] || { ! tty --silent <&1; } || echo W: "$LEAK" >&2
}











repomd_cli_init "$@"; exit $?
