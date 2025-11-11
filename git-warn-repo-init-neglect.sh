#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
# Warn me when it seems like I might be going to commit to a repo
# not yet sufficiently configured.


function wrin_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")" # busybox
  # cd -- "$SELFPATH" || return $?
  exec </dev/null

  local GIT_CDUP="$(git rev-parse --show-cdup)"
  local GIT_USER_NAME="$(git config user.name)"
  local GIT_USER_MAIL="$(git config user.email)"
  local GIT_USER_SEEMS_FAKE="$(wrin_does_my_git_identity_seem_fake)"
  local GIT_ALL_BRANCH_NAMES="$(git branch | tr -s '\n* ' ' ')"

  local HINT= WARN=
  [ -n "$GIT_ALL_BRANCH_NAMES" ] || wrin_no_branches_yet
  wrin_anon_public_package_json

  [ -z "$HINT" ] || echo -n "$HINT" >&"${GIT_WRIN_HINT_FD:-1}"
  [ -z "$WARN" ] || echo -n "$WARN" >&"${GIT_WRIN_WARN_FD:-2}"
  [ -z "$WARN" ] || return 2

  case "$1" in
    '' ) return 0;;
  esac
  echo E: "Unexpected CLI argument: $1" >&"${GIT_WRIN_WARN_FD:-2}"
  return 2
}


function wrin_no_branches_yet () {
  local VAL=
  HINT+='H: No branches yet? To create an empty branch: env'
  VAL='GIT_{AUTHOR,COMMITTER}_'
  HINT+=" ${VAL}DATE='$(date -R)'"
  [ -z "$GIT_USER_SEEMS_FAKE" ] ||
    HINT+=" ${VAL}NAME='$GIT_USER_NAME' ${VAL}EMAIL='$GIT_USER_MAIL'"
  HINT+=" git commit --allow-empty --message='Init repo.'"$'\n'
}


function wrin_anon_public_package_json () {
  local PKJS_PUB="$(wrin_does_package_json_seem_to_be_meant_for_publishing \
    {,"$GIT_CDUP"/}package.json)"
  [ -z "$PKJS_PUB" ] || [ -z "$GIT_USER_SEEMS_FAKE" ] ||
    WARN+="Found $PKJS_PUB but $GIT_USER_SEEMS_FAKE."$'\n' >&2
}


function wrin_does_my_git_identity_seem_fake () {
  local SUS=
  [[ -n "$GIT_USER_NAME" ]] ||
    SUS+=' git user name is empty,'
  [[ "${GIT_USER_NAME,,}" == 'user '* ]] &&
    SUS+=' git user name starts with "user",'
  [[ "${GIT_USER_NAME,,}" == *' name' ]] &&
    SUS+=' git user name ends with "name",'
  [[ -n "$GIT_USER_MAIL" ]] ||
    SUS+=' git user email is empty,'
  [[ "${GIT_USER_MAIL,,}" == *'.tld' ]] &&
    SUS+=' git user email ends with ".tld",'
  [ -n "$SUS" ] || return 0
  echo "the configured git identity seems fake:${SUS%,}"
}


function wrin_does_package_json_seem_to_be_meant_for_publishing () {
  local VERBATIM_BANS='
    "private":"false"
    '
  VERBATIM_BANS="$(echo "$VERBATIM_BANS" | sed -nre 's~^\s+(\S)~\1~p')"
  local PERLRE_BANS='($:'
  PERLRE_BANS+='|^"(bugs|homepage|repository|url)":"(git\+|)https?://'
  PERLRE_BANS+=')'

  local SPLIT_RX='s~"[#-~]+":"~\n&~g'
  local PKJS= FOUND=
  for PKJS in "$@"; do
    [ -f "$PKJS" ] || continue
    FOUND="$( <"$PKJS" tr -d '\r\n \t' | sed -re "$SPLIT_RX" | (
      grep -m 1 -oFe "$VERBATIM_BANS" || grep -m 1 -oPe "$PERLRE_BANS"
      ) )"
    [ -n "$FOUND" ] || continue
    echo "'$FOUND' in '$PKJS'"
    return 0
  done
}











wrin_cli_init "$@"; exit $?
