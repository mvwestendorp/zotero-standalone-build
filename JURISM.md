# Note on Juris-M build

To grab module from tip of jurism branch in Juris-M fork, set the
branch in .gitmodules:

    branch = jurism

Then, before build, do this:

    git submodule update --remote

This is one of many answers here:

    http://stackoverflow.com/questions/1777854/git-submodules-specify-a-branch-tag
