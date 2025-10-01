#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function find_apply_patches () {
  local PATCHES_DIR="$1"; shift
  if [ "$PATCHES_DIR" == --func ]; then "$@"; return $?; fi
  exec </dev/null
  local TODO=(
    -L # follow symlinks
    "${PATCHES_DIR:-.}"
    -mindepth 1
    -maxdepth 3
    -name '.*' -prune ,
    -type f
    -name '[0-9][0-9]*'
    -printf '%f\t%p\n'
    )
  readarray -t TODO < <( # @2025-02-11 man bash: Array will be cleared.
    find "${TODO[@]}" | LANG=C sort -V | cut -sf 2-)
  local N_DONE=0

  local PATCH_START_UTS="$EPOCHSECONDS"
  local PATCH_FILE= PATCH_TITLE= PATCH_RV=
  [ -n "$AUTOCOMMIT_PREFIX" ] || AUTOCOMMIT_PREFIX='Live demo patch: '

  local VAL=
  local CMD=() OPTS=() ARGS=()
  local GIT_GREPS=()
  for PATCH_FILE in "${TODO[@]}"; do
    [ -f "$PATCH_FILE" ] || continue
    PATCH_TITLE="$PATCH_FILE"
    PATCH_TITLE="${PATCH_TITLE#$PATCHES_DIR}"
    PATCH_TITLE="${PATCH_TITLE#/}"

    readarray -t OPTS < <(sed -nre 's~^#!\s*\-\s+~~p' -- "$PATCH_FILE")
    readarray -t ARGS < <(
      scan_simple_args "$PATCH_FILE"
      # ^-- Don't sort: Order may be important for some CLI args.

      scan_git_greps "$PATCH_FILE" | LANG=C sort -Vu
      )

    # Nope: Running a script with no args is totally fine for various
    #   kinds of patch steps. For sed files, we had closed stdin above.
    # if [ "${#ARGS[@]}" == 0 ]; then
    #   echo W: "No arguments for patch step: $PATCH_TITLE" >&2
    #   continue
    # fi

    CMD=( "$PATCH_FILE" )
    [ -x "$PATCH_FILE" ] || case "$PATCH_FILE" in
      *.js ) CMD=( nodejs -- "$PATCH_FILE" );;
      *.patch ) CMD=( git am -- );;
      *.pl ) CMD=( perl -- "$PATCH_FILE" );;
      *.sed ) CMD=( sed -rf "$PATCH_FILE" -i -- );;
      *.sh ) CMD=( bash -- "$PATCH_FILE" );;
      * )
        # echo E: "Unsupported unexecutable patch step: $PATCH_TITLE" >&2
        continue;;
    esac

    echo "# Patch step: $PATCH_TITLE"
    "${CMD[@]}" "${OPTS[@]}" "${ARGS[@]}"; PATCH_RV="$?"

    if git status --porcelain | grep -q .; then
      git add -A . || return $?
      VAL="$AUTOCOMMIT_PREFIX$PATCH_TITLE"
      [ "$PATCH_RV" == 0 ] || VAL="[fail] $VAL (exit code: $PATCH_RV)"
      git commit -m "$VAL" || return $?
    fi

    [ "$PATCH_RV" == 0 ] || return "$PATCH_RV"$(
      echo E: "Patch step failed (rv=$PATCH_RV): $PATCH_TITLE" >&2)
    (( N_DONE += 1 ))
  done
  local PATCH_DONE_UTS="$EPOCHSECONDS" DURA_SEC=
  (( DURA_SEC = PATCH_DONE_UTS - PATCH_START_UTS ))
  echo "# Done, $N_DONE patch steps have been applied in $DURA_SEC sec." \
    "@ $(printf '%(%F %T)T' -1)"
}


function literally_echo () {
  case "$#$1" in
    1-n | 1-e ) echo -- "$1";;
    * ) echo "$@";;
  esac
}


function scan_simple_args () {
  local SCAN=()
  local VAL='s~^#!\s*\+(<([^<>]*)>|)\s+~\2>~p' OPT=
  readarray -t SCAN < <(sed -nre "$VAL" -- "$@")
  # ^-- Don't sort: Order may be important for some CLI args.
  for VAL in "${SCAN[@]}"; do
    OPT="${VAL%%'>'*}"
    VAL="${VAL#*'>'}"
    case "$OPT"' ' in
      '= ' ) literally_echo "$VAL";;
      ' ' )
        OPT="${VAL//[^\*\?]/}"
        [ -z "$OPT" ] || echo W: $FUNCNAME: \
          "Please clarify whether the wildcard '${OPT:0:1}' is meant literally" \
          "(in that case, use '#!+<=> your *literal* argument')" \
          "or maybe you meant something like '#!+<git ls-files> docs/*.md'?" \
          "in: '$VAL'" >&2
        literally_echo "$VAL";;
      'git ls-files '* ) $OPT -- "$VAL";;
      * ) echo E: $FUNCNAME: "Unsupported effect option: '$OPT'" >&2; return 4;;
    esac
  done
}


function scan_git_greps () {
  local SCAN=()
  local VAL='s~^#!\s*\+<git-grep(:[A-Z]| -[A-Za-z]+|)>~\1>~p' OPT=
  readarray -t SCAN < <(sed -nre "$VAL" -- "$@")
  for VAL in "${SCAN[@]}"; do
    OPT="${VAL%%'>'*}"
    VAL="${VAL#*>}"
    case "$OPT" in
      '' ) OPT=" -Fe$VAL";;
      :[A-Z] ) OPT="-${OPT#:}e";;
    esac
    git grep -l $OPT "$VAL"
  done
}










find_apply_patches "$@"; exit $?
