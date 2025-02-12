#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ldap_simple_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local DBGLV="${DEBUGLEVEL:-0}"

  #==== We must resolve all potentially relative paths before we can cd. ====#

  local SELFFILE="$(readlink -f -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  [ "${SELFPATH:0:1}" == / ] || return 4$(
    echo E: "Failed to detect SELFPATH from '$0' in '$PWD'!" \
      "Found: '$SELFPATH'" >&2)

  local PATCHES_DIR=
  if [[ "$1" == --patches-dir=* ]]; then
    PATCHES_DIR="${1#*=}"
    shift
  else
    PATCHES_DIR="$(dirname -- "$0")"
    [ "${PATCHES_DIR:0:1}" == / ] || PATCHES_DIR="$PWD/$PATCHES_DIR"
    PATCHES_DIR="$(readlink -f -- "$PATCHES_DIR")"
  fi
  [ "${PATCHES_DIR:0:1}" == / ] || return 4$(
    echo E: "Failed to detect PATCHES_DIR from '$0' in '$PWD'!" \
      "Found: '$PATCHES_DIR'" >&2)

  #==== Now that all potentially relative paths are resolved, we can cd. ====#

  cd -- "$PATCHES_DIR" || return $?

  [ -n "$HOSTNAME" ] || local HOSTNAME="$(hostname -s)"
  [ -n "$HOSTNAME" ] || return 4$(
    echo E: 'Cannot detect current hostname.' >&2)

  local WANT_USER="$(stat -c %U -- "$PATCHES_DIR")"
  [ -n "$WANT_USER" ] || return 4$(
    echo E: "Cannot detect owner username for: $PATCHES_DIR" >&2)

  [ -n "$USER" ] || local USER="$(whoami)"
  [ -n "$USER" ] || return 4$(
    echo E: 'Cannot detect current username.' >&2)

  if [ "$USER" != "$WANT_USER" ]; then
    sleep 0.5s # throttle potential infinite re-exec
    echo D: "sudo-ing to user '$WANT_USER'." >&2
    cd /
    exec sudo --user="$WANT_USER" "$SELFFILE" \
      --patches-dir="$PATCHES_DIR" "$@"
    echo E: "Failed to re-exec as user '$WANT_USER'" >&2
    return 4
  fi

  local -A CFG=()
  while [[ "$1" == [a-z]*=* ]]; do CFG["${1%%=*}"]="${1#*=}"; shift; done
  [ "$1" == -- ] && shift

  export PATCHES_DIR
  local VAL=
  for VAL in cfg.{@"$HOSTNAME",site,local}.rc; do
    [ -f "$VAL" ] || continue
    in_func source -- "$VAL" --config || return $?
  done
  VAL=

  cfgdf git_remote origin
  cfgdf live_worktree ..
  # cfgdf live_ref # nope: see ldap_simple_guess_ref_if_empty below
  cfgdf live_ref_topnames 'livedemo staging master main'

  exec </dev/null
  cd -- "$PATCHES_DIR" || return $?

  [ -n "${CFG[patcher_branch]}" ] || CFG[patcher_branch]="$(
    git branch | sed -nre 's~^\* ~~p')"

  local HOST_PREFIX="$HOSTNAME"
  HOST_PREFIX="${HOST_PREFIX#serv}"
  case "$HOST_PREFIX" in
    *[0-9] ) ;;
    * ) HOST_PREFIX+='-';;
  esac

  [ -n "${CFG[live_branch]}" ] || CFG[live_branch]="${HOST_PREFIX}live"

  git fetch "${CFG[git_remote]}" || return $?
  git checkout "${CFG[patcher_branch]}" || return $?
  local PATCHER_REF="$(ldap_simple_decide_explicit_ref patcher_)"
  git reset --hard "$PATCHER_REF" || return $?

  # Only guess the live ref after we have updated the patcher_ref,
  # so that if no names from the old config are found, we at least
  # have updated the config for better luck on the next attempt.
  ldap_simple_guess_ref_if_empty live_ref || return $?

  cd -- "${CFG[live_worktree]}" || return $?
  local ACTUAL_LIVE_BRANCH="$(git branch | sed -nre 's~^\* ~~p')"
  [ -n "$ACTUAL_LIVE_BRANCH" ] || ACTUAL_LIVE_BRANCH='??'
  [ "$ACTUAL_LIVE_BRANCH" == "${CFG[live_branch]}" ] || return 4$(
    echo E: "Branch checked out is '$ACTUAL_LIVE_BRANCH' but expected" \
      "'${CFG[live_branch]}' in: $PWD" >&2)

  local LIVE_REF="$(ldap_simple_decide_explicit_ref live_)"
  git reset --hard "$LIVE_REF" || return $?

  export AUTOCOMMIT_PREFIX="${CFG[autocommit_prefix]}"
  "$SELFPATH"/find_apply_patches.sh "$PATCHES_DIR" || return $?
}


function cfgdf () { [ -n "${CFG["$1"]}" ] || CFG["$1"]="$2"; }
function in_func () { "$@"; }


function ldap_simple_decide_explicit_ref () {
  local PFX="$1"
  local VAL="${CFG["$PFX"ref]:-/}"
  [ "${VAL%/}" == "$VAL" ] || VAL+="${CFG["$PFX"branch]}"
  [ "${VAL#/}" == "$VAL" ] || VAL="${CFG[git_remote]}$VAL"
  echo "$VAL"
}


function ldap_simple_guess_ref_if_empty () {
  local OPT_NAME="$1"
  [ -z "${CFG[$OPT_NAME]}" ] || return 0
  local HEADS=" $(git ls-remote --heads "${CFG[git_remote]}" |
    cut -d / -sf 3- | tr -s '\r\n ' ' ') "
  local VAL=
  for VAL in ${CFG["$OPT_NAME"_topnames]}; do
    [[ "$HEADS" == *" $VAL "* ]] || continue
    CFG["$OPT_NAME"]="${CFG[git_remote]}/$VAL"
    echo "D: Guessing ref option '$OPT_NAME' value '$VAL'."
    return 0
  done
  echo D: "Detected head names in remote are:${HEADS% }" >&2
  echo E: "Option '$OPT_NAME' is unset and remote '${CFG[git_remote]}'" \
    "seems to not have any head with a name from option" \
    "${OPT_NAME}_topnames!" >&2
  return 4
}












ldap_simple_cli_init "$@"; exit $?
