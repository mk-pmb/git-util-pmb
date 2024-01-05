#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function etckeeper_git_sudo_helper () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local GIT_NAME="$(git config -- user.name)"
  [ -n "$GIT_NAME" ] || return 4$(echo "E: Failed to detect author name" >&2)
  local GIT_MAIL="$(git config -- user.email)"
  [ -n "$GIT_MAIL" ] || return 4$(echo "E: Failed to detect author email" >&2)
  sudo --preserve-env \
    GIT_{AUTHOR,COMMITTER}_NAME="$GIT_NAME" \
    GIT_{AUTHOR,COMMITTER}_EMAIL="$GIT_MAIL" \
    etckeeper vcs "$@"; return $?
}

[ "$1" == --lib ] && return 0; etckeeper_git_sudo_helper "$@"; exit $?
