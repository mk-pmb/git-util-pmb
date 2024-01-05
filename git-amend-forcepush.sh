#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_amend_forcepush () {
  [ -n "$1" ] || return 2$(echo 'E: no file names given' >&2)
  git add -A -- "$@" || return $?
  git commit --amend --reuse-message=HEAD -- "$@" || return $?

  local BRN="$(git branch | grep -xPe '\*\s+\S+' -m 1 \
    | grep -oPe '\S+$')"
  [ -n "$BRN" ] || return 4$(echo 'E: failed to find current branch' >&2)

  local RMT="$(git config --local branch."$BRN".remote \
    || git config --local branch.master.remote)"
  [ -n "$RMT" ] || return 4$(
    echo "E: failed to find remote for branch $BRN" >&2)

  git push --force "$RMT" "$BRN:$BRN" || return $?
}










[ "$1" == --lib ] && return 0; git_amend_forcepush "$@"; exit $?
