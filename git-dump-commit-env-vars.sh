#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function git_dump_commit_env_vars () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local FMT= VAL= SED= FX=,
  while [ -n "$1" ]; do case "$1" in
    --unamend ) FX+="${1#--},"; shift;;
    * ) break;;
  esac; done
  local FMT="$1"; shift
  case "$FMT" in
    rawenv | \
    ini ) ;;

    bashdict | \
    env | \
    shell )
      SED+='s~\x27~&&~g; s~^~&\x27~; s~$~\x27~; '
      SED+='s~^(\x27)(æ+=)~\2\1~; '
      ;;

    * )
      FMT="'$FMT'; try one of: $(local -f "$FUNCNAME" |
        sed -nre '/^ +case "\$FMT" in\b/,/^ +esac\b/p' |
        sed -nre 's~^ +([a-z |]+)\)$~\1~p' | tr ' |' '\n' |
        grep . | sort -Vu | tr '\n' ' ')"
      FMT="${FMT% }"
      echo E: $FUNCNAME: "Unsupported output format: $FMT" >&2
      return 4;;
  esac
  case "$FMT" in
    env | rawenv ) SED+='s~^æ+=~GIT_\U&\E~; ';;
    bashdict ) SED+='s~^(æ+)=~[\1]=~; ';;
  esac

  SED="${SED//æ/[A-Za-z0-9_-]}"
  SED="/./{$SED}"

  local PRETTY= WHO= FACT=
  PRETTY+='commit=%H%n'
  PRETTY+='abbrev=%h%n'
  PRETTY+='subj=%s%n'
  for WHO in author committer ; do
    for FACT in date name email ; do
      PRETTY+="${WHO}_${FACT}=%"
      case "$FX" in
        *,unamend,* ) PRETTY+='a';;
        * ) PRETTY+="${WHO:0:1}";;
      esac
      PRETTY+="${FACT:0:1}%n"
    done
  done
  PRETTY+='%n'
  [ "$#" -ge 1 ] || set -- HEAD
  while [ "$#" -ge 1 ]; do
    echo "ref_spec=$1"
    git show --no-patch --pretty=format:"$PRETTY" "$1" || return $?
    shift
  done | sed -re "$SED"
}










git_dump_commit_env_vars "$@"; exit $?
