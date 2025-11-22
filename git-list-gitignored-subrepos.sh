#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ligisur_cli_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local PATH_ONLY='--only-matching'
  local MATCH_LNUM=
  while [ "$#" -ge 1 ]; do case "$1" in
    -d | --details ) PATH_ONLY=; shift;;
    -n | --match-lnum ) MATCH_LNUM='-n'; shift;;
    * ) echo E: "Unsupported CLI arg: $1"; return 4;;
  esac; done

  local SED_SPLIT_DETAILS='s~(/\.git)\s*(#|$)~\1 ~; s~(/\.git)\s+~\1\t~'
  if [ -z "$PATH_ONLY" ]; then
    true # caller wants details, nothing to do here.
  elif git grep --help | grep -qFe "$PATH_ONLY"; then
    # caller doesn't want details, and we can use git-grep to omit them.
    SED_SPLIT_DETAILS=
  else
    # caller doesn't want details, but git is too old to omit them,
    # so we need to have sed censor them.
    PATH_ONLY=
    SED_SPLIT_DETAILS+='; s~\t.*$~~'
  fi

  git grep $PATH_ONLY $MATCH_LNUM \
    -Pe '^/\S+/\.git(?=\s|#|$)' -- {,'**/'}.gitignore |
    sed -re "$SED_SPLIT_DETAILS"
}










ligisur_cli_main "$@"; exit $?
