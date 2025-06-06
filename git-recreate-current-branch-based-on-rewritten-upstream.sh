#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function recreate_current_branch_based_on_rewritten_upstream () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  exec </dev/null

  git status --short -uno | grep . && return 4$(
    echo E: 'Flinching: Worktree is not clean!' >&2) || true

  local GOOD_BRANCH="${1:-master}"; shift
  local GOOD_LATEST_COMMIT="$(git rev-parse "$GOOD_BRANCH")"
  [ -n "$GOOD_LATEST_COMMIT" ] || return 4$(
    echo E: "Unable to resolve branch name '$GOOD_BRANCH'" >&2)
  echo "Good branch '$GOOD_BRANCH' is at: $GOOD_LATEST_COMMIT"
  local MERGE_BASE="$(git merge-base HEAD "$GOOD_BRANCH")"
  echo "HEAD's latest common ancestor in branch '$GOOD_BRANCH': $MERGE_BASE"
  if [ "$MERGE_BASE" == "$GOOD_LATEST_COMMIT" ]; then
    echo "Nothing to do? HEAD seems to be at '$GOOD_BRANCH' exactly."
    return 0
  fi
  local HEAD_LATEST_COMMITS="$(list_latest_commit_messages -n 10)"
  local HEAD_LATEST_COMMIT_MSGS="$(
    echo "$HEAD_LATEST_COMMITS" | cut -f 2-)"
    # ^-- using echo to avoid temporary file

  local MATCHING_GOOD_COMMITS="$(
    list_latest_commit_messages "$MERGE_BASE..$GOOD_BRANCH" |
      grep -Ff <(echo "$HEAD_LATEST_COMMIT_MSGS"))"
  [ -n "$MATCHING_GOOD_COMMITS" ] || return 4$(
    echo E: "Unable to find the latest commit messages from HEAD branch" \
      "in branch '$GOOD_BRANCH'!" >&2)
  local MATCHING_GOOD_COMMIT_MSGS="$(
    echo "$MATCHING_GOOD_COMMITS" | cut -f 2-)"
    # ^-- using echo to avoid temporary file

  # Check if HEAD is a true continuation of MATCHING_GOOD_COMMIT_MSGS,
  # i.e. MATCHING_GOOD_COMMIT_MSGS is a prefix:
  local VAL="$HEAD_LATEST_COMMIT_MSGS"
  if [ "${HEAD_LATEST_COMMIT_MSGS:0:${#VAL}}" != "$VAL" ]; then
    colordiff -sU 9009009 --label good <(echo "$MATCHING_GOOD_COMMIT_MSGS"
      ) --label head <(echo "$HEAD_LATEST_COMMIT_MSGS") ||
    echo E: 'Unable to find perfect match' >&2
    return 4
  fi

  echo -n 'Ancestor on good branch: '
  local ONTO_COMMIT="${MATCHING_GOOD_COMMITS##*$'\n'}"
  ONTO_COMMIT="${ONTO_COMMIT%%$'\t'*}"
  [ -n "$ONTO_COMMIT" ] || return 4$(
    echo E: 'Failed to determine the ONTO_COMMIT!' >&2)
  local HEAD_COMMON="$(echo "$HEAD_LATEST_COMMITS" | grep -Ff <(
    echo "$MATCHING_GOOD_COMMIT_MSGS") | tail -n 1 | cut -f 1)"
  list_latest_commit_messages -n 1 "$ONTO_COMMIT" | cut -f 1,3

  echo -n 'Ancestor on HEAD:        '
  [ -n "$ONTO_COMMIT" ] || return 4$(
    echo E: 'Failed to determine the HEAD_COMMON commit!' >&2)
  list_latest_commit_messages -n 1 "$HEAD_COMMON" | cut -f 1,3

  for VAL in *.patch{,ed}; do
    [ -f "$VAL" ] || continue
    echo E: "Flinching: File exists: $VAL" >&2
    return 4
  done
  git format-patch "$HEAD_COMMON"..HEAD || return $?
  git reset --hard "$ONTO_COMMIT" || return $?
  git-am-and-mark-done -F 0 || return $?
  rm -- 0*.patched || return $?
}


function list_latest_commit_messages () {
  git log --reverse --no-decorate --color=never --format=oneline "$@" |
    sed -re 's~^(\S+)\s+~\1\t\t~; s~\.?$~\t|~'
}










recreate_current_branch_based_on_rewritten_upstream "$@"; exit $?
