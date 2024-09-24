#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function hard_reset_experimental () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  set -o pipefail -o errexit
  local REPO_DIR="$(git rev-parse --show-toplevel)"
  [ -d "$REPO_DIR" ] || return 2$(echo E: 'Failed to find git work tree!' >&2)
  cd -- "$REPO_DIR"
  local OWNER="$(stat -c %U .)"
  local SUDO=
  [ "$USER" == "$OWNER" ] || SUDO="sudo -u $OWNER"
  $SUDO git stash
  $SUDO git fetch origin
  $SUDO git checkout -b experimental 2>/dev/null || true
  echo
  echo 'Relevant part starts here.' \
    'Ideally it should say "HEAD is now at" + relevant result.'
  $SUDO git stash list | sed -rf <(echo '
    1s~^~\nW: Some uncommitted local changes have been stashed:\n~
    $s~$~\n~')
  $SUDO git reset --hard origin/experimental
}


hard_reset_experimental "$@"; exit $?
