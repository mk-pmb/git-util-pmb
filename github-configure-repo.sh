#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function github_configure_repo () {
  local RUNMODE="$1"; shift
  export LANG{,UAGE}=en_US.UTF-8

  [ -n "$GIT_DIR" ] || local GIT_DIR="$(git rev-parse --show-toplevel)"
  local GIT_DIR_BN="$(basename -- "$GIT_DIR" .git)"
  local GH_SECT='github'
  local GH_SSH_SRV="$(gh_cfg_get ssh-host)"
  [ -n "$GH_SSH_SRV" ] || GH_SSH_SRV='github.com'
  local GH_USER="$(gh_cfg_get username)"
  local GH_USER_RGX="$(<<<"$GH_USER" sed -re 's~[^A-Za-z0-9_-]~\\&~g')"

  case "$RUNMODE" in
    --func ) "$@"; return $?;;
  esac

  [ "$(git rev-parse --git-dir)" == .git ] || return 3$(
    echo "E: Flinching: To avoid accidentially configuring a parent repo," \
      "$FUNCNAME must be run in the toplevel of the repo." >&2)

  maybe_configure_locally user.name "$GH_USER"
  local GH_MAIL="$(gh_cfg_get email)"
  [ -n "$GH_MAIL" ] || GH_MAIL="$GH_USER"'@users.noreply.github.com'
  maybe_configure_locally user.email "$GH_MAIL"

  git config avahi-remotes.domain ''

  local GHRMT_LIST=()
  local GH_RMT='origin'
  local AUTOADD_STRATEGIES=(
    'nodejs package.json'
    )
  local STRAT=
  for STRAT in '' "${AUTOADD_STRATEGIES[@]}"; do
    if [ -n "$STRAT" ]; then
      echo "I: Trying to guess and add a remote from oracle '$STRAT'"
      autoadd_ghrmt_"${STRAT//[^a-z0-9_]/_}" || continue
    fi
    optimize_remote_urls_syntax
    readarray -t GHRMT_LIST < <(find_github_remotes)
    [ -n "${GHRMT_LIST[*]}" ] && break
  done

  autodetect_upstream || return $?

  [ -n "${GHRMT_LIST[*]}" ] || return 2$(
    echo "E: No github remotes found! Try: git remote add $GH_RMT" \
      "git@$GH_SSH_SRV:$GH_USER/$GIT_DIR_BN.git" >&2)

  harmonize_gh_ssh_srv "${GHRMT_LIST[@]}" || return $?

  [ -n "$GH_RMT" ] || return 4$(echo 'E: GH_RMT not configured' >&2)
  git remote | grep -qxFe "$GH_RMT" || return 4$(
    echo "E: There is no remote named '$GH_RMT'" >&2)

  git config remote."$GH_RMT".sshkeyfile "$(gh_cfg_get keyfile)"

  local CUR_BRANCH="$(git branch | grep -xPe '\*\s+\S+' -m 1 \
    | grep -oPe '\S+$' || echo master)"

  if ! git_check_ref_exists "$GH_RMT/$CUR_BRANCH"; then
    echo "W: ref not found, trying to fetch: $GH_RMT/$CUR_BRANCH" >&2
    vfail git_nohint fetch "$GH_RMT"
  fi

  if git_check_ref_exists "$GH_RMT/$CUR_BRANCH"; then
    vfail git_nohint branch --set-upstream-to="$GH_RMT/$CUR_BRANCH"
  else
    try_suggest_create_repo
  fi

  git-prettify-repo-config
}


function maybe_configure_locally () {
  local KEY="$1"; shift
  local VAL="$1"; shift
  local HAS="$(git config --local "$KEY")"
  case "$HAS" in
    '' )
      git config --local -- "$KEY" "$VAL"
      return $?;;
    "$VAL" ) return 0;;
  esac
  echo "W: Local config option exists! => skipped:" \
    "git config --local -- '$KEY' '$VAL'" >&2
}


function optimize_remote_urls_syntax () {
  readarray -t GHRMT_LIST < <(git config --list | sed -nre '
    s~^remote\.([^=\.]+)\.(url)=https://(github\.com)/('"$GH_USER_RGX"')/|\
               ^- 1       ^- 2           ^- 3          ^- 4               \
    ~\r\1 git@\4.ssh.\3:\4/~
    /^\r/{
      s~^\r~~
      /\.git$/!s~/?$~.git~
      p
    }' | sort -u)
  local GITIFY=
  for GITIFY in "${GHRMT_LIST[@]}"; do
    echo "I: Convert remote URL: ${GITIFY// / = }"
    git remote set-url "${GITIFY%% *}" "${GITIFY#* }"
  done
}


function git_check_ref_exists () {
  git rev-parse --verify --quiet "$1" >/dev/null; return $?
}


function find_github_remotes () {
  git config --list | sed -nre '
    s~^remote\.([^=\.]+\.(url))=git\@(([a-z0-9-]+\.)*github\.com):(\S+)$|\
               ^- 1      ^- 2        ^^- 3,4                      ^- 5   \
    ~\1 \3 \5~p' | sort -u | grep .
  return $?
}


function gh_cfg_get () {
  git config --get "$GH_SECT"."$1"
}


function harmonize_gh_ssh_srv () {
  local RMT_NAME=
  local RMT_HOST=
  local RMT_PATH=
  for RMT_PATH in "$@"; do
    RMT_NAME="${RMT_PATH%% *}"; RMT_PATH="${RMT_PATH#* }"
    RMT_HOST="${RMT_PATH%% *}"; RMT_PATH="${RMT_PATH#* }"
    # echo "$RMT_NAME: $RMT_HOST [$RMT_PATH]"
    if [ "$RMT_HOST" != "$GH_SSH_SRV" ]; then
      echo "I: Remote $RMT_NAME: host [$RMT_HOST -> $GH_SSH_SRV]:$RMT_PATH"
      git config "remote.$RMT_NAME" "git@${GH_SSH_SRV}:$RMT_PATH"
    fi
  done
}


function fixup_git_remote_url () {
  local URL="$1"
  case "$URL" in
    git+https://* ) URL="${URL#*+}";;
  esac
  echo "$URL"
}


function autoadd_ghrmt_verbose () {
  local RMT_URL="$1"
  [ -n "$RMT_URL" ] || return 1
  echo "I: Found a plausible guess for adding a remote: $GH_RMT = $RMT_URL"
  RMT_URL="$(fixup_git_remote_url "$RMT_URL")"
  git remote add "$GH_RMT" "$RMT_URL"
  return $?
}


function autoadd_ghrmt_nodejs_package_json () {
  local MAXLN=10
  local REPO_URL='s~^\s*"url":\s*"git\+(\S+)".*$~\1~p'
  REPO_URL="$(grep -Fe '"repository":' package.json -A $MAXLN -m 1 \
    | grep -Fe '}' -B $MAXLN -m 1 | sed -nre "$REPO_URL")"
  autoadd_ghrmt_verbose "$REPO_URL"
  return $?
}


function vfail () {
  local RV=
  "$@"; RV=$?
  [ "$RV" == 0 ] || echo "W: rv=$RV: $*" >&2
  return "$RV"
}


function list_remote_names_and_users () {
  git remote -v | sed -nre 's~^([A-Za-z0-9._-]+)\s+\S+[/@\.]github\.com[:/]($\
    |[a-z0-9_-]+)/\S+\s+\(fetch\)$~/\1/\t@\2@~p'
}


function autodetect_upstream () {
  local HOW='
    rename_foreign_origin_to_upstream
    autodetect_upstream_from_package_json
    '
  for HOW in $HOW; do
    git remote | grep -qxFe upstream && return 0
    "$HOW" || true
  done
}


function rename_foreign_origin_to_upstream () {
  local RMT_NAMES_USERS="$(list_remote_names_and_users)"
  if ! <<<"$RMT_NAMES_USERS" grep -qPe '^/origin/'; then
    # There is no remote "origin" at all. Let's rename upstream if it's ours.
    <<<"$RMT_NAMES_USERS" grep -qxFe $'/upstream/\t'"@$GH_USER@" \
      && vfail git remote rename upstream origin
    return 0
  fi
  local FOREIGN="$(<<<"$RMT_NAMES_USERS" grep -vFe "@$GH_USER@")"
    # Let's check whether
  if ! <<<"$FOREIGN" grep -qPe '^/origin/'; then
    return 0    # There is no foreign remote "origin".
  fi
  vfail git remote rename origin upstream
  return $?
}


function git_nohint () {
  git "$@" 2>&1 | grep -vPe '^hint: '
  return "${PIPESTATUS[0]}"
}


function try_suggest_create_repo () {
  local SUG_NAME='s~\s+~ ~g
    s~ \(fetch\)$~\a~
    s~\.git\a$~\a~
    s~^(\S+) \S+\bgithub\.com[:/]'"$GH_USER_RGX"'/([^/ ]+)\a$~=\1= \2~p'
  SUG_NAME="$(LANG=C git remote --verbose | sed -nre "$SUG_NAME
    " | LANG=C grep -m 1 -Fe "=$GH_RMT= ")"
  SUG_NAME="${SUG_NAME##* }"
  [ -n "$SUG_NAME" ] || return 3
  echo "D: suggest create repo with name: $SUG_NAME"

  local DESCR_STRATS=(
    'nodejs package.json'
    )
  local SUG_DESCR=
  echo -n "D: trying to suggest a description. "
  for SUG_DESCR in "${DESCR_STRATS[@]}"; do
    echo -n "$SUG_DESCR? "
    SUG_DESCR="${SUG_DESCR// /_}"
    SUG_DESCR="${SUG_DESCR//./_}"
    SUG_DESCR="$(try_suggdescr_"$SUG_DESCR")"
    [ -n "$SUG_DESCR" ] && break
  done
  if [ -n "$SUG_DESCR" ]; then
    echo 'got it.'
    echo "D: suggested repo description: $SUG_DESCR"
  else
    echo 'no idea.'
  fi

  local CREA_URL="https://$GH_SSH_SRV/new?"
  [ -n "$SUG_DESCR" ] && CREA_URL+='repository_description=%1Bbase64:'"$(
    echo -n "$SUG_DESCR" | base64 --wrap=0 | tr -d =)&"

  # add repo name last, to help me notice when my terminal cut off
  # parts of the link.
  CREA_URL+="repository_name=$SUG_NAME"
  echo "H: Create? $CREA_URL"
}


function try_suggdescr_nodejs_package_json () {
  [ -f package.json ] || return 2
  # grep -m1 -Pe '^ +"description": *"
  nodejs -p 'require("./package.json").description'
}


function autodetect_upstream_from_package_json () {
  [ -f package.json ] || return 2
  # grep -m1 -Pe '^ +"description": *"
  local REPO_URL='var r = require("./package.json").repository; r.url || r'
  REPO_URL="$(nodejs -p "$REPO_URL")"
  [ -n "$REPO_URL" ] || return 2

  local RGX='^[A-Za-z0-9_-]+/[A-Za-z0-9_-]+$'
  [[ "$REPO_URL" =~ $RGX ]] && REPO_URL="https://github.com/$REPO_URL.git"

  case "$REPO_URL" in
    "git@$GH_SSH_SRV:$GH_USER/"* ) return 0;;
    *"://$GH_SSH_SRV/$GH_USER/"* ) return 0;; # * = (git+|)https
    *"://github.com/$GH_USER/"* ) return 0;; # * = (git+|)https
  esac
  REPO_URL="$(fixup_git_remote_url "$REPO_URL")"
  echo D: "Adding git remote upstream = $REPO_URL"
  git remote add -- upstream "$REPO_URL" || return $?
}












github_configure_repo "$@"; exit $?
