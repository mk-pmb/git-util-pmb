#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function sync_ignored_subrepos () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local ACTION="$1"; shift
  case "$ACTION" in
    '' ) ACTION='ensure_exists';;
  esac

  local LIST=()
  readarray -t LIST < <(find -mount -maxdepth 32 -name .gitignore)
  readarray -t LIST < <(grep -HPe '^/\S+/\.git(?=\s|$)' \
    -- "${LIST[@]}" | sed -rf <(echo '
    s~^\./~~
    s~\.gitignore:/?~~
    s~\s+~ ~g
    s~ ?# ?~ # ~
    ') | LANG=C sort -Vu)
  local REPO= HINT= SXS_CNT=0
  local FAILS=()
  for REPO in "${LIST[@]}"; do
    case "$REPO" in
      *' # '* ) HINT="${REPO#* # }"; REPO="${REPO%% # *}";;
    esac
    REPO="${REPO%/.git}"
    echo "=== $REPO ==="
    sync_one_isr "$@" || FAILS+=( "$REPO" )
    (( SXS_CNT += 1 ))
    echo
  done

  if [ -n "${FAILS[*]}" ]; then
    echo "E: $ACTION: ${#FAILS[@]} of ${#REPOS[@]} repos had errors:" \
      "${FAILS[*]}" >&2
    return "${#FAILS[@]}"
  fi
  echo "D: $ACTION: success in $SXS_CNT repo(s)."
}


function sync_one_isr () {
  in_dir "$REPO" one_isr_"$ACTION" "$@" || return $?
}


function in_dir () {
  pushd -- "$1" >/dev/null || return $?
  shift
  "$@"
  local RV="$?"
  popd >/dev/null || return $?
  return "$RV"
}


function one_isr_ensure_exists () {
  [ -f .git/HEAD ] || git init . || return $?
  local BRANCHES=$'\n'"$(git branch)"$'\n'
  case "$BRANCHES" in
    *$'\n* '[A-Za-z0-9_]* )
      # looks like we have a sanely named, checked-out branch
      ;;
    * )
      [ -z "$$HINT" ] || echo "D: hint: $HINT" >&2
      echo "E: no checked-out branch?!" >&2
      return 3;;
  esac
}


function one_isr_aksyg () {
  set -o errexit
  aksyg |& unbuffered exec-as aksyg-tee tee -- "$PWD"/.git/logs/aksyg.log
  # ^-- exec-as and absolute path: mitigate gax tee hang @ byggvir 2019-09-04
}










sync_ignored_subrepos "$@"; exit $?
