#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
set -o errexit -o pipefail
exec git whatchanged --date=iso --pretty=format:$'%ad %h %s' "$@" |
  exec sed -nre '/^[0-9]/{s~^(\S+ \S+) \S+ (\S+) ~\2\t\1\t~p}'; exit $?
