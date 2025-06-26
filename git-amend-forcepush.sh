#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_amend_forcepush () {
  local SELFPATH="$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")" # busybox

  [ -n "$1" ] || return 2$(echo 'E: no file names given' >&2)
  local COMMIT_ENV=()
  if [ "$1" == --confess ]; then
    shift
  else
    eval "COMMIT_ENV=( $(
      "$SELFPATH"/git-dump-commit-env-vars.sh --unamend env HEAD |
        sed -nre '/^GIT_COMMITTER_/p') )"
  fi

  local FLAGS=,
  case "$1" in
    -n | --no-push ) FLAGS+='nopush,'; shift;;
  esac

  [ "$1" == -- ] && shift
  [ "$#" -ge 1 ] || return 4$(echo E: 'Need at least one file to amend.' >&2)
  git add -A -- "$@" || return $?
  env "${COMMIT_ENV[@]}" git commit --amend \
    --reuse-message=HEAD -- "$@" || return $?

  [ "${FLAGS/,nopush,/}" == "$FLAGS" ] || return 0

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
