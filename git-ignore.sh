#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function cli_main () {
  local INVOKED_AS="$(basename -- "$0" .sh)"
  local DBGLV="${DEBUGLEVEL:-0}"
  local IGN_FN='.gitignore'
  local OPT=

  case "$INVOKED_AS" in
    [a-z]*ig ) IGN_FN=".${INVOKED_AS}nore";;
    git-ignore-subrepos ) OPT='--sub-repos';;
  esac

  if [ -z "$OPT" ]; then OPT="$1"; shift; fi
  case "$OPT" in
    -- ) ;;
    '--'func=* ) "${OPT#*=}" "$@"; return $?;;
    # ^-- The quotes are to hide it from --help.
    --sub-repos | \
    --list-auto-delete | --auto-delete )
      OPT="${OPT#--}"
      "${OPT//-/_}" "$@"
      return $?;;
    --help | \
    -* )
      local -fp "${FUNCNAME[0]}" | guess_bash_script_config_opts-pmb
      [ "${OPT//-/}" == help ] && return 0
      echo "E: $0, CLI: unsupported option: $OPT" >&2; return 1;;
    * ) ;;
  esac

  add_to_or_edit_gitignore "$OPT" "$@"
  return $?
}


function add_to_or_edit_gitignore () {
  >>"$IGN_FN" || return $?
  local HAD=
  if [ -s "$IGN_FN" ]; then
    HAD="$(cat -- "$IGN_FN"; echo :)"
    HAD="${HAD%:}"
    [ -n "$HAD" ] || return 4$(
      echo "E: Failed to read old content of file $IGN_FN" >&2)
  fi
  local HAD_LEN="${#HAD}"
  [[ "$HAD" == *$'\n' ]] || echo >>"$IGN_FN" || return $?

  [ "$HAD_LEN" -ge 1 ] || suggest_initial_ignores >>"$IGN_FN" || return $?
  [[ "${HAD,,}" == *$'\n# unsorted'* ]] || echo >>"$IGN_FN" $'\n\n\n#' \
    'Unsorted stuff (this section should be empty):' || return $?

  case "$#:$1" in
    [01]: ) "${VISUAL:-true}" "$IGN_FN"; return $?;;
  esac

  local ARG=
  for ARG in "$@"; do
    case "$ARG" in
      '' ) continue;;
      -- ) continue;;
    esac
    ARG="/$ARG"
    [[ "$HAD" == *$'\n'"$ARG"$'\n'* ]] && continue
    echo "$ARG" >>"$IGN_FN" || return $?
  done
}


function list_auto_delete () {
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME scan" >&2
  sed -nre '
    : skip
      /^#\[auto-delete\]#$/{b adel}
      n
    b skip
    : adel
      /^[^# \t]/p;n
      /^#\[/b skip
    b adel
    ' -- "$IGN_FN"
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME done" >&2
}


function auto_delete__gen_find_args () {
  echo '('; echo -false
  list_auto_delete | sed -re '
    s!^[^/]!*/&!
    s!^/!.&!
    s!^!-o\n-path\n!
    '
  echo ')'
}


function auto_delete () {
  local ADEL=()
  readarray -t ADEL < <(auto_delete__gen_find_args "${ADEL[@]}")
  [ "$DBGLV" -ge 1 ] && echo "D: $FUNCNAME find+del" >&2
  [ "$DBGLV" -ge 2 ] && ADEL+=( -print )
  find "${ADEL[@]}" -delete || return $?
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME done" >&2
  return 0
}


function list_sub_repos () {
  find -mindepth 2 -maxdepth 2 -name .git '(' -type d -o -type l ')' \
    | sed -re 's~^\.~~;p;s~\/.git$~~' | LANG=C sort --version-sort
}


function readarray_grep () {
  local DEST_VAR="$1"; shift
  local GREPPED="$(grep "$@")"
  eval "$DEST_VAR=()"
  [ -z "$GREPPED" ] || readarray -t "$DEST_VAR" <<<"$GREPPED"
}


function sub_repos () {
  local SUBS=()
  readarray -t SUBS < <(list_sub_repos)
  local N_SUBS="${#SUBS[@]}"
  [ "$N_SUBS" -ge 1 ] || return 3$(echo "E: Found no sub repos" >&2)
  local OLD_IGN="$(grep -Pe '^/' -- .gitignore 2>/dev/null)"
  local HAD=() ADD=()
  readarray_grep HAD -xFe  "$OLD_IGN" < <(printf -- '%s\n' "${SUBS[@]}")
  readarray_grep ADD -vxFe "$OLD_IGN" < <(printf -- '%s\n' "${SUBS[@]}")
  local N_ADD="${#ADD[@]}"
  echo "Of $N_SUBS suggested sub repo ignore path(s)," \
    "${#HAD[@]} are already in your .gitignore => adding $N_ADD path(s)."
  [ "$N_ADD" -ge 1 ] || return 0

  local PAD=
  printf -v PAD -- '# --- ¦ --- sub repos %(%F %T)T --- ¦ ---' -1
  add_to_or_edit_gitignore --
  printf -- '%s\n' '' "${PAD//¦/8<}" "${ADD[@]}" "${PAD//¦/>8}" \
    >>.gitignore || return $?
}


function suggest_initial_ignores () {
  echo '# Auto-generated files:'
  local -A IGN=(
    ['tmp.*']=+
    )

  local NM='node_modules'
  [ -f package.json ] && IGN[$NM]=+
  local PAR_DIR="$(dirname -- "$PWD")"
  local PAR_DBN="$(basename -- "$PAR_DIR")"
  case "$PAR_DBN" in
    "$NM" ) IGN["$PAR_DBN"]=+;;
  esac
  local KEY= VAL="
    $NM/
    "
  for VAL in $VAL; do
    case "$VAL" in
      */ ) [ -d "$VAL" ] && IGN["${VAL%/}"]=+;;
      * ) [ -f "$VAL" ] && IGN["$VAL"]=+;;
    esac
  done

  printf -- '/%s\n' "${!IGN[@]}" | sort --version-sort
}











cli_main "$@"; exit $?
