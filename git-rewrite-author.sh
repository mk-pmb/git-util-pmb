#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function rewrite_author () {
  local OLD_MAIL="$1"; shift
  local OLD_MAIL_GUESS=
  [ -n "$OLD_MAIL" ] || OLD_MAIL_GUESS="$(git log -n 1 --pretty='format:%ae')"
  [ -n "$OLD_MAIL" ] || OLD_MAIL="$OLD_MAIL_GUESS"
  [ -n "$OLD_MAIL" ] || return $(fail 2 'guess old mail address')

  local NEW_NAME="$1"; shift
  [ -n "$NEW_NAME" ] || NEW_NAME="$(git config --get user.name)"
  [ -n "$NEW_NAME" ] || return $(fail 2 'guess new author name')

  local NEW_MAIL="$1"; shift
  [ -n "$NEW_MAIL" ] || NEW_MAIL="$(git config --get user.email)"
  [ -n "$NEW_MAIL" ] || return $(fail 2 'guess new mail address')

  echo "Rewrite history: Rename author * <$OLD_MAIL> to $NEW_NAME <$NEW_MAIL>"
  [ -n "$OLD_MAIL_GUESS" ] && [ "$OLD_MAIL_GUESS" == "$NEW_MAIL" ] && return $(
    fail 2 'guess old mail address different from new mail address')

  local BRANCH_PREFIX="${FUNCNAME//_/-}"
  local TEMP_BRANCH="$BRANCH_PREFIX-$(date +'%Y-%m%d-%H%M')-$$"
  echo -n "Create temporary branch $TEMP_BRANCH: "
  git branch "$TEMP_BRANCH"
  echo -n "checkout: "
  git checkout "$TEMP_BRANCH" || return $?

  find .git/refs/original/ -maxdepth 1 \
    -name "${BRANCH_PREFIX:-/E/no/BRANCH_PREFIX}*" -delete

  export OLD_MAIL NEW_NAME NEW_MAIL
  echo -n 'Rewrite: '
  git filter-branch --commit-filter '
    if [ "$GIT_AUTHOR_EMAIL" = "$OLD_MAIL" ]; then
      GIT_AUTHOR_NAME="$NEW_NAME"
      GIT_AUTHOR_EMAIL="$NEW_MAIL"
    fi
    if [ "$GIT_COMMITTER_EMAIL" = "$OLD_MAIL" ]; then
      GIT_COMMITTER_NAME="$NEW_NAME"
      GIT_COMMITTER_EMAIL="$NEW_MAIL"
    fi
    git commit-tree "$@"' "$TEMP_BRANCH"
  local RV="$?"

  echo
  git status
  return "$RV"
}


function fail () {
  local RV="$1"; shift
  echo "E: Failed to $*" >&2
  echo "$RV"
  return "$RV"
}









rewrite_author "$@"; exit $?
