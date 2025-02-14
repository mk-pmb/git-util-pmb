#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function reex_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DBGLV="${DEBUGLEVEL:-0}"
  local LOCAL_BRANCH="${1:-experimental}"; shift
  local RMT="${1:-origin}"; shift

  # split fetch_from:fetch_dest = remote_branch:local_branch
  local REMOTE_BRANCH="${LOCAL_BRANCH%%:*}"
  local LOCAL_BRANCH="${LOCAL_BRANCH##*:}"

  set -o pipefail -o errexit

  local REPO_DIR="$(git rev-parse --show-toplevel)"
  [ -d "$REPO_DIR" ] || return 2$(echo E: 'Failed to find git work tree!' >&2)
  cd -- "$REPO_DIR" || return 2$(
    echo E: "Failed (rv=$?) to chdir to the git work tree!" >&2)

  local OWNER= SUDO=
  if stat --help 2>&1 | grep -qPe ' -c[, ]'; then
    # ^-- Busybox on some WD NAS only has -L and -t
    OWNER="$(stat -c %U .)"
    [ "$USER" == "$OWNER" ] || SUDO="sudo -u $OWNER"
  fi
  [ "${DEBUGLEVEL:-0}" -lt 2 ] || SUDO="echo X: $SUDO"

  reex_check_device
  reex_vsudo_git stash
  reex_vsudo_git fetch "$RMT"
  reex_vsudo_git checkout -b "$LOCAL_BRANCH" \
    2>/dev/null || true
  echo
  echo 'Relevant part starts here.' \
    'Ideally it should say "HEAD is now at" + relevant result.'
  $SUDO git stash list | sed -re '# not using <() for busybox compat.
    1s~^~\nW: Some uncommitted local changes have been stashed:\n~
    $s~$~\n~'
  $SUDO git reset --hard "$RMT/$REMOTE_BRANCH"
}


function reex_check_device () {
  [ "$REEX_ANY_DEVICE" == "$PWD" ] && return 0 || true
  local DEVICE="$(df -P . | sed -re '1d;s~^(\S+)\s.*\s(\S+)$~\1 @ \2~')"
  DEVICE="${DEVICE//$'\n'/¶}"
  case "$DEVICE" in
    /dev/* ) ;;
    * )
      echo E: 'Flinching from operating on a filesystem on device' \
        "'$DEVICE' which may or may not be a network file system." \
        "Set environment variable REEX_ANY_DEVICE='$PWD' to ignore."  >&2
      return 4;;
  esac
}


function reex_vsudo_git () {
  local ACTION="$1"; shift
  # echo -n D: "$ACTION"
  local DESCR=
  if [ "$#" -ge 1 ]; then
    DESCR=" $*"
    case "$ACTION" in
      fetch )
        DESCR=": $(git remote -v | grep -Pe "^$1\s" | grep -vFe '(push)')";;
    esac
  fi
  # echo "$DESCR"
  $SUDO git "$ACTION" "$@" || return $?$(
    echo E: "Failed (rv=$?) to git $ACTION$DESCR" >&2)
}













reex_cli_init "$@"; exit $?
