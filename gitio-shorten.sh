#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gitio_shorten () {
  local GITHUB_URL=
  local GITIO_ID=
  for GITHUB_URL in "$@"; do
    case "$GITHUB_URL" in
      'https://github.com/'* ) ;;
      * ) return 2$(echo 'error://git.io/strange_url' >&2)
    esac
    GITIO_ID="$(curl --silent --request POST \
      --data "url=$GITHUB_URL" http://git.io/create)"
    [ -n "$GITIO_ID" ] || return 8$(echo 'error://git.io/no_result' >&2)
    echo http://git.io/"$GITIO_ID"
  done
}




[ "$1" == --lib ] && return 0; gitio_shorten "$@"; exit $?
