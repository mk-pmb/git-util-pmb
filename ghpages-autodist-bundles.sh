#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function ghpbun_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local ORIG_CWD="$(readlink -f .)"
  cd -- "$ORIG_CWD" || return $?
  local ORIG_BRN="$(git branch | sed -nre 's!^\* !!p')"
  [ -n "$ORIG_BRN" ] || return 4$(
    echo E: 'Cannot determine current branch.' >&2)
  local DIST_DIR='dist'
  cd -- "$(git rev-parse --show-cdup)" || return $?
  local REPO_DIR="$PWD"
  local DEST_RMT='origin'
  local DEST_BRN='gh-pages'
  local COMMIT_UTS="$(git log --max-count=1 --format=%ct "$ORIG_BRN")"

  export GIT_{AUTHOR,COMMITTER}_NAME='auto-dist'
  export GIT_{AUTHOR,COMMITTER}_EMAIL='auto-dist@none.invalid'

  echo D: "git fetch $DEST_RMT…" || return $?
  git fetch "$DEST_RMT" || return $?

  local VAL='/### BEGIN ghpages-autodist-bundles ###/'
  VAL+=",${VAL/BEGIN/ENDOF}"'{/^\s*#/!°}'
  local SED_BUNDLES="$VAL"
  local TODO= DGI="$DIST_DIR"/.gitignore
  TODO="$(sed -nre "${SED_BUNDLES/°/p}" -- "$DGI" | sed -re '/^\s*#/d' |
    LANG=C sort --version-sort)"$'\n'
  set -- find "$DIST_DIR/" -mount -maxdepth 1 -type f '(' -false
  while [ -n "$TODO" ]; do
    VAL="${TODO%%$'\n'*}"; TODO="${TODO#*$'\n'}"
    case "$VAL" in
      '' ) continue;;
      /* ) ;;
      * ) echo E: "Bundle pattern must start with a slash: '$VAL'"; return 4;;
    esac
    set -- "$@" -o -path "$DIST_DIR$VAL"
  done
  set -- "$@" ')'
  local BUNDLE_FILES=()
  readarray -t BUNDLE_FILES < <("$@")
  local DIST_FILE_DESCR='dist bundle(s)'
  [ -n "${BUNDLE_FILES[0]}" ] || return 4$(
    echo E: "Could not find any $DIST_FILE_DESCR!" >&2)

  local GH_WT_SUBDIR='wt.ghpages-autodist-bundles'
  local GH_WT_PATH="$(git rev-parse --git-dir)/$GH_WT_SUBDIR"
  if [ ! -d "$GH_WT_PATH" ]; then
    echo D: "Gonna prepare worktree $GH_WT_SUBDIR:"
    set -- git worktree add --no-checkout "$GH_WT_PATH" "$DEST_BRN"
    "$@" || return 4$(echo E: "Cannot $*" >&2)
  fi
  cd -- "$GH_WT_PATH" || return $?
  git checkout "$DEST_BRN" || return $?
  git reset --hard "$ORIG_BRN" || return $?

  sed -re "${SED_BUNDLES/°/d}" -i -- "$DGI" || return $?
  (( COMMIT_UTS += 60 ))
  export GIT_{AUTHOR,COMMITTER}_DATE="$(date -Rd "@$COMMIT_UTS")"
  git commit --message="[auto-dist] Un-gitignore $DIST_FILE_DESCR." \
    -- "$DGI" || return $?

  echo D: 'Copy $DIST_DIR/ files: '
  for VAL in "${BUNDLE_FILES[@]}"; do
    echo -n "$VAL, "
    cp --target-directory="$DIST_DIR/" -- "$REPO_DIR/$VAL" || return $?
  done
  echo done.
  git add dist || return $?

  (( COMMIT_UTS += 60 ))
  export GIT_{AUTHOR,COMMITTER}_DATE="$(date -Rd "@$COMMIT_UTS")"
  git commit --message="[auto-dist] Commit $DIST_FILE_DESCR." \
    -- "$DIST_DIR/" || return $?

  git checkout "$ORIG_BRN" -- "$DGI" || return $?
  (( COMMIT_UTS += 60 ))
  export GIT_{AUTHOR,COMMITTER}_DATE="$(date -Rd "@$COMMIT_UTS")"
  VAL="[auto-dist] Re-gitignore $DIST_FILE_DESCR."
  VAL+=$'\n\nThis is meant to help avoid gitg crashing when trying to diff.'
  git commit --message="$VAL" -- "$DGI" || return $?

  echo
  echo -n D: "Gonna publish branch $ORIG_BRN" \
    "+ $DIST_FILE_DESCR --> $DEST_RMT/$DEST_BRN:"
  local VAL=5
  while true; do
    echo -n " $VAL…"
    (( VAL -= 1 ))
    [ "$VAL" -ge 1 ] || break
    sleep 1s
  done
  echo
  git push --force "$DEST_RMT" HEAD:"$DEST_BRN" || return $?
}










ghpbun_cli_init "$@"; exit $?
