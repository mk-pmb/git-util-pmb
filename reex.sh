#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function hard_reset_experimental () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local LOCAL_BRANCH="${1:-experimental}"; shift
  local RMT="${1:-origin}"; shift

  # split fetch_from:fetch_dest = remote_branch:local_branch
  local REMOTE_BRANCH="${LOCAL_BRANCH%%:*}"
  local LOCAL_BRANCH="${LOCAL_BRANCH##*:}"

  set -o pipefail -o errexit

  local REPO_DIR="$(git rev-parse --show-toplevel)"
  [ -d "$REPO_DIR" ] || return 2$(echo E: 'Failed to find git work tree!' >&2)
  cd -- "$REPO_DIR"

  local OWNER= SUDO=
  if stat --help 2>&1 | grep -qPe ' -c[, ]'; then
    # ^-- Busybox on some WD NAS only has -L and -t
    OWNER="$(stat -c %U .)"
    [ "$USER" == "$OWNER" ] || SUDO="sudo -u $OWNER"
  fi
  [ "${DEBUGLEVEL:-0}" -lt 2 ] || SUDO="echo X: $SUDO"

  $SUDO git stash
  echo "D: fetch: $(git remote -v | grep -Pe "^$RMT\s" | grep -vFe '(push)')"
  $SUDO git fetch "$RMT"
  echo D: checkout:
  $SUDO git checkout -b "$LOCAL_BRANCH" 2>/dev/null || true
  echo
  echo 'Relevant part starts here.' \
    'Ideally it should say "HEAD is now at" + relevant result.'
  $SUDO git stash list | sed -re '# not using <() for busybox compat.
    1s~^~\nW: Some uncommitted local changes have been stashed:\n~
    $s~$~\n~'
  $SUDO git reset --hard "$RMT/$REMOTE_BRANCH"
}


hard_reset_experimental "$@"; exit $?
