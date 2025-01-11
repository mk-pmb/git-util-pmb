#!/bin/sed -rf
# -*- coding: UTF-8, tab-width: 2 -*-

1{/^#? ?On branch \S+$/d}
#1{/^#? ?Changes to be committed:$/d}
#1{/^#? ?Changes not staged for commit:$/d}
#1{/^#? ?Untracked files:$/d}

/^#?\s*$/d
/^#? +\(use "git push" to (publish) /d
/^#? +\(use "git (reset HEAD|restore) <file>\.*" to (unstage)[ )]/d
/^#? +\(use "git add(|\/rm) <file>\.*" to (update|include)[ )]/d
/^#? +\(use "git checkout -- <file>\.*" to discard changes /d

s~^#?[^\t\f]*~\f<dimgray>&\f<>~
