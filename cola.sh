#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gitcola_helper_main () {
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  # cd -- "$SELFPATH" || return $?
  case "$1" in
    --func ) shift; "$@"; return $?;;
    --mmver ) detect_cola_version; return $?;;
  esac

  with-dotgit-worktree-symlink || return $?
  cola_wrapper "$@" &
  disown $!
  tty --silent && sleep 1  # delay prompt until after potential startup msgs
}


function symlnk () {
  local TARGET="$1"; shift
  local LINKFN="$1"; shift
  [ -L "$LINKFN" ] && rm -- "$LINKFN"
  ln --symbolic --no-target-directory -- "$TARGET" "$LINKFN" || return $?
}


function detect_cola_version () {
  git-cola --version | sed -nrf <(echo '
    s~^[A-Za-z0-9 ]* ([0-9]+)\.([0-9]+)\.[0-9\.a-z]+$~\v000\1\.000\2~
    s~^[A-Za-z ]* ([0-9]+)\.([0-9]+)$~\v000\1\.000\2~
    s~^\v~~p
    ') | sed -rf <(echo '
    s~(^)0*([0-9]{2}\.)~\1\2~
    s~(\.)0*([0-9]{3}$)~\1\2~
    ') | grep . || return 3$(echo "E: unable to detect git-cola version" >&2)
}


function cola_wrapper () {
  local COLA_VER="$(detect_cola_version)"
  [ -n "$COLA_VER" ] || return 3
  local GIT_CFGD="$HOME"/.config/git
  local COLA_HOME="$HOME"/.cache/git-cola/v"$COLA_VER"
  local COLA_CFGD="$COLA_HOME"/.config/git-cola
  [ -d "$COLA_CFGD" ] || mkdir -p "$COLA_CFGD" || return $?
  local COLA_JSON="$GIT_CFGD"/cola-v"$COLA_VER".json
  [ -f "$COLA_JSON" ] || >>"$COLA_JSON" || return $?
  symlnk "$GIT_CFGD"/gitconfig.cfg "$COLA_HOME"/.gitconfig || return $?
  symlnk "$COLA_JSON" "$COLA_CFGD"/settings || return $?
  symlnk "$COLA_JSON" "$COLA_HOME"/.cola || return $?

  local REPO_TOP="$(git rev-parse --show-toplevel)"
  local RPT_BFN=.GIT_COLA_STATUS.gen.tmp
  local RPT_FN=
  if [ -d "$REPO_TOP" ]; then
    # generate a status file to easily distinguish a clean working directory
    # from cola still scanning the repo.
    RPT_FN="$REPO_TOP/$RPT_BFN"
    echo -n 'scan: ' >"$RPT_FN"
    ( cd -- "$REPO_TOP"; repo_status_report ) >>"$RPT_FN" &
  fi

  local REPO_GITDIR="$(git rev-parse --git-dir)"
  if ! grep -qPe '\S' -m 1 "$REPO_GITDIR"/GIT_COLA_MSG >&2; then
    ( git config --get cola.defaultCommitMsg \
      || echo 'git config cola.defaultCommitMsg …'
    ) >"$REPO_GITDIR"/GIT_COLA_MSG
  fi

  local COLA_ENV=()
  COLA_ENV+=( HOME="$COLA_HOME" )
  env_enus "${COLA_ENV[@]}" git-cola "$@" &>/dev/null
  [ ! -f "$RPT_FN" ] || rm -- "$RPT_FN"
  with-dotgit-worktree-symlink --cleanup || return $?
  return 0
}


function env_enus () {
  env LANG{,UAGE}='en_US.UTF-8' "$@"
  return $?
}


function repo_status_report () {
  env_enus timeout 5s git status --short --branch | grep -vxFe "?? $RPT_BFN"
  echo "## end, rv=$?"$'\n'
  timeout 2s git-log-concise -n 10
}











gitcola_helper_main "$@"; exit $?
