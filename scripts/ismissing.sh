#!/bin/bash
#script isMissing.sh.  prints 1 if the file is missing, 0 if it exists.
test -e $1
echo $?