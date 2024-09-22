#!/bin/sh
echo "$(git config user.name) <$(git config user.email)>"; exit $?
