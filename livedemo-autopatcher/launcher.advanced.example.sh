#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function autopatch_launcher_init () {
  #==== boilerplate code ====#
  # from git-util-pmb/livedemo-autopatcher/launcher.advanced.example.sh

  local SELFFILE="$(readlink -f -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  cd -- "$SELPATH" || return $?
  if [ "$1" == --no-reset-self ]; then
    shift
  else
    ../lib/git-util-pmb/livedemo-autopatcher/autoreset.sh ||
      return 4$(echo E: $SELFFILE: 'Failed to autoreset.')
    exec "$SELFFILE" --no-reset-self "$@"
    echo E: $SELFFILE: 'Failed to reexec after autoreset.'
    return 4
  fi

  #==== custom code should be below here ====#

  echo E: $SELFFILE: 'Stub! Write your custom code here if needed.'; return 8
  # e.g.
  # ./build/build.sh clean || return $?
  # ./build/build.sh lint || return $?
  # ./build/build.sh build || return $?
}


autopatch_launcher_init "$@"; exit $?
