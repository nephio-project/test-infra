#!/bin/sh
echo "-------------------------------------"
echo "Those files don't have license header"
find . -type f -exec /go/bin/addlicense -check {} \;
echo "-------------------------------------"
