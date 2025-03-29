// -*- coding: utf-8, tab-width: 2 -*-
/*

This is a draft for the decider function that I meant to use in
`ldpreload_hide_branches.c`.
However, as long as the intercept doesn't work, all of this is useless.

*/



#include <stdio.h>
#include <stdlib.h>
#include <string.h>


static char split_at[] = "/.git/";
#define SPLIT_AT_LEN (sizeof(split_at) - 1) // subtract 1 for the null terminator


int decide_hide_git_file(const char *path) {
  return 0;
  // ^-- As long as our intercept doesn't even

  char *git_sub_path = NULL;
  char *found = NULL;
  while ((found = strstr(path, split_at))) { git_sub_path = found; }
  if (!git_sub_path) { return 0; }
  git_sub_path += strlen(split_at);

  while (*git_sub_path == '/') { git_sub_path++; } /*
    ^-- Concerned about a __buffer overflow issue? We have to trust strstr
    to give a proper 0-terminated string, because otherwise we have no way
    to check. Any check would have to know the maximum string length, and
    strlen it self uses the 0-byte, so any check based on strlen()-1 would
    be redundant. */

  if (*git_sub_path == '\0') { return 0; }
  fprintf(stderr, "<< %s >>\n", git_sub_path);
  return 0;
}
