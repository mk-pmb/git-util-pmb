#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function with_dotgit_worktree_symlink () {
  case "$#:$1" in
    1:--cleanup ) cleanup_dotgit_worktree_symlink; return $?;;
  esac

  if [ "$PWD" == "$SYMDOTGIT_WTREE" -o -L .git ]; then
    [ "$#" -ge 1 ] || return 3$(
      echo 'E: already in worktree with symlink?' >&2)
    "$@"; return $?
  fi

  local SYMDOTGIT_ORIGPWD="$PWD"
  local SYMDOTGIT_WTREE="$(git config --get core.worktree)"
  export SYMDOTGIT_WTREE
  local SYM_TGT=
  if [ -n "$SYMDOTGIT_WTREE" ]; then
    echo -n 'Preparing .git symlink to make the detached worktree' \
      'compatible with non-aware git tools: '
    if [ -L "$SYMDOTGIT_WTREE/.git" ]; then
      echo -n 'symlink already exists '
      SYM_TGT="$(readlink -m -- "$SYMDOTGIT_WTREE/.git")"
      if [ "$SYM_TGT" == "$(readlink -m -- "$SYMDOTGIT_ORIGPWD")" ]; then
        echo -n 'and points to the our repo. '
      else
        echo 'but points to another directory:'
        echo "I: expected target: $SYMDOTGIT_ORIGPWD" >&2
        echo "E: current  target: $SYM_TGT" >&2
        return 3
      fi
    else
      ln --symbolic --no-target-directory \
        -- "$SYMDOTGIT_ORIGPWD" "$SYMDOTGIT_WTREE/.git" || return $?
    fi
    cd -- "$SYMDOTGIT_WTREE" || return $?
    echo ok.
  fi
  [ "$#" == 0 ] && return 0
  local CMD_ENV=()
  [ -n "$debian_chroot" ] || CMD_ENV+=( debian_chroot='sym.git' )
  [ -n "${CMD_ENV[0]}" ] && CMD_ENV=( env "${CMD_ENV[@]}" )
  "${CMD_ENV[@]}" "$@"
  local RV="$?"
  cleanup_dotgit_worktree_symlink
  return "$RV"
}


function cleanup_dotgit_worktree_symlink () {
  [ -n "$SYMDOTGIT_WTREE" ] || return 0
  [ -n "$SYMDOTGIT_ORIGPWD" ] && cd -- "$SYMDOTGIT_ORIGPWD"
  # ^-- In case of network file system and a reconnect during cola execution,
  #     select the re-connected instance of the current directory.
  local LNK="$SYMDOTGIT_WTREE/.git"
  [ -L "$LNK" ] && rm -- "$LNK"
  return 0
}













with_dotgit_worktree_symlink "$@"; exit $?
