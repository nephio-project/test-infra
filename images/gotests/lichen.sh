#!/usr/bin/env bash

for i in \
  $(egrep -rl --null --include \*.go 'package\s+main\b' | xargs -0 -L 1  dirname  | sort -u | xargs -d '\n' -L 1 printf "%s " ) ; \
do cd $i; echo $i; rm -f /tmp/cmd; go build -o "/tmp/cmd" > /dev/null 2>&1 ; lichen -c /etc/lichen.yaml "/tmp/cmd" || exit 1; cd - ;done
