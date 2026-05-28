#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function repomd_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local VAL="$(git rev-parse --show-cdup)"
  [ -z "$VAL" ] || cd -- "$VAL" || return $?
  exec < <(git ls-files --full-name | sort --version-sort)
  while IFS= read -r VAL; do
    [ -f "$VAL" ] || continue
    set -- "$@" "$VAL"
  done
  echo -ne '\xEF\xBB\xBF'
  ghciu --ignore-local-config -Q \
    fmt_markdown_textblock__bundle_files "$@" || return $?
}











repomd_cli_init "$@"; exit $?
