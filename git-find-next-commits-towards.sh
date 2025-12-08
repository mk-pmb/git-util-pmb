#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
HOW_MANY=1
case "$1" in
  '' ) ;;
  *[^0-9]* ) ;;
  * ) HOW_MANY="$1"; shift;;
esac
TOWARDS="$1"; shift
git log --reverse --oneline "$@" HEAD.."$TOWARDS" | head --lines="$HOW_MANY"
