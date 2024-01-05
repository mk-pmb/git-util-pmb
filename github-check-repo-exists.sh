#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function github_check_repo_exists () {
  local REPO="$1"   # e.g. gitgitgadget/git
  local REFS_URL="https://github.com/$REPO.git/info/refs"
  # ^-- Requesting just the file gives error "Please upgrade your git client.
  #   GitHub.com no longer supports git over dumb-http", so we have to add:
  REFS_URL+='?service=git-upload-pack'

  local WGET_OPTS=(
    --save-headers
    --header='Range: 0-0'
    --output-document=-
    -- "$REFS_URL"
    )
  local HTTP_REPLY="$(LANG=C wget "${WGET_OPTS[@]}" 2>&1)"
  local HTTP_STATUS='
    s~^\S+ request sent, awaiting response... ([0-9]{3} )~\1~p
    '
  HTTP_STATUS="$(<<<"$HTTP_REPLY" sed -nre "$HTTP_STATUS")"
  case "$HTTP_STATUS" in
    '200 '* ) echo public; return 0;;
    '401 '* ) echo maybe_private; return 1;;
    '404 '* ) echo not_found; return 1;;
  esac
  echo "E: unexpected HTTP status: '$HTTP_STATUS'" >&2
  return 23
}










[ "$1" == --lib ] && return 0; github_check_repo_exists "$@"; exit $?
